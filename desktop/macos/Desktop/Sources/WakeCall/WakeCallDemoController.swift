import AppKit
import Combine
import Foundation

/// A small, local state machine for the Wake Call prototype.
///
/// The demo deliberately stops at a phone-handoff state. Omi already has verified-number and
/// Twilio infrastructure, but an automated outbound call needs a server-side schedule and an
/// explicit user consent flow before it can be real. Keeping that boundary explicit lets the
/// desktop interaction be demonstrated without ever placing an unexpected phone call.
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
    case .escalating: return "Demo mode is showing the phone-call handoff. No call is placed."
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

  static let demoDelay: UInt64 = 12
  static let escalationDelay: UInt64 = 8

  private var machine = WakeCallDemoStateMachine()
  private var alarmTask: Task<Void, Never>?
  private var escalationTask: Task<Void, Never>?
  private let alarmPulse: () -> Void

  init(alarmPulse: @escaping () -> Void = { NSSound.beep() }) {
    self.alarmPulse = alarmPulse
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
  }

  private func cancelPendingTimers() {
    alarmTask?.cancel()
    escalationTask?.cancel()
    alarmTask = nil
    escalationTask = nil
  }

  private func publishStage() {
    stage = machine.stage
  }

  private static var defaultWakeTime: Date {
    Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
  }
}
