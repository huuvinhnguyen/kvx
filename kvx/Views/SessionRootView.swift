import SwiftUI

struct SessionRootView: View {
    @State private var model: SessionViewModel
    @State private var accountMethodsContinuity: AccountMethodsContinuity?

    init(coordinator: SessionCoordinator, googleSignIn: GoogleSignInUseCase? = nil) {
        _model = State(initialValue: SessionViewModel(coordinator: coordinator, googleSignIn: googleSignIn))
        _accountMethodsContinuity = State(initialValue: nil)
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
                if let continuity = accountMethodsContinuity,
                   continuity.generation == model.state.generation {
                    AuthenticatedContent(coordinator: model.coordinator, generation: model.state.generation,
                                         accountMethodsContinuity: continuity)
                        .id(model.state.generation)
                } else { ProgressView("Đang mở phiên…") }
            }
        }
        .environment(model)
        .task { await model.observeAndRestore() }
        .onChange(of: model.state.generation) { _, generation in
            accountMethodsContinuity?.invalidate()
            accountMethodsContinuity = model.state.phase == .authenticated
                ? AccountMethodsContinuity(generation: generation, gate: model.state.reconciliation) : nil
        }
        .onChange(of: model.state.reconciliation) { _, gate in
            accountMethodsContinuity?.applyGate(gate)
        }
    }
}

private struct AuthenticatedContent: View {
    let coordinator: SessionCoordinator
    let generation: UInt64
    @State private var devices: DeviceViewModel
    let accountMethodsContinuity: AccountMethodsContinuity
    private let buzzerUseCases: BuzzerUseCases
    private let pirTriggerActionUseCases: PIRTriggerActionUseCases
    private let pirRepository: PIRAPIClient

    init(coordinator: SessionCoordinator, generation: UInt64,
         accountMethodsContinuity: AccountMethodsContinuity) {
        self.coordinator = coordinator
        self.generation = generation
        self.accountMethodsContinuity = accountMethodsContinuity
        let transport = AuthenticatedTransport(authority: coordinator, generation: generation)
        _devices = State(initialValue: DeviceViewModel(repository: RemoteDeviceRepository(dataSource: BinblogDeviceDataSource(transport: transport))))
        buzzerUseCases = BuzzerUseCases(repository: BuzzerAPIClient(transport: transport))
        pirRepository = PIRAPIClient(transport: transport)
        pirTriggerActionUseCases = PIRTriggerActionUseCases(repository: PIRTriggerActionAPIClient(transport: transport))
    }
    var body: some View {
        ContentView(viewModel: devices, buzzerUseCases: buzzerUseCases, pirRepository: pirRepository,
                    pirTriggerActionUseCases: pirTriggerActionUseCases,
                    accountMethodsView: AnyView(AccountMethodsView(coordinator: coordinator, generation: generation,
                                                                    continuity: accountMethodsContinuity)))
    }
}
