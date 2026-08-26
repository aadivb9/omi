import AppKit
import Foundation

/// Device-local fallback for a personal wake call. It uses FaceTime Audio on
/// the Mac, so it needs no Omi subscription or backend call quota.
enum FaceTimeWakeCallService {
  enum Error: LocalizedError {
    case missingTarget
    case invalidTarget
    case faceTimeUnavailable
    case launchFailed

    var errorDescription: String? {
      switch self {
      case .missingTarget: return "Add the email address or phone number you use with FaceTime."
      case .invalidTarget: return "That FaceTime address is not valid."
      case .faceTimeUnavailable: return "FaceTime is not available on this Mac."
      case .launchFailed: return "Omi could not start the FaceTime Audio call."
      }
    }
  }

  static func startAudioCall(target: String) throws {
    guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.FaceTime") != nil else {
      throw Error.faceTimeUnavailable
    }
    guard let url = audioCallURL(target: target) else {
      throw Error.invalidTarget
    }
    guard NSWorkspace.shared.open(url) else {
      throw Error.launchFailed
    }
    pressFaceTimeCallButtonWhenReady()
  }

  static func audioCallURL(target: String) -> URL? {
    let value = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    guard !value.contains(where: { $0.isWhitespace || $0 == "/" || $0 == "?" || $0 == "#" }) else { return nil }
    return URL(string: "facetime-audio://\(value)")
  }

  /// FaceTime has no public API for confirming an outgoing call. Its URL scheme
  /// only opens the confirmation UI, so retry the accessibility press after the
  /// window appears. macOS asks once for permission to control System Events.
  private static func pressFaceTimeCallButtonWhenReady() {
    DispatchQueue.global(qos: .userInitiated).async {
      for _ in 0..<8 {
        Thread.sleep(forTimeInterval: 0.5)
        if pressFaceTimeCallButton() { return }
      }
      log("FaceTimeWakeCallService: call confirmation was not available to auto-press")
    }
  }

  private static func pressFaceTimeCallButton() -> Bool {
    let source = """
      tell application "System Events"
        tell process "FaceTime"
          repeat with theWindow in windows
            if exists button "Call" of theWindow then
              click button "Call" of theWindow
              return "pressed"
            end if
          end repeat
        end tell
      end tell
      return "not_found"
      """
    guard let script = NSAppleScript(source: source) else { return false }
    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if let error {
      log(
        "FaceTimeWakeCallService: automation permission is required (error \(error[NSAppleScript.errorNumber] ?? "unknown"))"
      )
      return false
    }
    let pressed = result.stringValue == "pressed"
    if pressed {
      log("FaceTimeWakeCallService: FaceTime call confirmation pressed")
    }
    return pressed
  }
}
