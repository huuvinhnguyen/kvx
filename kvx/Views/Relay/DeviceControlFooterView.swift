import SwiftUI

/// Footer widget displaying device info and control buttons
struct DeviceControlFooterView: View {
    let deviceId: String
    let firmwareVersion: String?
    let appVersion: String?
    let onRestart: () -> Void
    let onResetWifi: () -> Void

    @State private var showRestartConfirmation = false
    @State private var showResetWifiConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Device ID
            HStack {
                Text("🆔")
                Text(deviceId)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Firmware and app versions
            if let firmware = firmwareVersion, let app = appVersion {
                HStack {
                    Text("🛠️")
                    Text(firmware)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("|")
                        .foregroundColor(.secondary)

                    Text("📱")
                    Text(app)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Restart button
            Button(action: { showRestartConfirmation = true }) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("Khởi động lại thiết bị")
                }
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
            .confirmationDialog(
                "Bạn có chắc muốn khởi động lại thiết bị không?",
                isPresented: $showRestartConfirmation,
                titleVisibility: .visible
            ) {
                Button("Khởi động lại", role: .destructive) {
                    onRestart()
                }
                Button("Hủy", role: .cancel) { }
            }

            // Reset WiFi button
            Button(action: { showResetWifiConfirmation = true }) {
                HStack {
                    Image(systemName: "wifi.circle.fill")
                    Text("Thay đổi WiFi")
                }
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .cornerRadius(10)
            }
            .confirmationDialog(
                "Thiết bị sẽ xóa WiFi cũ và chuyển sang chế độ cấu hình mới. Bạn có chắc không?",
                isPresented: $showResetWifiConfirmation,
                titleVisibility: .visible
            ) {
                Button("Thay đổi WiFi", role: .destructive) {
                    onResetWifi()
                }
                Button("Hủy", role: .cancel) { }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DeviceControlFooterView(
        deviceId: "esp8266_demo",
        firmwareVersion: "v1.0.0",
        appVersion: "v2.0.0",
        onRestart: { print("Restarting...") },
        onResetWifi: { print("Resetting WiFi...") }
    )
    .padding()
}
