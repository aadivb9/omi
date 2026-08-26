import OmiTheme
import SwiftUI

struct WakeCallDemoSettingsCard: View {
  @ObservedObject var controller: WakeCallDemoController

  var body: some View {
    VStack(alignment: .leading, spacing: OmiSpacing.lg) {
      HStack(alignment: .top, spacing: SettingsGlassMetrics.rowContentSpacing) {
        SettingsIconTile(symbol: "alarm.waves.left.and.right.fill")

        VStack(alignment: .leading, spacing: OmiSpacing.xxs) {
          HStack(spacing: OmiSpacing.xs) {
            Text("Wake Call")
              .scaledFont(size: OmiType.subheading, weight: .medium)
              .foregroundColor(Ink.primary)

            Text("PHONE WAKE")
              .scaledFont(size: OmiType.micro, weight: .semibold)
              .foregroundColor(Ink.secondary)
              .padding(.horizontal, OmiSpacing.xs)
              .padding(.vertical, OmiSpacing.hairline)
              .background(Ink.hairline.opacity(0.7))
              .clipShape(Capsule())
          }

          Text("A wake-up safety net that rings your Mac first, then calls your phone if you stay asleep.")
            .scaledFont(size: OmiType.caption)
            .foregroundColor(Ink.secondary)
        }

        Spacer()
      }

      wakeTimeRow

      phoneSetup

      faceTimeSetup

      GlassSeparator()

      escalationPath

      statusPanel

      controls
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("wake-call-demo")
  }

  private var wakeTimeRow: some View {
    HStack {
      VStack(alignment: .leading, spacing: OmiSpacing.hairline) {
        Text("Wake time")
          .scaledFont(size: OmiType.body, weight: .medium)
          .foregroundColor(Ink.primary)
        Text("The saved wake time for the full version")
          .scaledFont(size: OmiType.caption)
          .foregroundColor(Ink.secondary)
      }

      Spacer()

      DatePicker("Wake time", selection: $controller.wakeTime, displayedComponents: .hourAndMinute)
        .datePickerStyle(.stepperField)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Wake time")
    }
  }

  private var escalationPath: some View {
    HStack(spacing: OmiSpacing.md) {
      escalationStep(icon: "laptopcomputer", title: "Ring this Mac", detail: "at your wake time")
      Image(systemName: "arrow.right")
        .scaledFont(size: OmiType.caption, weight: .semibold)
        .foregroundColor(Ink.secondary)
      escalationStep(icon: "phone.fill", title: "Phone handoff", detail: "after no response")
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Wake Call rings this Mac first, then hands off to your phone if there is no response")
  }

  private var phoneSetup: some View {
    VStack(alignment: .leading, spacing: OmiSpacing.sm) {
      Toggle(
        "Call my verified phone after 8 seconds",
        isOn: Binding(
          get: { controller.phoneWakeEnabled },
          set: { controller.setPhoneWakeEnabled($0) })
      )
      .toggleStyle(.switch)
      .accessibilityIdentifier("wake-call-phone-toggle")

      Text(controller.phoneSetupDetail)
        .scaledFont(size: OmiType.caption)
        .foregroundColor(Ink.secondary)

      if !controller.isPhoneVerified {
        HStack(spacing: OmiSpacing.sm) {
          TextField("+15551234567", text: $controller.phoneNumber)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 190)
            .accessibilityLabel("Phone number for Wake Call")

          if controller.isVerifyingPhone {
            Button("Check verification") {
              controller.checkPhoneVerification()
            }
            .buttonStyle(OmiButtonStyle(.secondary, size: .compact))
          } else {
            Button("Verify phone") {
              controller.startPhoneVerification()
            }
            .buttonStyle(OmiButtonStyle(.secondary, size: .compact))
          }
        }
      }
    }
  }

  private var faceTimeSetup: some View {
    VStack(alignment: .leading, spacing: OmiSpacing.sm) {
      Toggle(
        "Use FaceTime Audio for my personal wake call",
        isOn: Binding(
          get: { controller.faceTimeWakeEnabled },
          set: { controller.setFaceTimeWakeEnabled($0) })
      )
      .toggleStyle(.switch)
      .accessibilityIdentifier("wake-call-facetime-toggle")

      Text("No Omi plan needed. Omi opens a FaceTime Audio call from this Mac after the 8-second handoff.")
        .scaledFont(size: OmiType.caption)
        .foregroundColor(Ink.secondary)

      HStack(spacing: OmiSpacing.sm) {
        TextField("Apple ID email or FaceTime number", text: $controller.faceTimeTarget)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 260)
          .accessibilityLabel("FaceTime address for Wake Call")

        Button("Test FaceTime handoff") {
          controller.testFaceTimeHandoff()
        }
        .buttonStyle(OmiButtonStyle(.secondary, size: .compact))
        .accessibilityLabel("Start a FaceTime Audio call now")
      }
    }
  }

  private func escalationStep(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: OmiSpacing.sm) {
      Image(systemName: icon)
        .scaledFont(size: OmiType.caption, weight: .semibold)
        .foregroundColor(Ink.accent)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: OmiSpacing.hairline) {
        Text(title)
          .scaledFont(size: OmiType.caption, weight: .medium)
          .foregroundColor(Ink.primary)
        Text(detail)
          .scaledFont(size: OmiType.micro)
          .foregroundColor(Ink.secondary)
      }
    }
  }

  private var statusPanel: some View {
    HStack(spacing: OmiSpacing.md) {
      Image(systemName: controller.stage.systemImage)
        .scaledFont(size: OmiType.subheading, weight: .semibold)
        .foregroundColor(statusColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: OmiSpacing.hairline) {
        Text(controller.stage.title)
          .scaledFont(size: OmiType.body, weight: .semibold)
          .foregroundColor(Ink.primary)
        Text(controller.stage.detail)
          .scaledFont(size: OmiType.caption)
          .foregroundColor(Ink.secondary)
      }

      Spacer(minLength: 0)
    }
    .padding(OmiSpacing.md)
    .background(statusColor.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: SettingsGlassMetrics.cardRadius / 2, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var controls: some View {
    switch controller.stage {
    case .ringing, .escalating:
      HStack(spacing: OmiSpacing.sm) {
        Button("I’m awake") {
          controller.acknowledge()
        }
        .buttonStyle(OmiButtonStyle(.primary, size: .compact))
        .accessibilityIdentifier("wake-call-acknowledge")

        Button("Reset demo") {
          controller.reset()
        }
        .buttonStyle(OmiButtonStyle(.secondary, size: .compact))
      }
    case .idle, .armed, .acknowledged:
      HStack(spacing: OmiSpacing.sm) {
        Button("Start 12-second demo") {
          controller.startDemo()
        }
        .buttonStyle(OmiButtonStyle(.primary, size: .compact))
        .accessibilityIdentifier("wake-call-start-demo")

        Button("Trigger now") {
          controller.triggerNow()
        }
        .buttonStyle(OmiButtonStyle(.secondary, size: .compact))
        .accessibilityIdentifier("wake-call-trigger-now")
      }
    }
  }

  private var statusColor: Color {
    switch controller.stage {
    case .idle: return Ink.accent
    case .armed: return Ink.accent
    case .ringing: return .orange
    case .escalating: return .red
    case .acknowledged: return Ink.listeningGreen
    }
  }
}
