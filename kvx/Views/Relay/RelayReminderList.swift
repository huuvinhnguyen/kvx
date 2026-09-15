import SwiftUI

/// List component for displaying and managing relay reminders
/// Matches Flutter's RelayReminderList widget
struct RelayReminderList: View {
    let reminders: [RelayReminder]
    @Binding var areRemindersActive: Bool
    let onDelete: ((String) -> Void)?
    let isEnabled: Bool

    init(
        reminders: [RelayReminder],
        areRemindersActive: Binding<Bool>,
        onDelete: ((String) -> Void)? = nil,
        isEnabled: Bool = true
    ) {
        self.reminders = reminders
        self._areRemindersActive = areRemindersActive
        self.onDelete = onDelete
        self.isEnabled = isEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle
            HStack {
                Text("Danh sách Hẹn giờ")
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                Toggle("", isOn: $areRemindersActive)
                    .labelsHidden()
                    .disabled(!isEnabled)
            }

            // Reminder items or empty state
            if reminders.isEmpty {
                Text("Không có hẹn giờ nào được thiết lập.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(reminders) { reminder in
                    ReminderItemView(
                        reminder: reminder,
                        onDelete: isEnabled ? onDelete : nil
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, lineWidth: 1)
        )
        .padding(.top, 20)
    }
}

/// Individual reminder item view
private struct ReminderItemView: View {
    let reminder: RelayReminder
    let onDelete: ((String) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDateTime(reminder.startTime))
                    .font(.system(size: 16, weight: .bold))

                Text("\(formatDuration(reminder.duration)) • \(reminder.repeatType.displayName)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: { onDelete(reminder.id) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes) phút"
        }
        return "\(seconds) giây"
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Empty state
            RelayReminderList(
                reminders: [],
                areRemindersActive: .constant(false)
            )

            // With reminders
            RelayReminderList(
                reminders: [
                    RelayReminder(
                        id: "1",
                        deviceId: "device-123",
                        relayIndex: 0,
                        startTime: Date(),
                        duration: 300,
                        repeatType: .daily
                    ),
                    RelayReminder(
                        id: "2",
                        deviceId: "device-123",
                        relayIndex: 0,
                        startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                        duration: 30,
                        repeatType: .weekly
                    ),
                ],
                areRemindersActive: .constant(true),
                onDelete: { id in
                    print("Delete reminder: \(id)")
                }
            )

            // Disabled state
            RelayReminderList(
                reminders: [
                    RelayReminder(
                        id: "3",
                        deviceId: "device-123",
                        relayIndex: 0,
                        startTime: Date(),
                        duration: 300,
                        repeatType: .daily
                    ),
                ],
                areRemindersActive: .constant(true),
                isEnabled: false
            )
        }
        .padding()
    }
}
