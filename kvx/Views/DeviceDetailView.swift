//
//  DeviceDetailView.swift
//  kvx
//
//  Created by Vinh Nguyen on 4/9/26.
//

import SwiftUI

struct DeviceDetailView: View {
    let device: Device
    @State private var isOn = false
    @State private var schedules: [Schedule] = []
    @State private var showingAddSchedule = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                deviceInfoCard
                controlSection
                scheduleSection
            }
            .padding()
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSchedule) {
            AddScheduleSheet(deviceId: device.id) { newSchedule in
                schedules.append(newSchedule)
            }
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: deviceIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(device.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if device.type == .temperature {
                    HStack(spacing: 8) {
                        if let temp = device.temperature {
                            Label(String(format: "%.1f°C", temp), systemImage: "thermometer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let humidity = device.humidity {
                            Label(String(format: "%d%%", Int(humidity)), systemImage: "humidity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            statusBadge
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(device.status.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
    }

    // MARK: - Control Section

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Điều khiển thiết bị")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                Text("Bật/Tắt thiết bị")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.green)

                Text(isOn ? "BẬT" : "TẮT")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOn ? .green : .red)
                    .frame(width: 40)
            }

            Divider()

            Button(action: {
                // Refresh action
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Làm mới")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Hẹn giờ")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingAddSchedule = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }

            if schedules.isEmpty {
                emptyScheduleState
            } else {
                scheduleList
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var emptyScheduleState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Chưa có lịch hẹn giờ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var scheduleList: some View {
        VStack(spacing: 8) {
            ForEach(schedules) { schedule in
                ScheduleRow(schedule: schedule) {
                    toggleSchedule(schedule)
                } onDelete: {
                    deleteSchedule(schedule)
                }
            }
        }
    }

    // MARK: - Helpers

    private var deviceIcon: String {
        switch device.type {
        case .iPhone: return "iphone"
        case .iPad: return "ipad"
        case .simulator: return "desktopcomputer"
        case .temperature: return "thermometer"
        case .switch: return "power"
        }
    }

    private var statusColor: Color {
        switch device.status {
        case .online: return .green
        case .offline: return .gray
        case .busy: return .orange
        }
    }

    private func toggleSchedule(_ schedule: Schedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule.copyWith(isActive: !schedule.isActive)
        }
    }

    private func deleteSchedule(_ schedule: Schedule) {
        schedules.removeAll { $0.id == schedule.id }
    }
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let schedule: Schedule
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.timeString)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(schedule.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: .constant(schedule.isActive))
                .labelsHidden()
                .tint(.green)
                .onChange(of: schedule.isActive) { _, _ in
                    onToggle()
                }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Add Schedule Sheet

struct AddScheduleSheet: View {
    let deviceId: String
    let onAdd: (Schedule) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime = Date()
    @State private var selectedType: Schedule.ScheduleType = .daily

    var body: some View {
        NavigationStack {
            Form {
                Section("Thời gian") {
                    DatePicker(
                        "Chọn giờ",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                }

                Section("Loại lịch hẹn") {
                    Picker("Loại", selection: $selectedType) {
                        ForEach(Schedule.ScheduleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Thêm lịch hẹn giờ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Thêm") {
                        let schedule = Schedule(
                            deviceId: deviceId,
                            time: selectedTime,
                            type: selectedType
                        )
                        onAdd(schedule)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DeviceDetailView(device: Device.sampleDevices[0])
    }
}
