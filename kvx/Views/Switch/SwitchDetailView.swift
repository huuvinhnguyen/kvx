import SwiftUI

struct SwitchDetailView: View {
    @State private var model: SwitchViewModel
    @State private var duration = "1"
    @State private var minutes = false
    @State private var durationError: String?
    init(deviceID: String, useCases: SwitchUseCases) {
        _model = State(initialValue: SwitchViewModel(deviceID: deviceID, useCases: useCases))
    }
    var body: some View {
        List {
            Section("Trạng thái") {
                if model.isBusy { ProgressView("Đang xử lý…") }
                Text("Snapshot máy chủ · Chưa xác minh trạng thái vật lý")
                Text("Kết nối thiết bị: chưa xác định")
                Text("Lần liên lạc: \(model.detail?.lastSeen.map(Self.time) ?? "Chưa xác định")")
                if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
                if let notice = model.notice { Text(notice) }
                Button("Tải lại snapshot") { Task { await model.load() } }.disabled(model.isBusy)
                if model.uncertain {
                    Text("Kết quả lệnh chưa xác định. Tải lại không chứng minh thiết bị đã bật/tắt. Không tự gửi lại.")
                    Button("Tôi đã kiểm tra thiết bị, cho phép lệnh mới") { model.acknowledgePhysicalCheck() }
                        .disabled(model.isBusy || model.commandInFlight || !model.readReady)
                }
            }
            if let detail = model.detail {
                if detail.relays.isEmpty { Text("Switch chưa có relay.") }
                else {
                    Section("Relay") {
                        Picker("Chọn relay", selection: Binding(get: { model.selectedRelay ?? 0 }, set: { relay in Task { await model.selectRelay(relay) } })) {
                            ForEach(detail.relays, id: \.index) { relay in Text("Relay \(relay.index + 1)").tag(relay.index) }
                        }.disabled(model.isBusy)
                        if let relay = detail.relays.first(where: { $0.index == model.selectedRelay }) {
                            Text("Trạng thái snapshot: \(relay.switchValue.map { $0 == 1 ? "BẬT" : "TẮT" } ?? "Chưa xác định")")
                            HStack {
                                Button("BẬT") { Task { await model.state(1) } }.buttonStyle(.borderedProminent)
                                Button("TẮT") { Task { await model.state(0) } }.buttonStyle(.bordered)
                            }.disabled(!model.canCommand || !detail.capabilities.manualSwitch)
                        }
                    }
                    Section("Kích hoạt theo thời lượng") {
                        TextField("Thời lượng (số nguyên)", text: $duration).keyboardType(.numberPad)
                            .accessibilityLabel("Thời lượng kích hoạt")
                        Picker("Đơn vị", selection: $minutes) { Text("Giây").tag(false); Text("Phút").tag(true) }
                        if let error = durationError { Text(error).foregroundStyle(.red) }
                        Button("Kích hoạt") {
                            guard let ms = SwitchDuration.milliseconds(duration, minutes: minutes) else {
                                durationError = "Nhập số nguyên: 1–86400 giây hoặc 1–1440 phút."; return
                            }
                            durationError = nil
                            Task { await model.pulse(ms) }
                        }.disabled(!model.canCommand || !detail.capabilities.pulse)
                    }.disabled(model.isBusy)
                    reminderSection
                    if let stats = model.statistics {
                        Section("Thống kê bản ghi log · UTC+07") {
                            Text("\(stats.from) – \(stats.to): \(stats.totalRecords) bản ghi")
                            Text("Không phải số lần bật hoặc thời gian chạy vật lý.")
                            ForEach(stats.days, id: \.date) { day in
                                HStack { Text(day.date); Spacer(); Text("\(day.count)") }
                            }
                        }
                    }
                }
                Section {
                    Button("Gửi yêu cầu thiết bị cập nhật") { Task { await model.refreshDevice() } }
                        .disabled(!model.canCommand || !detail.capabilities.refresh)
                }
            }
        }
        .navigationTitle(model.detail?.name ?? "Switch")
        .refreshable { await model.load() }
        .task { await model.activate() }
        .onDisappear { model.deactivate() }
    }
    private var reminderSection: some View {
        Section("Hẹn giờ — chỉ đọc") {
            Text("Thêm, sửa, xóa và bật/tắt hẹn giờ chưa khả dụng.")
            if let relay = model.detail?.relays.first(where: { $0.index == model.selectedRelay }) {
                Text("Nhóm lịch: \(relay.remindersActive.map { $0 ? "Đang bật" : "Đang tắt" } ?? "Chưa xác định")")
            }
            if model.readReady && model.reminders.isEmpty { Text("Chưa có hẹn giờ.") }
            ForEach(model.reminders.sorted { a, b in
                let ad = SwitchTimestamp.date(a.startTime) ?? .distantPast
                let bd = SwitchTimestamp.date(b.startTime) ?? .distantPast
                return ad == bd ? (Int64(a.id) ?? 0) < (Int64(b.id) ?? 0) : ad < bd
            }) { reminder in
                VStack(alignment: .leading) {
                    Text(Self.time(reminder.startTime))
                    Text("\(reminder.durationMs.map { "\($0) ms" } ?? "Thời lượng không hợp lệ") · \(Self.repeatLabel(reminder.repeatType)) · \(reminder.enabled ? "Bật" : "Tắt")")
                    if !reminder.configurationValid { Text("Cấu hình không hợp lệ").foregroundStyle(.orange) }
                }
            }
            if model.nextAfterID != nil {
                Button("Tải thêm hẹn giờ") { Task { await model.moreReminders() } }.disabled(model.isBusy)
            }
        }
    }
    private static func time(_ raw: String?) -> String {
        guard let date = SwitchTimestamp.date(raw) else { return "Ngày giờ không hợp lệ" }
        let f = DateFormatter(); f.locale = Locale(identifier: "vi_VN"); f.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC+07'"; return f.string(from: date)
    }
    private static func repeatLabel(_ value: String) -> String {
        switch value { case "once", "none": "Không lặp"; case "daily": "Hằng ngày"; case "weekly": "Hằng tuần"; case "monthly": "Hằng tháng"; default: "Kiểu lặp không hỗ trợ" }
    }
}
