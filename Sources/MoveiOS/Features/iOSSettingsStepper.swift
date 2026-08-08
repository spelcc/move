import SwiftUI

struct iOSSettingsStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let valueText: (Int) -> String

    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        valueText: @escaping (Int) -> String = { String($0) }
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.valueText = valueText
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(valueText(value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: value)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                adjustmentButton(
                    systemImage: "minus",
                    accessibilityLabel: "Diminuer \(title)",
                    enabled: value - step >= range.lowerBound,
                    delta: -step
                )
                adjustmentButton(
                    systemImage: "plus",
                    accessibilityLabel: "Augmenter \(title)",
                    enabled: value + step <= range.upperBound,
                    delta: step
                )
            }
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: value)
    }

    private func adjustmentButton(
        systemImage: String,
        accessibilityLabel: String,
        enabled: Bool,
        delta: Int
    ) -> some View {
        iOSSettingsAdjustmentButton(
            systemImage: systemImage,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: valueText(value),
            enabled: enabled
        ) {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        }
    }
}

private struct iOSSettingsAdjustmentButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let enabled: Bool
    let action: () -> Void

    @State private var feedbackToken = 0

    var body: some View {
        Button {
            feedbackToken += 1
            action()
        } label: {
            Image(systemName: systemImage)
                .symbolEffect(.bounce, value: feedbackToken)
        }
        .buttonStyle(iOSSettingsAdjustmentButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

private struct iOSSettingsAdjustmentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 40, height: 34)
            .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary.opacity(0.45))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(isEnabled ? 0.2 : 0.06))
            }
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(.rect)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed { return Color.accentColor.opacity(0.3) }
        return Color.accentColor.opacity(isEnabled ? 0.1 : 0.03)
    }
}
