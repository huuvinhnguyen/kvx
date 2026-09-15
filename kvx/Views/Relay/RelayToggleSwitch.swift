import SwiftUI

/// A large toggle switch component for relay control
/// Matches Flutter's RelayToggleSwitch widget
struct RelayToggleSwitch: View {
    @Binding var isOn: Bool
    let label: String
    let isEnabled: Bool

    init(
        isOn: Binding<Bool>,
        label: String = "BẬT / TẮT",
        isEnabled: Bool = true
    ) {
        self._isOn = isOn
        self.label = label
        self.isEnabled = isEnabled
    }

    var body: some View {
        HStack(spacing: 20) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(2.0)
                .disabled(!isEnabled)

            Text(label)
                .font(.system(size: 28, weight: .bold))
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 2)
        )
        .padding(.top, 30)
    }
}

#Preview {
    VStack(spacing: 20) {
        RelayToggleSwitch(isOn: .constant(false))
        RelayToggleSwitch(isOn: .constant(true))
        RelayToggleSwitch(isOn: .constant(false), label: "Custom Label")
        RelayToggleSwitch(isOn: .constant(false), isEnabled: false)
    }
    .padding()
}
