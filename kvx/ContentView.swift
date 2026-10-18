//
//  ContentView.swift
//  kvx
//
//  Created by Vinh Nguyen on 21/4/26.
//

import SwiftUI

struct ContentView: View {
    let viewModel: DeviceViewModel
    var buzzerUseCases = BuzzerUseCases(repository: BuzzerAPIClient())
    var pirRepository: any PIRRepository = PIRAPIClient()
    var accountMethodsView: AnyView?

    var body: some View {
        DeviceListView(viewModel: viewModel, buzzerUseCases: buzzerUseCases, pirRepository: pirRepository, accountMethodsView: accountMethodsView)
    }
}

#Preview {
    ContentView(viewModel: DeviceViewModel(repository: RemoteDeviceRepository()))
}
