import SwiftUI

struct BinblogLoginView: View {
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Tài khoản Binblog") {
                    TextField("Tên đăng nhập", text: $username)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Mật khẩu", text: $password).textContentType(.password)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        if isLoading { ProgressView() } else { Text("Đăng nhập") }
                    }
                    .disabled(isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
                } footer: {
                    Text("Dùng cùng tài khoản với Flutter để xem cùng danh sách thiết bị.")
                }
            }
            .navigationTitle("Đăng nhập Binblog")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() }.disabled(isLoading) } }
            .interactiveDismissDisabled(isLoading)
        }
    }

    @MainActor private func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let token = try await BinblogLoginClient().login(username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            UserDefaults.standard.set(token, forKey: "binblog.accessToken")
            password = ""
            onSuccess()
            dismiss()
        } catch {
            errorMessage = "Đăng nhập thất bại. Kiểm tra tài khoản và kết nối rồi thử lại."
        }
    }
}
