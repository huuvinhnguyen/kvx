import SwiftUI

/// Duration unit for relay activation
enum DurationUnit: String, CaseIterable, Identifiable {
    case seconds = "Giây"
    case minutes = "Phút"

    var id: String { rawValue }
}

/// Form for activating relay for a specific duration
/// Matches Flutter's RelayLonglastForm widget
struct RelayLonglastForm: View {
    let onActivate: (TimeInterval) -> Void
    let isEnabled: Bool

    @State private var durationText: String = ""
    @State private var selectedUnit: DurationUnit = .seconds
    @State private var errorMessage: String?

    init(
        onActivate: @escaping (TimeInterval) -> Void,
        isEnabled: Bool = true
    ) {
        self.onActivate = onActivate
        self.isEnabled = isEnabled
    }

    var body: some View {
        VStack(spacing: 20) {
            // Duration input field
            TextField("Nhập thời gian...", text: $durationText)
                .keyboardType(.numberPad)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)
                .padding(15)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(errorMessage != nil ? Color.red : Color(.separator))
                )
                .disabled(!isEnabled)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }

            // Unit picker
            Picker("", selection: $selectedUnit) {
                ForEach(DurationUnit.allCases) { unit in
                    Text(unit.rawValue)
                        .tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .frame(height: 50)
            .disabled(!isEnabled)

            // Activate button
            Button(action: handleActivate) {
                Text("KÍCH HOẠT")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 30)
                    .background(isEnabled ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isEnabled)
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 2)
        )
        .padding(.top, 30)
    }

    private func handleActivate() {
        errorMessage = nil

        guard !durationText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Vui lòng nhập thời gian!"
            return
        }

        guard let value = Int(durationText), value > 0 else {
            errorMessage = "Thời gian phải là số nguyên dương!"
            return
        }

        let duration: TimeInterval
        switch selectedUnit {
        case .minutes:
            duration = TimeInterval(value * 60)
        case .seconds:
            duration = TimeInterval(value)
        }

        onActivate(duration)
        durationText = ""
        errorMessage = nil
    }
}

#Preview {
    ScrollView {
        VStack {
            RelayLonglastForm(onActivate: { duration in
                print("Activate for \(duration) seconds")
            })

            RelayLonglastForm(onActivate: { _ in }, isEnabled: false)
        }
        .padding()
    }
}
