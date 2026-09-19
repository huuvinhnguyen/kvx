import SwiftUI

struct BuzzerDetailView: View {
    let device: Device
    @State private var model: BuzzerViewModel
    @State private var confirmation: BuzzerCommand?
    @State private var showingLogin = false

    init(device: Device, useCases: BuzzerUseCases) {
        self.device = device
        _model = State(initialValue: BuzzerViewModel(deviceID: device.id, useCases: useCases))
    }

    var body: some View {
        List {
            header
            if model.isLoading { ProgressView("Đang tải dữ liệu…") }
            if let notice = model.notice {
                Section { Label(notice, systemImage: "info.circle").foregroundStyle(.secondary) }
            }
            if let error = model.errorMessage {
                Section {
                    Text("Dữ liệu mở rộng và điều khiển Buzzer").font(.headline)
                    Text(error).foregroundStyle(.red)
                    if model.needsLogin {
                        Button("Đăng nhập Binblog") { showingLogin = true }
                    } else {
                        Button("Tải lại dữ liệu") { Task { await model.load() } }.disabled(model.isBusy)
                    }
                }
            }
            if let detail = model.detail {
                testSection(detail)
                sources(detail)
                history(detail)
                metadata(detail)
                Section("Quản lý thiết bị") {
                    Button("Khởi động lại thiết bị", systemImage: "arrow.clockwise") { confirmation = .restart }
                    Button("Thay đổi WiFi", systemImage: "wifi", role: .destructive) { confirmation = .resetWifi }
                }.disabled(model.isBusy || model.needsLogin)
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task { await model.load() }
        .onDisappear { model.deactivate() }
        .alert(confirmationTitle, isPresented: Binding(
            get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }
        ), presenting: confirmation) { command in
            Button("Hủy", role: .cancel) { confirmation = nil }
            Button("Xác nhận", role: command == .resetWifi ? .destructive : nil) {
                confirmation = nil
                Task { await model.send(command) }
            }
        } message: { command in
            Text(command == .test ? "Buzzer sẽ phát âm theo thời lượng đã cấu hình. Bạn muốn tiếp tục?" :
                 command == .resetWifi ? "Thiết bị sẽ xóa WiFi cũ và chuyển sang chế độ cấu hình mới. Bạn có chắc không?" :
                    "Bạn có chắc muốn khởi động lại thiết bị không?")
        }
        .sheet(isPresented: $showingLogin) {
            BinblogLoginView { Task { await model.load() } }
        }
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .test: return "Test Buzzer"
        case .resetWifi: return "Thay đổi WiFi"
        default: return "Khởi động lại thiết bị"
        }
    }

    // Common device data comes from /api/devices, just like Switch and PIR.
    private var header: some View {
        Section("Thiết bị cảnh báo") {
            Label(device.name, systemImage: "bell.badge").font(.headline)
            Text(device.chipID ?? "Chưa có mã chip").font(.caption).textSelection(.enabled)
            Label(device.status.rawValue, systemImage: "circle.fill")
                .foregroundStyle(device.status == .online ? Color.green : device.status == .busy ? Color.orange : Color.secondary)
            LabeledContent("Lần kết nối cuối", value: formatted(model.detail?.lastSeen ?? device.lastConnected))
            if model.detail != nil {
                Button {
                    Task { await model.send(.refresh) }
                } label: {
                    Label(model.pendingCommand == .refresh ? "Đang gửi lệnh…" : "Làm mới thiết bị", systemImage: "arrow.triangle.2.circlepath")
                }.disabled(model.isBusy || model.needsLogin)
            }
        }
    }

    private func testSection(_ detail: BuzzerDetail) -> some View {
        Section {
            LabeledContent("PIR đang liên kết", value: "\(detail.sources.count)")
            LabeledContent("Lần trigger gần nhất", value: formatted(detail.events.first?.occurredAt))
            LabeledContent("Thời lượng test", value: duration(detail.testDurationMS))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = model.cooldownSeconds(at: context.date)
                Button { confirmation = .test } label: {
                    Label(model.pendingCommand == .test ? "Đang gửi lệnh…" : seconds > 0 ? "Chờ \(seconds) giây" : "Test Buzzer", systemImage: "bell")
                }.disabled(model.isBusy || !detail.canTest || seconds > 0)
            }
            if model.pendingCommand != nil { ProgressView("Đang xử lý…") }
            if !detail.canTest {
                Text("Cần cấu hình thời lượng từ 100 đến 10.000 ms để test.").foregroundStyle(.secondary)
            }
        } footer: {
            Text("Chỉ xác nhận server đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.")
        }
    }

    private func sources(_ detail: BuzzerDetail) -> some View {
        Section("PIR kích hoạt Buzzer (\(detail.sources.count))") {
            if detail.sources.isEmpty {
                Text("Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.").foregroundStyle(.secondary)
            }
            ForEach(detail.sources) { source in
                VStack(alignment: .leading, spacing: 6) {
                    Label(source.name, systemImage: "sensor.tag.radiowaves.forward").font(.headline)
                    Text(source.chipID).font(.caption)
                    Text("Kênh \(source.relayIndex) · \(duration(source.durationMS))").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
        }
    }

    private func history(_ detail: BuzzerDetail) -> some View {
        Section {
            if detail.events.isEmpty {
                Text("Chưa có lịch sử lệnh từ PIR cho Buzzer này.").foregroundStyle(.secondary)
            }
            ForEach(detail.events) { event in
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatted(event.occurredAt)).font(.headline)
                    Text(event.sourceName)
                    Text(event.sourceChipID).font(.caption).foregroundStyle(.secondary)
                    Text("\(duration(event.durationMS)) · Đã nhận motion").font(.subheadline)
                }.padding(.vertical, 4)
            }
        } header: { Text("Lịch sử lệnh từ PIR") }
        footer: { Text("Tối đa 20 sự kiện gần nhất. Thời gian Việt Nam (UTC+7). Đã nhận motion không có nghĩa Buzzer đã phát âm.") }
    }

    private func metadata(_ detail: BuzzerDetail) -> some View {
        Section("Thông tin thiết bị") {
            Text(detail.chipID).textSelection(.enabled)
            if let version = detail.buildVersion, !version.isEmpty { LabeledContent("Firmware", value: "v\(version)") }
            if let version = detail.appVersion, !version.isEmpty { LabeledContent("Ứng dụng", value: "v\(version)") }
        }
    }

    private func duration(_ value: Int?) -> String { value.map { "\($0) ms" } ?? "—" }
    private func formatted(_ value: Date?) -> String {
        guard let value else { return "Chưa có dữ liệu" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: value)
    }
}
