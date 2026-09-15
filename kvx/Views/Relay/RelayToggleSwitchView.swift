import SwiftUI

/// Toggle switch widget for relay on/off control
struct RelayToggleSwitchView: View {
    @Binding var channel: RelayChannel
    let onToggle: (Bool) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Toggle(isOn: Binding(
                get: { channel.isOn },
                set: { newValue in
                    channel = RelayChannel(
                        index: channel.index,
                        isOn: newValue,
                        label: channel.label
                    )
                    onToggle(newValue)
                }
            )) {
                Text("BẬT / TẮT")
                    .font(.system(size: 28, weight: .bold))
            }
            .toggleStyle(SwitchToggleStyle(tint: .green))
        }
        .padding(30)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray, lineWidth: 2)
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var channel = RelayChannel(index: 0, isOn: false, label: "Kênh 1")

        var body: some View {
            RelayToggleSwitchView(
                channel: $channel,
                onToggle: { value in
                    print("Toggle: \(value)")
                }
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
