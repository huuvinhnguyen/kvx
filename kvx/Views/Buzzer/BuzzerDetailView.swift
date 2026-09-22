import SwiftUI

struct BuzzerDetailView: View {
    let device: Device
    @State private var model: BuzzerViewModel
    @State private var showingTestConfirmation = false
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
                testSection
                sources(detail)
                history
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task { await model.load() }
        .onDisappear { model.deactivate() }
        .alert("Test Buzzer", isPresented: $showingTestConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xác nhận") { Task { await model.test() } }
        } message: {
            Text("Buzzer sẽ phát âm theo cấu hình trên máy chủ. Bạn muốn tiếp tục?")
        }
        .sheet(isPresented: $showingLogin) { BinblogLoginView { Task { await model.load() } } }
    }

    private var header: some View {
        Section("Thiết bị cảnh báo") {
            Label(device.name, systemImage: "bell.badge").font(.headline)
            Text(device.chipID ?? "Chưa có mã chip").font(.caption).textSelection(.enabled)
            Label(device.status.rawValue, systemImage: "circle.fill")
                .foregroundStyle(device.status == .online ? Color.green : device.status == .busy ? Color.orange : Color.secondary)
            LabeledContent("Lần kết nối cuối", value: formatted(model.detail?.lastSeen ?? device.lastConnected))
        }
    }

    private var testSection: some View {
        Section {
            LabeledContent("PIR đang liên kết", value: "\(model.detail?.linkedPIRCount ?? model.sources.count)")
            LabeledContent("Lần trigger gần nhất", value: formatted(model.detail?.lastTriggeredAt))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = model.cooldownSeconds(at: context.date)
                Button { showingTestConfirmation = true } label: {
                    Label(model.isTesting ? "Đang gửi lệnh…" : seconds > 0 ? "Chờ \(seconds) giây" : "Test Buzzer", systemImage: "bell")
                }.disabled(model.isBusy || seconds > 0)
            }
            if model.isTesting { ProgressView("Đang xử lý…") }
        } footer: {
            Text("Chỉ xác nhận server đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.")
        }
    }

    private func sources(_ detail: BuzzerDetail) -> some View {
        Section("PIR kích hoạt Buzzer (\(model.sources.count))") {
            if model.sources.isEmpty { Text("Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.").foregroundStyle(.secondary) }
            ForEach(model.sources) { source in
                VStack(alignment: .leading, spacing: 6) {
                    Label(source.name, systemImage: "sensor.tag.radiowaves.forward").font(.headline)
                    Text(source.chipID).font(.caption)
                    Text("Kênh \(source.relayIndex) · \(duration(source.longlast))").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
        }
    }

    private var history: some View {
        Section {
            if model.events.isEmpty { Text("Chưa có lịch sử lệnh từ PIR cho Buzzer này.").foregroundStyle(.secondary) }
            ForEach(model.events) { event in
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatted(event.occurredAt)).font(.headline)
                    Text(event.sourceName)
                    Text(event.sourceChipID).font(.caption).foregroundStyle(.secondary)
                    Text("Kênh \(event.relayIndex) · \(duration(event.longlast)) · Đã nhận motion").font(.subheadline)
                }.padding(.vertical, 4)
            }
        } header: { Text("Lịch sử lệnh từ PIR") }
        footer: { Text("Tối đa 20 sự kiện gần nhất. Thời gian Việt Nam (UTC+7). Đã nhận motion không có nghĩa Buzzer đã phát âm.") }
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
