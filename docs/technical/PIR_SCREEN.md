# Màn hình PIR — Swift và Flutter

Mở thiết bị có `device_type: "pir"` trong danh sách thiết bị. Cả hai ứng dụng
hiển thị dashboard PIR thay cho các điều khiển bật/tắt và hẹn giờ.

## Chức năng

- Tên, trạng thái và mã chip thiết bị.
- Ngày mặc định là hôm nay theo Asia/Ho_Chi_Minh (UTC+7).
- Chọn ngày, lùi/tiến ngày; không chọn ngày tương lai.
- Biểu đồ 24 cột, tổng số lần phát hiện và chạm để xem chi tiết từng giờ.
- Heatmap 30 ngày, chọn ô ngày để đổi biểu đồ.
- Mức màu: 0, 1–3, 4–8, 9–15, 16+ lần.
- 20 sự kiện chuyển động mới nhất của thiết bị, không phụ thuộc ngày thống kê.
- Làm mới, kéo để làm mới, trạng thái tải, lỗi/thử lại và ngày không có chuyển động.
- Phản hồi cũ không ghi đè dữ liệu khi người dùng đổi ngày nhanh.

## API

Cùng sử dụng `https://khuonvien.vn`, Bearer JWT và **chip_id**, không dùng ID số
trong database làm mã chip.

- `GET /api/devices/motion_stats?chip_id=...&date=YYYY-MM-DD`
  - `date`, `values` (24 số nguyên không âm), `total`.
  - `recent_events`: tối đa 20 phần tử, mới nhất trước; mỗi phần tử có
    `id`, `event_type: motion_detected`, `occurred_at` (ISO 8601).
- `GET /api/devices/motion_heatmap?chip_id=...&days=30`
  - `data`: các phần tử `{date, count}`.

Swift dùng access token trong UserDefaults như ứng dụng hiện tại.
Flutter dùng chung datasource đăng nhập/danh sách thiết bị; token được giữ trong
bộ nhớ, các request đồng thời dùng chung lần đăng nhập và token bị loại khi gặp 401.

## Thay đổi backend đi kèm

Repository `/Users/vinhnguyen/Documents/ror/binblog` bổ sung `recent_events`
vào API thống kê hiện có và cập nhật Swagger cùng request tests.
Truy vấn sự kiện nằm sau kiểm tra quyền sở hữu thiết bị, chỉ lấy `motion_detected`,
sắp xếp `occurred_at DESC, id DESC`, giới hạn 20. Không cần migration.

**Cần phát hành thay đổi backend này để lịch sử hiện trên môi trường thật.**
Với backend cũ không trả `recent_events`, biểu đồ vẫn hoạt động và khu vực lịch sử
hiển thị “Lịch sử chi tiết chưa khả dụng trên ứng dụng.” Không dùng dữ liệu demo
trong luồng ứng dụng thật.

## Mã nguồn chính

Swift:
- `kvx/Views/PIR/PIRDetailView.swift`
- `kvx/ViewModels/PIRViewModel.swift`
- `kvx/Services/PIRAPIClient.swift`
- `kvx/Models/PIRStatistics.swift`

Flutter:
- `kvx_flutter/lib/presentation/screens/pir_detail_screen.dart`
- `kvx_flutter/lib/data/repositories/pir_repository.dart`
- `kvx_flutter/lib/domain/entities/pir_statistics.dart`

## Kiểm tra

```bash
cd kvx_flutter
flutter test test/pir/pir_test.dart
flutter build ios --simulator --no-pub
```

Swift: chạy `PIRStatisticsTests` trong Xcode hoặc `xcodebuild test` với simulator
có sẵn. Tests kiểm tra dữ liệu 24 giờ, ngưỡng heatmap, múi giờ và lịch sử API.
Flutter bổ sung tests mapping chip ID, request xác thực, lỗi/thử lại và phản hồi
đến sai thứ tự khi đổi ngày/nhấn heatmap.

Backend:

```bash
bundle exec rspec spec/requests/api/device_motion_statistics_spec.rb spec/requests/api/device_motion_statistics_swagger_spec.rb
```

Xem `BUILD.md` để cấu hình đăng nhập và chạy ứng dụng. Kiểm tra API trong task này
dùng mock/request tests; chưa xác minh bằng tài khoản và thiết bị production.

## Kết quả kiểm tra triển khai

- 4 tests PIR Swift: đạt trên iPhone 17 Pro simulator.
- 6 tests PIR Flutter: đạt.
- 11 request/Swagger tests Rails: đạt.
- Kiểm tra tĩnh các tệp PIR Flutter: không có vấn đề.
- Render Flutter với dữ liệu demo ở 390 × 844: biểu đồ, heatmap và lịch sử không tràn bố cục.
- Phân tích toàn dự án Flutter vẫn báo lỗi import có sẵn trong
  `relay_widgets_demo_screen.dart` (trỏ đến thư mục `widgets/relay/` không tồn tại).
  Các lỗi này không nằm trong luồng ứng dụng chính/PIR.

## Sửa lỗi native không thấy PIR (15/09/2026)

Điều tra simulator xác nhận:

- iPhone 16 Pro còn cài binary ngày 06/09, chưa chứa `PIRDetailView`.
- iPhone 16 đã có màn PIR nhưng cả hai simulator đều chưa có `binblog.accessToken`.
- Native khởi tạo danh sách bằng `Device.sampleDevices` và giữ nguyên khi API lỗi;
  vì vậy người dùng thấy thiết bị mẫu thay vì danh sách tài khoản thật.
- `run_kvx.sh` tìm `.app` đầu tiên trong toàn bộ DerivedData, có thể cài nhầm bản cũ.

Đã sửa:

- Danh sách native khởi tạo rỗng; thiếu token/401 yêu cầu đăng nhập và xóa dữ liệu
  của phiên cũ khỏi màn hình.
- Thêm màn đăng nhập Binblog, dùng cùng API và tài khoản với Flutter; không lưu mật khẩu.
- Script dùng đường dẫn build xác định và simulator ID cụ thể, rồi khởi động lại app.
- Giữ `chipID` khi cập nhật trạng thái thiết bị để không làm mất định danh PIR.

Mở native và chọn **Đăng nhập Binblog**, dùng cùng tài khoản Flutter.
Bản native và Flutter là hai ứng dụng riêng; trạng thái đăng nhập không tự chia sẻ.

Kiểm chứng bản sửa: 4 `NativeDeviceLoadingTests` đạt trên iOS 18.1, gồm thiếu token,
phiên hết hạn, đăng nhập và mapping PIR từ API. Dữ liệu test được giả lập; người dùng
cần đăng nhập trong ứng dụng để xác minh danh sách thiết bị của tài khoản thật.
