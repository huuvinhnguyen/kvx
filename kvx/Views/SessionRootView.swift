import SwiftUI

struct SessionRootView: View {
    @State private var model: SessionViewModel

    init(coordinator: SessionCoordinator) {
        _model = State(initialValue: SessionViewModel(coordinator: coordinator))
    }
    var body: some View {
        Group {
            switch model.state.phase {
            case .unknown, .restoring:
                VStack(spacing: 16) {
                    if let message = model.state.message {
                        Text(message)
                        Button("Thử lại") { Task { await model.retryRestore() } }
                        Button("Đăng xuất") { Task { await model.logout() } }
                    } else { ProgressView("Đang khôi phục phiên…") }
                }.padding()
            case .signedOut, .authenticating:
                BinblogLoginView(onSuccess: {})
            case .authenticated:
                AuthenticatedContent(coordinator: model.coordinator, generation: model.state.generation)
                    .id(model.state.generation)
            }
        }
        .environment(model)
        .task { await model.observeAndRestore() }
    }
}

private struct AuthenticatedContent: View {
    let coordinator: SessionCoordinator
    let generation: UInt64
    @State private var devices: DeviceViewModel
    private let buzzerUseCases: BuzzerUseCases
    private let pirRepository: PIRAPIClient

    init(coordinator: SessionCoordinator, generation: UInt64) {
        self.coordinator = coordinator
        self.generation = generation
        let transport = AuthenticatedTransport(authority: coordinator, generation: generation)
        _devices = State(initialValue: DeviceViewModel(repository: RemoteDeviceRepository(dataSource: BinblogDeviceDataSource(transport: transport))))
        buzzerUseCases = BuzzerUseCases(repository: BuzzerAPIClient(transport: transport))
        pirRepository = PIRAPIClient(transport: transport)
    }
    var body: some View {
        ContentView(viewModel: devices, buzzerUseCases: buzzerUseCases, pirRepository: pirRepository)
    }
}
