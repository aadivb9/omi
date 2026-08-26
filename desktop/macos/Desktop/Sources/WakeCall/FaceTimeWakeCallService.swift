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
  }

  static func audioCallURL(target: String) -> URL? {
    let value = target.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    guard !value.contains(where: { $0.isWhitespace || $0 == "/" || $0 == "?" || $0 == "#" }) else { return nil }
    return URL(string: "facetime-audio://\(value)")
  }
}
