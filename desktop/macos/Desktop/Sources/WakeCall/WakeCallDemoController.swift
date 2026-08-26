import AppKit
import Combine
import Foundation

/// A small state machine for Omi's opt-in Wake Call flow.
enum WakeCallDemoStage: Equatable {
  case idle
  case armed
  case ringing
  case escalating
  case acknowledged

  var title: String {
    switch self {
    case .idle: return "Ready when you are"
    case .armed: return "Wake Call is armed"
    case .ringing: return "Wake up"
    case .escalating: return "Phone handoff started"
    case .acknowledged: return "You are up"
    }
  }

  var detail: String {
    switch self {
    case .idle: return "Omi will ring this Mac first, then escalate if you do not respond."
    case .armed: return "Your demo alarm rings in a few seconds."
    case .ringing: return "Tap “I’m awake” before the phone handoff begins."
    case .escalating: return "Omi is calling your verified phone number now."
    case .acknowledged: return "Alarm silenced. Omi will keep your next wake time ready."
    }
  }

  var systemImage: String {
    switch self {
    case .idle: return "alarm"
    case .armed: return "timer"
    case .ringing: return "alarm.waves.left.and.right.fill"
    case .escalating: return "phone.connection.fill"
    case .acknowledged: return "checkmark.circle.fill"
    }
  }
}

struct WakeCallDemoStateMachine {
  private(set) var stage: WakeCallDemoStage = .idle

  mutating func arm() {
    stage = .armed
  }

  mutating func fireAlarm() {
    guard stage == .armed else { return }
    stage = .ringing
  }

  mutating func startPhoneHandoff() {
    guard stage == .ringing else { return }
    stage = .escalating
  }

  mutating func acknowledge() {
    guard stage == .armed || stage == .ringing || stage == .escalating else { return }
    stage = .acknowledged
  }

  mutating func reset() {
    stage = .idle
  }
}

@MainActor
final class WakeCallDemoController: ObservableObject {
  @Published private(set) var stage: WakeCallDemoStage = .idle
  @Published var wakeTime = WakeCallDemoController.defaultWakeTime
  @Published var phoneNumber = ""
  @Published private(set) var phoneWakeEnabled = WakeCallPreferences.phoneWakeEnabled
  @Published private(set) var phoneSetupDetail = "Checking your verified phone…"
  @Published private(set) var isPhoneVerified = false
  @Published private(set) var isVerifyingPhone = false

  static let demoDelay: UInt64 = 12
  static let escalationDelay: UInt64 = 8

  private var machine = WakeCallDemoStateMachine()
  private var alarmTask: Task<Void, Never>?
  private var escalationTask: Task<Void, Never>?
  private var phoneCallTask: Task<Void, Never>?
  private let alarmPulse: () -> Void

  init(alarmPulse: @escaping () -> Void = { NSSound.beep() }) {
    self.alarmPulse = alarmPulse
    Task { await refreshPhoneStatus() }
  }

  deinit {
    alarmTask?.cancel()
    escalationTask?.cancel()
  }

  func startDemo() {
    cancelPendingTimers()
    machine.arm()
    publishStage()

    alarmTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: Self.demoDelay * 1_000_000_000)
      guard !Task.isCancelled else { return }
      self?.fireAlarm()
    }
  }

  func triggerNow() {
    cancelPendingTimers()
    machine.arm()
    machine.fireAlarm()
    publishStage()
    alarmPulse()
    OmiUISound.play(.reveal)
    schedulePhoneHandoff()
  }

  func acknowledge() {
    cancelPendingTimers()
    machine.acknowledge()
    publishStage()
    OmiUISound.play(.complete)
  }

  func reset() {
    cancelPendingTimers()
    machine.reset()
    publishStage()
  }

  func setPhoneWakeEnabled(_ enabled: Bool) {
    guard enabled else {
      phoneWakeEnabled = false
      WakeCallPreferences.phoneWakeEnabled = false
      return
    }
    guard isPhoneVerified else {
      phoneSetupDetail = "Verify your phone number before enabling wake calls."
      return
    }
    phoneWakeEnabled = true
    WakeCallPreferences.phoneWakeEnabled = true
  }

  func startPhoneVerification() {
    let number = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !number.isEmpty else {
      phoneSetupDetail = "Enter your phone number in international format, for example +15551234567."
      return
    }
    isVerifyingPhone = true
    phoneSetupDetail = "Starting verification…"
    Task { [weak self] in
      do {
        try await WakeCallPhoneService.startVerification(phoneNumber: number)
        guard let self else { return }
        isVerifyingPhone = true
        phoneSetupDetail = "Answer Omi’s verification call and enter the code, then choose Check verification."
      } catch {
        guard let self else { return }
        isVerifyingPhone = false
        phoneSetupDetail = error.localizedDescription
      }
    }
  }

  func checkPhoneVerification() {
    let number = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !number.isEmpty else { return }
    Task { [weak self] in
      do {
        let verified = try await WakeCallPhoneService.checkVerification(phoneNumber: number)
        guard let self else { return }
        isPhoneVerified = verified
        isVerifyingPhone = !verified
        phoneSetupDetail =
          verified
          ? "Verified phone ready for wake calls."
          : "Not verified yet. Finish the verification call, then try again."
      } catch {
        guard let self else { return }
        phoneSetupDetail = error.localizedDescription
      }
    }
  }

  func refreshPhoneStatus() async {
    do {
      isPhoneVerified = try await WakeCallPhoneService.hasVerifiedPrimaryNumber()
      isVerifyingPhone = false
      phoneSetupDetail =
        isPhoneVerified
        ? "Verified phone ready for wake calls."
        : "Add and verify a phone number to enable wake calls."
    } catch {
      phoneSetupDetail = "Couldn’t check phone setup: \(error.localizedDescription)"
    }
  }

  private func fireAlarm() {
    machine.fireAlarm()
    publishStage()
    alarmPulse()
    OmiUISound.play(.reveal)
    schedulePhoneHandoff()
  }

  private func schedulePhoneHandoff() {
    escalationTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: Self.escalationDelay * 1_000_000_000)
      guard !Task.isCancelled else { return }
      self?.startPhoneHandoff()
    }
  }

  private func startPhoneHandoff() {
    machine.startPhoneHandoff()
    publishStage()
    guard phoneWakeEnabled else { return }
    phoneCallTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await WakeCallPhoneService.placeWakeCall(label: "Wake up")
        phoneSetupDetail = "Wake call placed to your verified phone."
      } catch {
        phoneSetupDetail = "Wake call failed: \(error.localizedDescription)"
      }
    }
  }

  private func cancelPendingTimers() {
    alarmTask?.cancel()
    escalationTask?.cancel()
    phoneCallTask?.cancel()
    alarmTask = nil
    escalationTask = nil
    phoneCallTask = nil
  }

  private func publishStage() {
    stage = machine.stage
  }

  private static var defaultWakeTime: Date {
    Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
  }
}
