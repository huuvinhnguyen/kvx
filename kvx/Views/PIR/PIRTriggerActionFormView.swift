import SwiftUI

struct PIRTriggerActionFormView: View {
    let model: PIRTriggerActionsViewModel
    let action: PIRTriggerAction?
    @Environment(\.dismiss) private var dismiss
    @State private var targetID: Int?
    @State private var relayIndex: Int?
    @State private var duration = ""
    @State private var enabled = true
    @State private var confirmDelayNormalization = false

    init(model: PIRTriggerActionsViewModel, action: PIRTriggerAction? = nil) {
        self.model = model
        self.action = action
        _targetID = State(initialValue: action?.target?.id)
        _relayIndex = State(initialValue: action?.relayIndex)
        _duration = State(initialValue: action.map { String($0.durationMilliseconds) } ?? "")
        _enabled = State(initialValue: action?.enabled ?? true)
    }

    private var choices: [PIRTriggerTarget] {
        if let current = action?.target?.id {
            return model.targets.filter { target in
                target.id == current || !model.actions.contains { existing in
                    existing.id != action?.id && existing.target?.id == target.id
                }
            }
        }
        return model.availableTargetsForAdd
    }
    private var target: PIRTriggerTarget? { model.targets.first { $0.id == targetID } }
    private var draft: PIRTriggerActionDraft? {
        guard let targetID, let relayIndex, let duration = Int(duration) else { return nil }
        let value = PIRTriggerActionDraft(targetID: targetID, relayIndex: relayIndex, durationMilliseconds: duration, enabled: enabled)
        return value.isValid(using: model.targets) ? value : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    Picker("Thiết bị", selection: $targetID) {
                        Text("Chọn target").tag(Int?.none)
                        ForEach(choices) { value in
                            Text("\(value.displayName) · \(value.deviceType.rawValue)").tag(Optional(value.id))
                        }
                    }
                    if let target {
                        Text(target.chipID).font(.caption).textSelection(.enabled)
                        Picker("Relay", selection: $relayIndex) {
                            Text("Chọn relay").tag(Int?.none)
                            ForEach(target.relayIndexes, id: \.self) { Text("Relay \($0)").tag(Optional($0)) }
                        }
                    }
                }
                Section("Cấu hình") {
                    TextField("Thời lượng (ms)", text: $duration).keyboardType(.numberPad)
                    if let target {
                        Text("Khoảng cho phép: \(target.durationBounds.minimum)–\(target.durationBounds.maximum) ms")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LabeledContent("Độ trễ", value: action.map { "\($0.delayMilliseconds) ms" } ?? "0 ms")
                    if let action, action.delayMilliseconds > 0 {
                        Text("Đây là độ trễ cũ chỉ đọc. Lưu thay đổi sẽ đặt độ trễ về 0 ms theo cấu hình đồng bộ hiện tại.")
                            .font(.footnote).foregroundStyle(.orange)
                    } else {
                        Text("Độ trễ cố định 0 ms và không thể chỉnh sửa.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Toggle("Bật hành động", isOn: $enabled)
                }
                if model.isBusy { ProgressView("Đang lưu và tải lại trạng thái…") }
            }
            .navigationTitle(action == nil ? "Thêm hành động" : "Sửa hành động")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        if action?.delayMilliseconds ?? 0 > 0 { confirmDelayNormalization = true }
                        else { Task { await submit() } }
                    }.disabled(draft == nil || model.isBusy)
                }
            }
            .onChange(of: targetID) { _, _ in
                guard let target else { relayIndex = nil; return }
                if !target.relayIndexes.contains(relayIndex ?? -1) { relayIndex = target.relayIndexes.first }
                if Int(duration).map(target.durationBounds.contains) != true { duration = String(target.durationBounds.minimum) }
            }
            .alert("Đặt độ trễ về 0 ms?", isPresented: $confirmDelayNormalization) {
                Button("Hủy", role: .cancel) {}
                Button("Lưu và đặt về 0") { Task { await submit() } }
            } message: { Text("Backend không còn hỗ trợ độ trễ khác 0 cho hành động được cập nhật.") }
        }
    }

    private func submit() async {
        guard let draft else { return }
        if let action { await model.update(action: action, draft: draft) }
        else { await model.create(draft) }
        if model.phase == .ready { dismiss() }
    }
}
