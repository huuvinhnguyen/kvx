import SwiftUI

/// Header component displaying device information
/// Matches Flutter's DeviceInfoHeader widget
struct DeviceInfoHeader: View {
    let deviceName: String
    let lastConnected: Date?
    let firmwareVersion: String?
    let appVersion: String?
    let onRefresh: (() -> Void)?
    let isLoading: Bool

    init(
        deviceName: String,
        lastConnected: Date? = nil,
        firmwareVersion: String? = nil,
        appVersion: String? = nil,
        onRefresh: (() -> Void)? = nil,
        isLoading: Bool = false
    ) {
        self.deviceName = deviceName
        self.lastConnected = lastConnected
        self.firmwareVersion = firmwareVersion
        self.appVersion = appVersion
        self.onRefresh = onRefresh
        self.isLoading = isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thiết bị: \(deviceName)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)

            HStack(spacing: 12) {
                if let lastConnected = lastConnected {
                    Text("Lần kết nối lần cuối:")
                        .font(.system(size: 14, weight: .bold))

                    Text(formatDateTime(lastConnected))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Spacer()

                if let onRefresh = onRefresh {
                    Button(action: onRefresh) {
                        HStack(spacing: 4) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("🔄")
                            }
                            Text("Làm mới")
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                    }
                    .disabled(isLoading)
                }
            }

            // Firmware and app version
            if firmwareVersion != nil || appVersion != nil {
                HStack(spacing: 16) {
                    if let firmware = firmwareVersion {
                        HStack(spacing: 4) {
                            Text("🛠️")
                            Text("v\(firmware)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 20) {
        DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            lastConnected: Date(),
            firmwareVersion: "0",
            appVersion: "1.0.0",
            onRefresh: {
                print("Refresh tapped")
            }
        )

        DeviceInfoHeader(
            deviceName: "esp8266_11729385",
            lastConnected: Date(),
            onRefresh: {
                print("Refresh tapped")
            },
            isLoading: true
        )

        DeviceInfoHeader(
            deviceName: "esp8266_11729385"
        )
    }
    .padding()
}
