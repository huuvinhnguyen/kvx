import SwiftUI

struct PIRTriggerActionsView: View {
    let device: Device
    @State private var model: PIRTriggerActionsViewModel
    @State private var showingAdd = false
    @State private var editingAction: PIRTriggerAction?
    @State private var deletingAction: PIRTriggerAction?
    @State private var confirmMigration = false

    init(device: Device, useCases: PIRTriggerActionUseCases) {
        self.device = device
        _model = State(initialValue: PIRTriggerActionsViewModel(chipID: device.chipID ?? "", useCases: useCases))
    }

    var body: some View {
        List {
            statusSection
            if let notice = model.notice { Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(.secondary) } }
            if let error = model.errorMessage { errorSection(error) }
            if model.phase == .invalidLegacy {
                Section { Text("Cấu hình legacy không hợp lệ và cần được đối soát trên máy chủ trước khi có thể quản lý tại đây.") }
            }
            if model.phase == .legacy { legacySection }
            if model.phase == .ready { managedSection }
        }
        .navigationTitle("Hành động PIR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if model.canManagePersistedActions { EditButton().disabled(model.isBusy) } }
        .task { if model.phase == .idle { await model.load() } }
        .refreshable { await model.load() }
        .sheet(isPresented: $showingAdd) { PIRTriggerActionFormView(model: model) }
        .sheet(item: $editingAction) { PIRTriggerActionFormView(model: model, action: $0) }
        .alert("Xóa hành động?", isPresented: Binding(get: { deletingAction != nil }, set: { if !$0 { deletingAction = nil } })) {
            Button("Hủy", role: .cancel) { deletingAction = nil }
            Button("Xóa", role: .destructive) {
                if let action = deletingAction { Task { await model.delete(action) } }
                deletingAction = nil
            }
        } message: { Text("Hành động sẽ bị xóa khỏi cấu hình PIR. Thao tác này không gửi lệnh MQTT.") }
        .alert("Chuyển cấu hình legacy?", isPresented: $confirmMigration) {
            Button("Hủy", role: .cancel) {}
            Button("Chuyển cấu hình") { Task { await model.migrateLegacy() } }
        } message: { Text("Cấu hình cũ sẽ được chuyển thành một hành động được quản lý. Thao tác này không kích hoạt thiết bị.") }
    }

    @ViewBuilder private var statusSection: some View {
        if model.phase == .loading { Section { ProgressView("Đang tải cấu hình và target…") } }
        if model.phase == .mutating { Section { ProgressView("Đang gửi cập nhật…") } }
        if model.phase == .reconciling { Section { ProgressView("Đang tải lại trạng thái máy chủ…") } }
        if model.phase == .uncertain {
            Section { Text("Chưa xác nhận được trạng thái sau cập nhật. Mọi chỉnh sửa đang bị khóa.").foregroundStyle(.orange) }
        }
        if model.phase == .featureDisabled { Section { Text("Quản lý hành động PIR đang tạm tắt trên máy chủ.") } }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Text(message).foregroundStyle(.red)
            if !model.needsLogin { Button("Tải lại") { Task { await model.load() } }.disabled(model.isBusy) }
        }
    }

    @ViewBuilder private var managedSection: some View {
        Section {
            Button { showingAdd = true } label: { Label("Thêm hành động", systemImage: "plus") }
                .disabled(!model.canAdd || model.availableTargetsForAdd.isEmpty)
            if model.actions.isEmpty { Text("PIR chưa có hành động nào.").foregroundStyle(.secondary) }
            ForEach(model.actions, id: \.stableID) { action in actionRow(action, editable: true) }
                .onMove { source, destination in Task { await model.reorder(fromOffsets: source, toOffset: destination) } }
        } header: { Text("Hành động (\(model.actions.count))") }
    }

    private var legacySection: some View {
        Section {
            if let action = model.actions.first { actionRow(action, editable: false) }
            Button("Chuyển sang hành động được quản lý") { confirmMigration = true }
                .disabled(!model.canMigrateLegacy || model.isBusy)
            if !model.canMigrateLegacy { Text("Target legacy không còn khả dụng; hãy tải lại hoặc đối soát trên máy chủ.").font(.footnote).foregroundStyle(.orange) }
        } header: { Text("Cấu hình legacy · Chỉ đọc") }
    }

    private func actionRow(_ action: PIRTriggerAction, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(action.position + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Text(action.target?.displayName ?? "Target không còn khả dụng").font(.headline)
                Spacer()
                if action.origin == .legacy { Text("LEGACY").font(.caption2.bold()).foregroundStyle(.orange) }
                Image(systemName: action.enabled ? "checkmark.circle.fill" : "pause.circle").foregroundStyle(action.enabled ? .green : .secondary)
            }
            if let target = action.target {
                Text("\(target.deviceType.rawValue) · \(target.chipID)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Text("Relay \(action.relayIndex) · \(action.durationMilliseconds) ms · Trễ \(action.delayMilliseconds) ms")
                .font(.subheadline)
            if editable {
                HStack {
                    Button("Sửa") { editingAction = action }.disabled(model.isBusy)
                    Button("Xóa", role: .destructive) { deletingAction = action }.disabled(model.isBusy)
                }.buttonStyle(.borderless)
            }
        }.padding(.vertical, 4)
    }
}
