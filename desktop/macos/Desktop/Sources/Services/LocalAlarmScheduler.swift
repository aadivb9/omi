import AppKit
import Foundation
@preconcurrency import UserNotifications

/// Local, device-owned alarms for explicit chat requests and important due tasks.
///
/// Alarms use both a native macOS notification (when notification permission is available) and an
/// in-process system beep. The latter makes short timers reliable while Omi is frontmost; the native
/// notification remains the background delivery path.
@MainActor
final class LocalAlarmScheduler {
  static let shared = LocalAlarmScheduler()

  enum Source: String, Codable {
    case explicitChat
    case importantTask
  }

  struct Alarm: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let fireDate: Date
    let source: Source
    let phoneWakeCallEnabled: Bool

    init(id: String, title: String, fireDate: Date, source: Source, phoneWakeCallEnabled: Bool = false) {
      self.id = id
      self.title = title
      self.fireDate = fireDate
      self.source = source
      self.phoneWakeCallEnabled = phoneWakeCallEnabled
    }

    private enum CodingKeys: String, CodingKey {
      case id, title, fireDate, source, phoneWakeCallEnabled
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      title = try container.decode(String.self, forKey: .title)
      fireDate = try container.decode(Date.self, forKey: .fireDate)
      source = try container.decode(Source.self, forKey: .source)
      phoneWakeCallEnabled = try container.decodeIfPresent(Bool.self, forKey: .phoneWakeCallEnabled) ?? false
    }
  }

  private static let alarmsDefaultsKey = "localAlarmScheduler.alarms.v1"
  nonisolated private static let importantTaskLeadTime: TimeInterval = 5 * 60
  nonisolated static let phoneWakeEscalationDelay: UInt64 = 8
  private var alarms: [String: Alarm] = [:]
  private var timers: [String: Timer] = [:]
  private var phoneWakeTasks: [String: Task<Void, Never>] = [:]
  private var ringingSounds: [String: NSSound] = [:]

  private init() {
    restoreFutureAlarms()
  }

  @discardableResult
  func schedule(
    title: String,
    fireDate: Date,
    id: String = UUID().uuidString,
    source: Source,
    phoneWakeCallEnabled: Bool = false
  ) -> Alarm? {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty, fireDate > Date() else { return nil }

    cancel(id: id, persist: false)
    let alarm = Alarm(
      id: id,
      title: trimmedTitle,
      fireDate: fireDate,
      source: source,
      phoneWakeCallEnabled: phoneWakeCallEnabled)
    alarms[id] = alarm
    arm(alarm)
    persist()
    return alarm
  }

  func scheduleImportantTasks(_ tasks: [TaskActionItem], now: Date = Date()) {
    for task in tasks where !task.completed && !task.isRetired {
      guard
        let fireDate = Self.importantTaskAlarmDate(
          dueAt: task.dueAt,
          priority: task.priority,
          now: now)
      else { continue }
      _ = schedule(
        title: "Important task: \(task.description)",
        fireDate: fireDate,
        id: "important-task-\(task.id)",
        source: .importantTask)
    }
  }

  nonisolated static func importantTaskAlarmDate(
    dueAt: Date?,
    priority: String?,
    now: Date
  ) -> Date? {
    guard priority?.lowercased() == "high", let dueAt else { return nil }
    let fireDate = dueAt.addingTimeInterval(-importantTaskLeadTime)
    return fireDate > now ? fireDate : nil
  }

  func cancel(id: String, persist: Bool = true) {
    timers.removeValue(forKey: id)?.invalidate()
    phoneWakeTasks.removeValue(forKey: id)?.cancel()
    ringingSounds.removeValue(forKey: id)?.stop()
    alarms.removeValue(forKey: id)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    if persist { self.persist() }
  }

  private func arm(_ alarm: Alarm) {
    let delay = alarm.fireDate.timeIntervalSinceNow
    guard delay > 0 else { return }

    let content = UNMutableNotificationContent()
    content.title = "Omi alarm"
    content.body = alarm.title
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: alarm.id, content: content, trigger: trigger)
    ) { error in
      if let error {
        log("LocalAlarmScheduler: native notification could not be scheduled: \(error.localizedDescription)")
      }
    }

    timers[alarm.id] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.fire(alarm.id) }
    }
  }

  private func fire(_ id: String) {
    guard let alarm = alarms[id] else { return }
    timers.removeValue(forKey: id)?.invalidate()
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    startRinging(id: id)
    NSApplication.shared.requestUserAttention(.criticalRequest)
    log("LocalAlarmScheduler: fired \(alarm.source.rawValue) alarm")
    // Schedule escalation before presenting the blocking fallback alert. When
    // no app window is visible, NSAlert.runModal() does not return until the
    // person dismisses it; placing this below the alert would silently prevent
    // the phone handoff from ever being armed.
    schedulePhoneWakeCall(for: alarm)
    presentAlarm(alarm) { [weak self] in
      self?.cancel(id: id)
    }
  }

  private func schedulePhoneWakeCall(for alarm: Alarm) {
    guard alarm.phoneWakeCallEnabled else { return }

    phoneWakeTasks[alarm.id] = Task { [weak self] in
      try? await Task.sleep(nanoseconds: Self.phoneWakeEscalationDelay * 1_000_000_000)
      guard !Task.isCancelled else { return }
      do {
        if WakeCallPreferences.faceTimeWakeEnabled {
          try FaceTimeWakeCallService.startAudioCall(target: WakeCallPreferences.faceTimeTarget)
          log("LocalAlarmScheduler: FaceTime wake handoff started")
        } else {
          try await WakeCallPhoneService.placeWakeCall(label: alarm.title)
          log("LocalAlarmScheduler: phone wake call placed")
        }
      } catch {
        log("LocalAlarmScheduler: phone wake call could not be placed: \(error.localizedDescription)")
      }
      self?.phoneWakeTasks.removeValue(forKey: alarm.id)
    }
  }

  private func startRinging(id: String) {
    let url = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
    guard let sound = NSSound(contentsOf: url, byReference: false) else {
      NSSound.beep()
      return
    }
    sound.volume = 1
    sound.loops = true
    ringingSounds[id] = sound
    sound.play()
  }

  private func presentAlarm(_ alarm: Alarm, onDismiss: @escaping () -> Void) {
    let alert = NSAlert()
    alert.messageText = "Alarm"
    alert.informativeText = alarm.title
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Dismiss")

    NSApplication.shared.activate(ignoringOtherApps: true)
    if let window = NSApplication.shared.windows.first(where: { $0.isVisible }) {
      alert.beginSheetModal(for: window) { _ in onDismiss() }
    } else {
      alert.runModal()
      onDismiss()
    }
  }

  private func restoreFutureAlarms() {
    guard let data = UserDefaults.standard.data(forKey: Self.alarmsDefaultsKey),
      let restored = try? JSONDecoder().decode([Alarm].self, from: data)
    else { return }

    for alarm in restored where alarm.fireDate > Date() {
      alarms[alarm.id] = alarm
      arm(alarm)
    }
    persist()
  }

  private func persist() {
    let futureAlarms = alarms.values.filter { $0.fireDate > Date() }.sorted { $0.fireDate < $1.fireDate }
    guard let data = try? JSONEncoder().encode(futureAlarms) else { return }
    UserDefaults.standard.set(data, forKey: Self.alarmsDefaultsKey)
  }
}
