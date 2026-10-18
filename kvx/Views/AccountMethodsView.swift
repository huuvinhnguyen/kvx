import SwiftUI

struct AccountMethodsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AccountMethodsViewModel

    init(coordinator: SessionCoordinator, generation: UInt64, continuity: AccountMethodsContinuity) {
        _model = State(initialValue: AccountMethodsViewModel(
            repository: AuthManagementClient(authority: coordinator, generation: generation),
            authority: coordinator, generation: generation, continuity: continuity))
    }

    var body: some View {
        List {
            if model.busy { ProgressView() }
            if let message = model.message, !message.isEmpty {
                Section { Text(message) }
            }
            if model.writeBlocked {
                Section {
                    Text("Chưa xác minh được trạng thái máy chủ. Không thể thay đổi tài khoản lúc này.")
                    Button("Tải lại phương thức") { model.refresh() }.disabled(model.busy)
                }
            }
            if model.lostCodes {
                Section {
                    Text("Không nhận được bộ mã mới. Mã trước đó có thể đã bị hủy. Chỉ tạo bộ khác sau khi kiểm tra trạng thái.")
                    Button("Tôi hiểu, cho phép tạo bộ mã khác") { model.acknowledgeLostCodes() }
                        .disabled(!model.canAcknowledgeLostCodes)
                }
            }
            if let methods = model.methods {
                Section("Phương thức đăng nhập") {
                    LabeledContent("Mật khẩu", value: methods.passwordUsable ? "Có thể đăng nhập" : "Chưa khả dụng")
                    ForEach(methods.providers, id: \.provider) { provider in
                        LabeledContent(provider.provider == "google" ? "Google" : "Nhà cung cấp khác",
                                       value: provider.usable ? "Có thể đăng nhập" : "Chưa khả dụng")
                    }
                    LabeledContent("Mã khôi phục", value: methods.codesEnrolled ? "Đã tạo" : "Chưa tạo")
                }
                if !model.codes.isEmpty {
                    Section("Mã mới — chỉ hiển thị lần này") {
                        Text("Lưu các mã này ngay. Chúng sẽ biến mất khi rời màn hình hoặc xác nhận.")
                        ForEach(model.codes, id: \.self) { code in Text(code) }
                        Button("Tôi đã lưu các mã") { model.acknowledgeCodes() }
                    }
                }
                if methods.passwordUsable {
                    Section {
                        Button(methods.codesEnrolled ? "Xoay mã khôi phục" : "Tạo mã khôi phục") {
                            model.beginPrompt(.rotateRecoveryCodes)
                        }.disabled(!model.canRotate)
                        if methods.canUnlinkGoogle {
                            Button("Gỡ Google", role: .destructive) { model.beginPrompt(.unlinkIdentity) }
                                .disabled(!model.canUnlink)
                        }
                    }
                }
                Section { Button("Làm mới trạng thái") { model.refresh() }.disabled(model.busy) }
            } else {
                Section {
                    Text("Chưa tải được trạng thái phương thức từ Binblog.")
                    Button("Tải lại") { model.refresh() }.disabled(model.busy)
                }
            }
        }
        .opacity(model.privacySuspended ? 0 : 1)
        .overlay {
            if model.privacySuspended { Color(uiColor: .systemBackground).ignoresSafeArea() }
        }
        .navigationTitle("Phương thức đăng nhập")
        .navigationBarBackButtonHidden(model.writeInFlight || !model.codes.isEmpty)
        .task { model.refresh() }
        .onAppear { if scenePhase != .active { model.suspendForPrivacy() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.resumeForPrivacy()
                if model.methods == nil { model.refresh() }
            }
            else { model.suspendForPrivacy() }
        }
        .onDisappear { model.cancel() }
        .sheet(isPresented: Binding(get: { model.requested != nil }, set: { if !$0 { model.dismissPrompt() } })) {
            if model.privacySuspended {
                Color(uiColor: .systemBackground).ignoresSafeArea()
            } else {
                NavigationStack {
                    Form {
                        Text(model.requested == .unlinkIdentity
                             ? "Chỉ tiếp tục khi mật khẩu Binblog còn dùng được. Máy chủ sẽ kiểm tra lại phương thức cuối cùng."
                             : "Bộ mã cũ sẽ không còn dùng được. Mã mới chỉ hiển thị một lần.")
                        SecureField("Mật khẩu Binblog", text: Binding(get: { model.password }, set: { model.password = $0 }))
                            .textContentType(.password)
                    }
                    .navigationTitle("Xác minh mật khẩu")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Hủy") { model.dismissPrompt() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Xác minh và tiếp tục") { model.submitPrompt() }
                                .disabled(model.password.isEmpty)
                        }
                    }
                }
            }
        }
    }
}
