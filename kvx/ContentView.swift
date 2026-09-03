//
//  ContentView.swift
//  kvx
//
//  Created by Vinh Nguyen on 21/4/26.
//

import SwiftUI

struct ContentView: View {
    let viewModel: DeviceViewModel

    var body: some View {
        DeviceListView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(viewModel: DeviceViewModel(repository: RemoteDeviceRepository()))
}
