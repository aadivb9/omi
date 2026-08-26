import XCTest

@testable import Omi_Computer

final class WakeCallDemoStateMachineTests: XCTestCase {
  func testWakeCallProgressesFromArmedToPhoneHandoff() {
    var machine = WakeCallDemoStateMachine()

    machine.arm()
    XCTAssertEqual(machine.stage, .armed)

    machine.fireAlarm()
    XCTAssertEqual(machine.stage, .ringing)

    machine.startPhoneHandoff()
    XCTAssertEqual(machine.stage, .escalating)
  }

  func testAcknowledgementStopsAnyActiveWakeCallStage() {
    var machine = WakeCallDemoStateMachine()

    machine.arm()
    machine.acknowledge()
    XCTAssertEqual(machine.stage, .acknowledged)

    machine.reset()
    machine.arm()
    machine.fireAlarm()
    machine.acknowledge()
    XCTAssertEqual(machine.stage, .acknowledged)

    machine.reset()
    machine.arm()
    machine.fireAlarm()
    machine.startPhoneHandoff()
    machine.acknowledge()
    XCTAssertEqual(machine.stage, .acknowledged)
  }

  func testInvalidTransitionsLeaveTheCurrentStageUntouched() {
    var machine = WakeCallDemoStateMachine()

    machine.fireAlarm()
    XCTAssertEqual(machine.stage, .idle)

    machine.startPhoneHandoff()
    XCTAssertEqual(machine.stage, .idle)
  }

  func testFaceTimeAudioURLRejectsUnsafeTargets() {
    XCTAssertEqual(
      FaceTimeWakeCallService.audioCallURL(target: "aadi@example.com")?.absoluteString,
      "facetime-audio://aadi@example.com")
    XCTAssertNil(FaceTimeWakeCallService.audioCallURL(target: "aadi@example.com?call=other"))
  }
}
