import SwiftUI

/// Form for creating relay reminders with scheduled activation
/// Matches Flutter's RelayReminderForm widget
struct RelayReminderForm: View {
    let onAdd: (RelayReminder) -> Void
    let deviceId: String
    let relayIndex: Int
    let isEnabled: Bool

    @State private var selectedDateTime: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var durationText: String = ""
    @State private var selectedUnit: DurationUnit = .minutes
    @State private var selectedRepeatType: ReminderRepeatType = .daily
    @State private var errorMessage: String?

    init(
        onAdd: @escaping (RelayReminder) -> Void,
        deviceId: String,
        relayIndex: Int,
        isEnabled: Bool = true
    ) {
        self.onAdd = onAdd
        self.deviceId = deviceId
        self.relayIndex = relayIndex
        self.isEnabled = isEnabled
    }

    var body: some View {
        VStack(spacing: 20) {
            // DateTime picker
            DatePicker(
                "",
                selection: $selectedDateTime,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(height: 50)
            .disabled(!isEnabled)

            // Duration input
            HStack(spacing: 10) {
                TextField("Nhập thời gian", text: $durationText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 18))
                    .padding(15)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(errorMessage != nil ? Color.red : Color(.separator))
                    )
                    .disabled(!isEnabled)

                Picker("", selection: $selectedUnit) {
                    ForEach(DurationUnit.allCases) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
                .padding(15)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator))
                )
                .disabled(!isEnabled)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Repeat type picker
            Picker("", selection: $selectedRepeatType) {
                ForEach(ReminderRepeatType.allCases) { type in
                    Text(type.displayName)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(height: 50)
            .padding(.horizontal, 15)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator))
            )
            .disabled(!isEnabled)

            // Submit button
            Button(action: handleAdd) {
                Text("Hẹn giờ")
                    .font(.system(size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(isEnabled ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!isEnabled)
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .padding(.top, 20)
    }

    private func handleAdd() {
        errorMessage = nil

        guard !durationText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Vui lòng nhập thời gian hoạt động!"
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

        let reminder = RelayReminder(
            id: UUID().uuidString,
            deviceId: deviceId,
            relayIndex: relayIndex,
            startTime: selectedDateTime,
            duration: duration,
            repeatType: selectedRepeatType,
            isActive: true
        )

        onAdd(reminder)
        durationText = ""
        errorMessage = nil
    }
}

#Preview {
    ScrollView {
        RelayReminderForm(
            onAdd: { reminder in
                print("Added reminder: \(reminder)")
            },
            deviceId: "device-123",
            relayIndex: 0
        )
        .padding()
    }
}
