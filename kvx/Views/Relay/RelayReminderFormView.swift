import SwiftUI

/// Form widget for creating relay reminders/schedules
struct RelayReminderFormView: View {
    let onSubmit: (Date, TimeInterval, ReminderRepeatType) -> Void

    @State private var startTime = Date()
    @State private var durationValue: String = ""
    @State private var durationUnit: DurationUnit = .minutes
    @State private var repeatType: ReminderRepeatType = .daily
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
            // Start time picker
            DatePicker(
                "Thời gian bắt đầu",
                selection: $startTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.system(size: 18))

            // Duration input
            HStack(spacing: 10) {
                TextField("Nhập thời gian", text: $durationValue)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 18))

                Picker("Đơn vị", selection: $durationUnit) {
                    ForEach(DurationUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 18))
            }

            // Repeat type picker
            Picker("Lặp lại", selection: $repeatType) {
                ForEach([ReminderRepeatType.none, .daily, .weekly, .monthly], id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 18))

            // Submit button
            HStack {
                Spacer()
                Button(action: handleSubmit) {
                    Text("Hẹn giờ")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(8)
                }
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

    private func handleSubmit() {
        guard let value = Int(durationValue), value > 0 else {
            errorMessage = "Vui lòng nhập thời gian hoạt động!"
            showError = true
            return
        }

        let duration = TimeInterval(value) * durationUnit.multiplier
        onSubmit(startTime, duration, repeatType)

        // Clear form
        durationValue = ""
        startTime = Date()
        repeatType = .daily
    }
}

#Preview {
    RelayReminderFormView { startTime, duration, repeatType in
        print("Reminder: \(startTime), \(duration)s, \(repeatType.displayName)")
    }
    .padding()
}
