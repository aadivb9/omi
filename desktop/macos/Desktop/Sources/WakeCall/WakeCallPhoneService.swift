import Foundation

/// Account-bound phone wake calls. The backend resolves the destination from
/// the signed-in user's verified primary number, so the desktop never sends or
/// stores a destination number when it fires an alarm.
enum WakeCallPhoneService {
  private struct PhoneNumbersResponse: Decodable {
    let numbers: [PhoneNumber]
  }

  private struct PhoneNumber: Decodable {
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
      case isPrimary = "is_primary"
    }
  }

  private struct VerifyRequest: Encodable {
    let phoneNumber: String

    enum CodingKeys: String, CodingKey {
      case phoneNumber = "phone_number"
    }
  }

  private struct VerifyResponse: Decodable {
    let status: String
  }

  private struct CheckResponse: Decodable {
    let verified: Bool
  }

  private struct WakeRequest: Encodable {
    let label: String
  }

  private struct WakeResponse: Decodable {
    let callSID: String

    enum CodingKeys: String, CodingKey {
      case callSID = "call_sid"
    }
  }

  static func hasVerifiedPrimaryNumber() async throws -> Bool {
    let response: PhoneNumbersResponse = try await APIClient.shared.get(
      "v1/phone/numbers", includeBYOK: false)
    return response.numbers.contains(where: \.isPrimary)
  }

  static func startVerification(phoneNumber: String) async throws {
    let _: VerifyResponse = try await APIClient.shared.post(
      "v1/phone/numbers/verify",
      body: VerifyRequest(phoneNumber: phoneNumber),
      includeBYOK: false)
  }

  static func checkVerification(phoneNumber: String) async throws -> Bool {
    let response: CheckResponse = try await APIClient.shared.post(
      "v1/phone/numbers/verify/check",
      body: VerifyRequest(phoneNumber: phoneNumber),
      includeBYOK: false)
    return response.verified
  }

  static func placeWakeCall(label: String) async throws {
    let _: WakeResponse = try await APIClient.shared.post(
      "v1/phone/wake", body: WakeRequest(label: label), includeBYOK: false)
  }
}

enum WakeCallPreferences {
  private static let phoneWakeEnabledKey = "wakeCall.phoneWakeEnabled"
  private static let faceTimeWakeEnabledKey = "wakeCall.faceTimeWakeEnabled"
  private static let faceTimeTargetKey = "wakeCall.faceTimeTarget"

  static var phoneWakeEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: phoneWakeEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: phoneWakeEnabledKey) }
  }

  static var faceTimeWakeEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: faceTimeWakeEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: faceTimeWakeEnabledKey) }
  }

  static var faceTimeTarget: String {
    get { UserDefaults.standard.string(forKey: faceTimeTargetKey) ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: faceTimeTargetKey) }
  }
}
