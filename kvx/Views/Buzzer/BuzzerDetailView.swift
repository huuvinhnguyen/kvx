import SwiftUI

struct BuzzerDetailView: View {
    let device: Device
    @State private var model: BuzzerViewModel
    @State private var showingTestConfirmation = false
    @State private var showingLogin = false
    @State private var showingLink = false
    @State private var unlinkSource: BuzzerSource?

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
        .task { await model.activate() }
        .onDisappear { model.deactivate() }
        .alert("Test Buzzer", isPresented: $showingTestConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Xác nhận") { Task { await model.test() } }
        } message: {
            Text("Buzzer sẽ phát âm theo cấu hình trên máy chủ. Bạn muốn tiếp tục?")
        }
        .sheet(isPresented: $showingLink) {
            BuzzerLinkSheet(model: model).task { await model.loadAvailable() }
        }
        .alert("Hủy liên kết", isPresented: Binding(get: { unlinkSource != nil }, set: { if !$0 { unlinkSource = nil } })) {
            Button("Hủy", role: .cancel) { unlinkSource = nil }
            Button("Hủy liên kết", role: .destructive) {
                if let source = unlinkSource { Task { await model.unlink(pirID: source.id) } }
                unlinkSource = nil
            }
        } message: {
            Text("PIR sẽ ngừng kích hoạt Buzzer này. Hủy liên kết chỉ thay đổi cấu hình, không phát âm hoặc chạy Test Buzzer. Tiếp tục?")
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
            Button("+ Liên kết PIR") { showingLink = true }
                .disabled(model.isBusy || model.requiresRefresh)
            if model.isLoading { ProgressView("Đang tải PIR đã liên kết…") }
            if model.sources.isEmpty && !model.isLoading { Text("Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.").foregroundStyle(.secondary) }
            ForEach(model.sources) { source in
                VStack(alignment: .leading, spacing: 6) {
                    Label(source.name, systemImage: "sensor.tag.radiowaves.forward").font(.headline)
                    Text(source.chipID).font(.caption)
                    Text("Kênh \(scalar(source.relayDisplay, source.relayIndex)) · \(duration(source.longlast, display: source.longlastDisplay))").font(.subheadline).foregroundStyle(.secondary)
                    Button("Hủy liên kết \(source.name)", role: .destructive) { unlinkSource = source }
                        .disabled(model.isBusy || model.requiresRefresh)
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
                    Text("Kênh \(scalar(event.relayDisplay, event.relayIndex)) · \(duration(event.longlast, display: event.longlastDisplay)) · Đã nhận motion").font(.subheadline)
                }.padding(.vertical, 4)
            }
        } header: { Text("Lịch sử lệnh từ PIR") }
        footer: { Text("Tối đa 20 sự kiện gần nhất. Thời gian Việt Nam (UTC+7). Đã nhận motion không có nghĩa Buzzer đã phát âm.") }
    }

    private func scalar(_ display: String?, _ value: Int?) -> String { display ?? value.map(String.init) ?? "—" }
    private func duration(_ value: Int?, display: String? = nil) -> String { (display ?? value.map(String.init)).map { "\($0) ms" } ?? "—" }
    private func formatted(_ value: Date?) -> String {
        guard let value else { return "Chưa có dữ liệu" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: value)
    }
}

private struct BuzzerLinkSheet: View {
    let model: BuzzerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = ""
    @State private var relay = "0"
    @State private var duration = "1000"
    @State private var showingConfirmation = false
    @State private var showingLogin = false

    private var selected: AvailableBuzzerPIR? { model.availablePIRs.first { $0.id == selectedID } }
    private var configuration: BuzzerLinkConfiguration? {
        guard let relayIndex = Int(relay), let longlast = Int(duration) else { return nil }
        return BuzzerLinkConfiguration(pirID: selectedID, relayIndex: relayIndex, longlast: longlast)
    }
    var body: some View {
        NavigationStack {
            Form {
                if model.isLoadingAvailable { ProgressView("Đang tải PIR có thể liên kết…") }
                if let error = model.availableError {
                    Section {
                        Text(error).foregroundStyle(.red)
                        if model.needsLogin { Button("Đăng nhập Binblog") { showingLogin = true } }
                        else { Button("Thử lại") { Task { await model.loadAvailable() } } }
                    }
                }
                if !model.isLoadingAvailable && model.availableError == nil {
                    if model.availablePIRs.isEmpty { Text("Không có PIR nào khả dụng.") }
                    else {
                        Picker("PIR", selection: $selectedID) {
                            Text("Chọn PIR").tag("")
                            ForEach(model.availablePIRs) { pir in Text(pir.displayName).tag(pir.id) }
                        }
                        TextField("Kênh relay (từ 0)", text: $relay).keyboardType(.numberPad)
                        TextField("Thời lượng (100–10000 ms)", text: $duration).keyboardType(.numberPad)
                        if let selected, let warning = selected.confirmation(currentBuzzerID: model.detail?.id ?? "") {
                            Text(warning).foregroundStyle(.orange)
                        }
                        Button("Liên kết") {
                            if selected?.confirmation(currentBuzzerID: model.detail?.id ?? "") != nil { showingConfirmation = true }
                            else { Task { await submit() } }
                        }.disabled(model.isBusy || model.requiresRefresh || configuration?.isValid != true)
                        Text("Liên kết chỉ thay đổi cấu hình; không chạy Test Buzzer hoặc phát âm.").font(.footnote)
                    }
                }
                if model.isMutating { ProgressView("Đang lưu cấu hình…") }
                if let error = model.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                        if model.requiresRefresh { Button("Tải lại dữ liệu") { Task { await model.load(); await model.loadAvailable() } } }
                    }
                }
            }
            .navigationTitle("Liên kết PIR")
            .toolbar { Button("Đóng") { dismiss() } }
            .alert("Xác nhận liên kết", isPresented: $showingConfirmation) {
                Button("Hủy", role: .cancel) {}
                Button(selected?.linkedBuzzer != nil ? "Chuyển & liên kết" : "Thay thế & liên kết") { Task { await submit() } }
            } message: { Text(selected?.confirmation(currentBuzzerID: model.detail?.id ?? "") ?? "") }
            .sheet(isPresented: $showingLogin) {
                BinblogLoginView { Task { await model.load(); await model.loadAvailable() } }
            }
        }
    }
    private func submit() async {
        guard let configuration else { return }
        await model.link(configuration)
        if model.errorMessage == nil && !model.requiresRefresh { dismiss() }
    }
}
