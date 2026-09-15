import SwiftUI

/// Demo view showcasing all relay control widgets
struct RelayWidgetsDemoView: View {
    @State private var channel = RelayChannel(index: 0, isOn: false, label: "Kênh 1")
    @State private var reminders: [RelayReminder] = [
        RelayReminder(
            id: "1",
            deviceId: "demo_device",
            relayIndex: 0,
            startTime: Date().addingTimeInterval(7200), // +2 hours
            duration: 1800, // 30 minutes
            repeatType: .daily,
            isActive: true
        ),
        RelayReminder(
            id: "2",
            deviceId: "demo_device",
            relayIndex: 0,
            startTime: Date().addingTimeInterval(86400), // +1 day
            duration: 3600, // 1 hour
            repeatType: .weekly,
            isActive: false
        ),
    ]
    @State private var remindersActive = true
    @State private var showMessage = false
    @State private var message = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Device Info Header
                    sectionHeader("Device Info Header")
                    DeviceInfoHeaderView(
                        deviceName: "esp8266_demo",
                        lastConnected: Date().addingTimeInterval(-300), // 5 minutes ago
                        firmwareVersion: "v1.0.0",
                        appVersion: "v2.0.0",
                        onRefresh: {
                            showMessageAlert("Refreshing device...")
                        }
                    )

                    Divider()

                    // Toggle Switch
                    sectionHeader("Toggle Switch")
                    RelayToggleSwitchView(
                        channel: $channel,
                        onToggle: { value in
                            showMessageAlert("Toggle: \(value)")
                        }
                    )

                    Divider()

                    // Longlast Form
                    sectionHeader("Longlast Form")
                    RelayLonglastFormView(
                        onActivate: { duration in
                            showMessageAlert("Activate for \(Int(duration))s")
                        }
                    )

                    Divider()

                    // Reminder Form
                    sectionHeader("Reminder Form")
                    RelayReminderFormView(
                        onSubmit: { startTime, duration, repeatType in
                            showMessageAlert("Reminder: \(startTime), \(Int(duration))s, \(repeatType.displayName)")
                        }
                    )

                    Divider()

                    // Reminder List
                    sectionHeader("Reminder List")
                    RelayReminderListView(
                        reminders: $reminders,
                        remindersActive: $remindersActive,
                        onToggleRemindersActive: { value in
                            showMessageAlert("Reminders active: \(value)")
                        },
                        onToggleReminder: { reminder in
                            showMessageAlert("Toggle reminder: \(reminder.id)")
                        },
                        onDeleteReminder: { reminder in
                            showMessageAlert("Delete reminder: \(reminder.id)")
                        }
                    )

                    Divider()

                    // Device Control Footer
                    sectionHeader("Device Control Footer")
                    DeviceControlFooterView(
                        deviceId: "esp8266_demo",
                        firmwareVersion: "v1.0.0",
                        appVersion: "v2.0.0",
                        onRestart: {
                            showMessageAlert("Restarting device...")
                        },
                        onResetWifi: {
                            showMessageAlert("Resetting WiFi...")
                        }
                    )
                }
                .padding()
            }
            .navigationTitle("Relay Widgets Demo")
            .alert("Message", isPresented: $showMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(message)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
    }

    private func showMessageAlert(_ msg: String) {
        message = msg
        showMessage = true
    }
}

#Preview {
    RelayWidgetsDemoView()
}
