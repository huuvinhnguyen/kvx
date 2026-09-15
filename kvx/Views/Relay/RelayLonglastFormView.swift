import SwiftUI

/// Form widget for activating relay for a specific duration
struct RelayLonglastFormView: View {
    let onActivate: (TimeInterval) -> Void

    @State private var durationValue: String = ""
    @State private var durationUnit: DurationUnit = .seconds
    @State private var showError = false
    @State private var errorMessage = ""

    enum DurationUnit: String, CaseIterable {
        case seconds = "Giây"
        case minutes = "Phút"

        var multiplier: TimeInterval {
            switch self {
            case .seconds: return 1
            case .minutes: return 60
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Duration input
            TextField("Nhập thời gian...", text: $durationValue)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 24))
                .multilineTextAlignment(.center)

            // Unit picker
            Picker("Đơn vị", selection: $durationUnit) {
                ForEach(DurationUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .font(.system(size: 24))

            // Activate button
            Button(action: handleActivate) {
                Text("KÍCH HOẠT")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Lỗi", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func handleActivate() {
        guard let value = Int(durationValue), value > 0 else {
            errorMessage = "Thời gian phải là số nguyên dương!"
            showError = true
            return
        }

        let duration = TimeInterval(value) * durationUnit.multiplier
        onActivate(duration)

        // Clear form
        durationValue = ""
    }
}

#Preview {
    RelayLonglastFormView { duration in
        print("Activate for \(duration)s")
    }
    .padding()
}
