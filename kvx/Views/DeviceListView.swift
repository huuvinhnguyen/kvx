//
//  DeviceListView.swift
//  kvx
//
//  Created by Vinh Nguyen on 22/4/26.
//

import SwiftUI

struct DeviceListView: View {
    @State private var viewModel = DeviceViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar(selectedFilter: $viewModel.selectedFilter)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                List {
                    ForEach(viewModel.filteredDevices) { device in
                        DeviceRow(device: device)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleStatus(for: device)
                            }
                    }
                    .onDelete(perform: viewModel.deleteDevices)
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.refresh()
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
            .navigationTitle("Devices")
            .searchable(text: $viewModel.searchText, prompt: "Search devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddDeviceSheet(viewModel: viewModel)
            }
        }
    }
}

struct FilterBar: View {
    @Binding var selectedFilter: DeviceViewModel.DeviceFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DeviceViewModel.DeviceFilter.allCases, id: \.self) { filter in
                FilterChip(
                    title: filter.rawValue,
                    isSelected: selectedFilter == filter
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                }
            }
            Spacer()
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }
}

struct AddDeviceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: DeviceViewModel

    @State private var name = ""
    @State private var selectedType: Device.DeviceType = .iPhone
    @State private var selectedStatus: Device.DeviceStatus = .online

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Info") {
                    TextField("Device Name", text: $name)
                    Picker("Type", selection: $selectedType) {
                        ForEach(Device.DeviceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(Device.DeviceStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 8, height: 8)
                                Text(status.rawValue)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addDevice(
                            name: name,
                            type: selectedType,
                            status: selectedStatus
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(device.type))
                .font(.title2)
                .foregroundStyle(colorForStatus(device.status))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(device.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    StatusBadge(status: device.status)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: Device.DeviceType) -> String {
        switch type {
        case .iPhone:
            return "iphone"
        case .iPad:
            return "ipad"
        case .simulator:
            return "desktopcomputer"
        }
    }

    private func colorForStatus(_ status: Device.DeviceStatus) -> Color {
        switch status {
        case .online:
            return .green
        case .offline:
            return .gray
        case .busy:
            return .orange
        }
    }
}

struct StatusBadge: View {
    let status: Device.DeviceStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(status.rawValue)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }

    private var statusColor: Color {
        switch status {
        case .online:
            return .green
        case .offline:
            return .gray
        case .busy:
            return .orange
        }
    }
}

#Preview {
    DeviceListView()
}
