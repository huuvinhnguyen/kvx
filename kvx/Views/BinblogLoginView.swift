import SwiftUI

struct BinblogLoginView: View {
    let onSuccess: () -> Void
    @Environment(SessionViewModel.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    private var isLoading: Bool { session.state.phase == .authenticating || session.state.clearing }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tài khoản Binblog") {
                    TextField("Tên đăng nhập", text: $username)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Mật khẩu", text: $password).textContentType(.password)
                }
                if session.state.reason == .expired { Text("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.") }
                if let message = session.state.message {
                    Text(message).foregroundStyle(.red)
                    Button("Thử lại đăng xuất") { Task { await session.logout() } }
                }
                if let errorMessage = session.loginError { Text(errorMessage).foregroundStyle(.red) }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading { ProgressView() } else { Text("Đăng nhập") }
                    }
                    .disabled(isLoading || session.state.message != nil || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                } footer: {
                    Text("Dùng cùng tài khoản với Flutter để xem cùng danh sách thiết bị.")
                }
            }
            .navigationTitle("Đăng nhập Binblog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isLoading ? "Hủy đăng nhập" : "Đóng") {
                        password = ""
                        Task { await session.logout(); dismiss() }
                    }.disabled(session.state.clearing)
                }
            }
            .interactiveDismissDisabled(isLoading)
        }
    }

    @MainActor private func login() async {
        await session.login(username: username, password: password)
        password = ""
        if session.state.phase == .authenticated {
            onSuccess()
            dismiss()
        }
    }
}
