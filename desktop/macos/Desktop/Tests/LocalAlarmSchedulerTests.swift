import XCTest

@testable import Omi_Computer

final class LocalAlarmSchedulerTests: XCTestCase {
  func testPhoneWakeEscalationDelayIsEightSeconds() {
    XCTAssertEqual(LocalAlarmScheduler.phoneWakeEscalationDelay, 8)
  }

  func testFaceTimeHandoffCountsAsPhoneWakeEnabled() {
    XCTAssertTrue(WakeCallPreferences.isAnyPhoneWakeEnabled(phoneWakeEnabled: false, faceTimeWakeEnabled: true))
    XCTAssertFalse(WakeCallPreferences.isAnyPhoneWakeEnabled(phoneWakeEnabled: false, faceTimeWakeEnabled: false))
  }

  func testHighPriorityTaskSchedulesFiveMinutesBeforeDueTime() {
    let now = Date(timeIntervalSince1970: 1_000)
    let dueAt = now.addingTimeInterval(900)

    XCTAssertEqual(
      LocalAlarmScheduler.importantTaskAlarmDate(dueAt: dueAt, priority: "high", now: now),
      now.addingTimeInterval(600))
  }

  func testLowerPriorityAndTooLateTasksDoNotScheduleAnAlarm() {
    let now = Date(timeIntervalSince1970: 1_000)

    XCTAssertNil(
      LocalAlarmScheduler.importantTaskAlarmDate(
        dueAt: now.addingTimeInterval(900), priority: "medium", now: now))
    XCTAssertNil(
      LocalAlarmScheduler.importantTaskAlarmDate(
        dueAt: now.addingTimeInterval(240), priority: "high", now: now))
  }
}
