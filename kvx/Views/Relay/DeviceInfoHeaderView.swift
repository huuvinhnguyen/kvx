import SwiftUI

/// Header widget displaying device info and refresh button
struct DeviceInfoHeaderView: View {
    let deviceName: String
    let lastConnected: Date?
    let firmwareVersion: String?
    let appVersion: String?
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Device name
            Text("Thiết bị: \(deviceName)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.blue)

            // Last connected and refresh button
            HStack {
                Text("Lần kết nối lần cuối:")
                    .font(.system(size: 16, weight: .semibold))

                if let lastConnected = lastConnected {
                    Text(formatDate(lastConnected))
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                } else {
                    Text("Chưa kết nối")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onRefresh) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Làm mới")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 20) {
        DeviceInfoHeaderView(
            deviceName: "esp8266_11729385",
            lastConnected: Date(),
            firmwareVersion: "v1.0.0",
            appVersion: "v2.0.0",
            onRefresh: { print("Refreshing...") }
        )

        DeviceInfoHeaderView(
            deviceName: "esp8266_demo",
            lastConnected: nil,
            firmwareVersion: nil,
            appVersion: nil,
            onRefresh: { print("Refreshing...") }
        )
    }
    .padding()
    .background(Color(.systemGray6))
}
