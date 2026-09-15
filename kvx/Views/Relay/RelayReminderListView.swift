import SwiftUI

/// Widget displaying list of relay reminders with toggle all and delete
struct RelayReminderListView: View {
    @Binding var reminders: [RelayReminder]
    @Binding var remindersActive: Bool

    let onToggleRemindersActive: (Bool) -> Void
    let onToggleReminder: (RelayReminder) -> Void
    let onDeleteReminder: (RelayReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle all
            HStack {
                Text("Danh sách Hẹn giờ")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { remindersActive },
                    set: { newValue in
                        remindersActive = newValue
                        onToggleRemindersActive(newValue)
                    }
                ))
                .labelsHidden()
            }

            if reminders.isEmpty {
                Text("Không có hẹn giờ nào được thiết lập.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(reminders) { reminder in
                    ReminderRow(
                        reminder: reminder,
                        onToggle: { onToggleReminder(reminder) },
                        onDelete: { onDeleteReminder(reminder) }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
}

private struct ReminderRow: View {
    let reminder: RelayReminder
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Circle()
                .fill(reminder.isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                // Start time
                Text(formatDate(reminder.startTime))
                    .font(.system(size: 16, weight: .semibold))

                // Duration and repeat type
                HStack(spacing: 8) {
                    Text(reminder.duration.toCompactString)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(reminder.repeatType.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Toggle button
            Button(action: onToggle) {
                Image(systemName: reminder.isActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(reminder.isActive ? .orange : .green)
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var reminders: [RelayReminder] = [
            RelayReminder(
                id: "1",
                deviceId: "demo",
                relayIndex: 0,
                startTime: Date().addingTimeInterval(7200),
                duration: 1800,
                repeatType: .daily,
                isActive: true
            ),
            RelayReminder(
                id: "2",
                deviceId: "demo",
                relayIndex: 0,
                startTime: Date().addingTimeInterval(86400),
                duration: 3600,
                repeatType: .weekly,
                isActive: false
            ),
        ]
        @State private var remindersActive = true

        var body: some View {
            RelayReminderListView(
                reminders: $reminders,
                remindersActive: $remindersActive,
                onToggleRemindersActive: { _ in },
                onToggleReminder: { _ in },
                onDeleteReminder: { _ in }
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
