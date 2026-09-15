import SwiftUI

/// Footer component for device control actions
/// Matches Flutter's DeviceControlFooter widget
struct DeviceControlFooter: View {
    let deviceId: String
    let firmwareVersion: String?
    let appVersion: String?
    let onRestart: (() -> Void)?
    let onResetWifi: (() -> Void)?
    let isLoading: Bool

    @State private var showRestartConfirmation = false
    @State private var showResetWifiConfirmation = false

    init(
        deviceId: String,
        firmwareVersion: String? = nil,
        appVersion: String? = nil,
        onRestart: (() -> Void)? = nil,
        onResetWifi: (() -> Void)? = nil,
        isLoading: Bool = false
    ) {
        self.deviceId = deviceId
        self.firmwareVersion = firmwareVersion
        self.appVersion = appVersion
        self.onRestart = onRestart
        self.onResetWifi = onResetWifi
        self.isLoading = isLoading
    }

    var body: some View {
        VStack(spacing: 16) {
            // Device ID and versions
            VStack(spacing: 8) {
                HStack {
                    Text("🆔")
                    Text(deviceId)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                HStack(spacing: 16) {
                    if let firmware = firmwareVersion {
                        HStack(spacing: 4) {
                            Text("🛠️")
                            Text("v\(firmware)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }

                    if firmwareVersion != nil && appVersion != nil {
                        Text("|")
                            .foregroundColor(.gray)
                    }

                    if let app = appVersion {
                        HStack(spacing: 4) {
                            Text("📱")
                            Text("v\(app)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)

            // Restart button
            if let onRestart = onRestart {
                Button(action: { showRestartConfirmation = true }) {
                    Label("🔁 Khởi động lại thiết bị", systemImage: "arrow.clockwise")
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isLoading)
                .confirmationDialog(
                    "Bạn có chắc muốn khởi động lại thiết bị không?",
                    isPresented: $showRestartConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Khởi động lại", role: .destructive) {
                        onRestart()
                    }
                    Button("Hủy", role: .cancel) {}
                }
            }

            // Reset WiFi button
            if let onResetWifi = onResetWifi {
                Button(action: { showResetWifiConfirmation = true }) {
                    Label("📶 Thay đổi WiFi", systemImage: "wifi.slash")
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isLoading)
                .confirmationDialog(
                    "Thiết bị sẽ xóa WiFi cũ và chuyển sang chế độ cấu hình mới. Bạn có chắc không?",
                    isPresented: $showResetWifiConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Thay đổi WiFi", role: .destructive) {
                        onResetWifi()
                    }
                    Button("Hủy", role: .cancel) {}
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

#Preview {
    VStack {
        Spacer()

        DeviceControlFooter(
            deviceId: "esp8266_11729385",
            firmwareVersion: "0",
            appVersion: "1.0.0",
            onRestart: {
                print("Restart device")
            },
            onResetWifi: {
                print("Reset WiFi")
            }
        )

        Spacer()

        DeviceControlFooter(
            deviceId: "esp8266_11729385",
            onRestart: {
                print("Restart device")
            },
            onResetWifi: {
                print("Reset WiFi")
            },
            isLoading: true
        )
    }
    .background(Color(.systemGroupedBackground))
}
