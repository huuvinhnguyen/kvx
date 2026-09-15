import SwiftUI
import Charts

struct PIRDetailView: View {
    let device: Device
    @StateObject private var model = PIRViewModel()
    @State private var selectedHour: Int?
    private let accent = Color(red: 0.20, green: 0.83, blue: 0.60)
    private let surface = Color(red: 0.08, green: 0.13, blue: 0.14)
    private let colors: [Color] = [Color(white: 0.16), Color(red: 0.11, green: 0.30, blue: 0.26), Color(red: 0.16, green: 0.44, blue: 0.36), Color(red: 0.23, green: 0.61, blue: 0.48), Color(red: 0.20, green: 0.83, blue: 0.60)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                card {
                    Label("CẢM BIẾN CHUYỂN ĐỘNG", systemImage: "sensor.tag.radiowaves.forward")
                        .font(.caption.weight(.semibold)).foregroundStyle(accent)
                    Text(device.name).font(.title2.bold())
                    HStack {
                        Label(device.status.rawValue, systemImage: "circle.fill")
                            .foregroundStyle(device.status == .online ? accent : .gray)
                        Spacer()
                        Text("PIR").foregroundStyle(.secondary)
                    }.font(.caption)
                    Text(device.chipID ?? "Chưa có mã chip").font(.caption.monospaced()).foregroundStyle(.secondary)
                }

                card {
                    Text("Phát hiện chuyển động").font(.headline)
                    Text("Thống kê theo giờ • Giờ Việt Nam (UTC+7)")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Ngày trước")
                        DatePicker("Chọn ngày", selection: $model.selectedDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden().frame(maxWidth: .infinity)
                        Button { moveDay(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Ngày sau")
                            .disabled(PIRCalendar.key(model.selectedDate) >= PIRCalendar.key(Date()))
                    }.buttonStyle(.bordered).tint(accent)
                    if model.isLoading {
                        ProgressView("Đang tải thống kê…").frame(maxWidth: .infinity, minHeight: 180)
                    } else if let error = model.error {
                        Text(error).foregroundStyle(.orange)
                        Button("Thử lại") { Task { await model.load(chipID: device.chipID) } }
                    } else if let stats = model.statistics {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(stats.total)").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(accent)
                            Text("lần phát hiện").font(.subheadline).foregroundStyle(.secondary)
                        }
                        hourlyChart(stats)
                        if stats.total == 0 {
                            Text("Không có chuyển động trong ngày này.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                card {
                    Text("Mật độ phát hiện — 30 ngày").font(.headline)
                    Text("Chạm một ngày để xem biểu đồ theo giờ.").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(model.days) { day in
                            Button {
                                if let date = PIRCalendar.date(day.date) { model.selectedDate = date }
                            } label: {
                                VStack(spacing: 5) {
                                    Text(day.shortLabel).font(.system(size: 10))
                                    Text("\(day.count)").font(.caption.bold())
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(colors[day.level], in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(day.date == PIRCalendar.key(model.selectedDate) ? .white : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(day.date): \(day.count) lần phát hiện")
                            .accessibilityAddTraits(day.date == PIRCalendar.key(model.selectedDate) ? .isSelected : [])
                        }
                    }
                    if model.days.isEmpty { Text("Chưa tải được mật độ chuyển động.").font(.caption).foregroundStyle(.secondary) }
                    HStack(spacing: 6) {
                        Text("0")
                        ForEach(0..<5) { level in RoundedRectangle(cornerRadius: 3).fill(colors[level]).frame(width: 18, height: 12) }
                        Text("16+ lần")
                    }.font(.caption2).foregroundStyle(.secondary)
                    Text("Mức màu: 0 · 1–3 · 4–8 · 9–15 · 16+ lần")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                card {
                    Label("Lịch sử chuyển động", systemImage: "clock.arrow.circlepath").font(.headline)
                    Text("20 sự kiện mới nhất").font(.caption).foregroundStyle(.secondary)
                    if let events = model.events {
                        if events.isEmpty {
                            Text("Chưa có sự kiện chuyển động.").foregroundStyle(.secondary)
                        }
                        ForEach(events) { event in
                            HStack(spacing: 12) {
                                Image(systemName: "figure.walk").foregroundStyle(accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Phát hiện chuyển động").font(.subheadline)
                                    if let date = event.timestamp {
                                        Text(date, format: .dateTime.day().month().year().hour().minute().second().timeZone(.specificName(.short)))
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text(event.occurred_at).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Divider()
                        }
                    } else {
                        Text("Lịch sử chi tiết chưa khả dụng trên ứng dụng.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }.padding(16)
        }
        .background(Color(red: 0.035, green: 0.065, blue: 0.07))
        .preferredColorScheme(.dark)
        .environment(\.timeZone, PIRCalendar.calendar.timeZone)
        .environment(\.calendar, PIRCalendar.calendar)
        .navigationTitle("Thiết bị PIR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button { Task { await model.load(chipID: device.chipID) } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Làm mới") }
        .refreshable { await model.load(chipID: device.chipID) }
        .task(id: PIRCalendar.key(model.selectedDate)) {
            selectedHour = nil
            await model.load(chipID: device.chipID)
        }
    }

    private func hourlyChart(_ stats: PIRStatistics) -> some View {
        VStack(alignment: .leading) {
            Chart(0..<24, id: \.self) { hour in
                BarMark(x: .value("Giờ", hour), y: .value("Số lần", stats.values[hour]))
                    .foregroundStyle(accent).cornerRadius(3)
                    .accessibilityLabel(String(format: "%02d:00", hour))
                    .accessibilityValue("\(stats.values[hour]) lần")
            }
            .chartXScale(domain: -1...24)
            .chartYScale(domain: 0...max(1, stats.values.max() ?? 1))
            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
            .chartXSelection(value: $selectedHour)
            .frame(height: 190)
            if let hour = selectedHour, (0..<24).contains(hour) {
                Text(String(format: "%02d:00–%02d:00: %d lần", hour, hour + 1, stats.values[hour]))
                    .font(.caption).foregroundStyle(accent)
            } else {
                Text("Chạm hoặc kéo trên biểu đồ để xem số lần.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func moveDay(_ offset: Int) {
        if let date = PIRCalendar.calendar.date(byAdding: .day, value: offset, to: model.selectedDate) {
            model.selectedDate = date
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18).background(surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.07)))
    }
}
