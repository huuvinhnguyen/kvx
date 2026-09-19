# Buzzer dùng dữ liệu Device chung

Ngày 2026-09-18. Sửa theo yêu cầu: switch, PIR và Buzzer cùng lấy thông tin thiết bị từ luồng Device Detail.

## Nguyên nhân và thay đổi

Danh sách đã tải `Device` từ `/api/devices` và truyền vào Device Detail cho mọi type. Switch/PIR hiển thị phần này trực tiếp. Buzzer trước đây chỉ hiển thị header khi `BuzzerAPIClient.detail` thành công, khiến HTTP 404 của endpoint mở rộng che mất cả thông tin Device đã có.

SwiftUI và Flutter hiện luôn hiển thị tên, chip ID, trạng thái (bao gồm Busy) từ Device, giống PIR. API Buzzer vẫn tải dữ liệu mở rộng (liên kết, lịch sử, thời lượng test) và phục vụ lệnh. Lỗi phần mở rộng hiển thị riêng, không biến thành thông báo thiết bị không tồn tại và không tạo lịch sử rỗng giả. Nút điều khiển chỉ xuất hiện khi dữ liệu mở rộng đã tải thành công.

Thông tin chung là snapshot truyền từ danh sách, giống Switch/PIR; thao tác tải lại trong Buzzer hiện chỉ đọc phần mở rộng. Chưa chuyển môi trường hoặc triển khai API. Máy chủ vẫn cần endpoint mở rộng để sử dụng các phần đó.

## File thay đổi

- `kvx/Views/Buzzer/BuzzerDetailView.swift`
- `kvx/Models/BuzzerDetail.swift`
- `kvx_flutter/lib/presentation/screens/buzzer_detail_screen.dart`
- `kvx_flutter/lib/domain/entities/buzzer_detail.dart`
- `kvx_flutter/test/buzzer/buzzer_test.dart`
- `docs/technical/buzzer-common-device-data.md`

## Kiểm chứng

- `flutter test test/buzzer/buzzer_test.dart`: 16/16 đạt, gồm widget test khi API mở rộng unavailable vẫn thấy tên/chip/Busy, không hiện lịch sử rỗng hoặc gửi lệnh.
- `xcodebuild test -project kvx.xcodeproj -scheme kvx -destination 'platform=iOS Simulator,id=65A80E5B-E316-471D-9BD7-E1B9D8FF2D01' -derivedDataPath /tmp/kvx-buzzer-build -only-testing:kvxTests -parallel-testing-enabled NO IPHONEOS_DEPLOYMENT_TARGET=17.6 CODE_SIGNING_ALLOWED=NO`: TEST SUCCEEDED, 73 XCTest + 20 Swift Testing = 93 tests. Log `/tmp/kvx-buzzer-common-device-tests.log`.
- Không chạy UI automation Swift hoặc lệnh MQTT thật.

## Acceptance criteria

- [x] Header Buzzer dùng Device chung với Switch/PIR.
- [x] Lỗi API mở rộng không làm trống phần thông tin chung.
- [x] SwiftUI và Flutter cùng hành vi, không WebView.
- [x] Không báo lịch sử rỗng/thành công giả khi API lỗi; không tự gửi lệnh.
- [ ] Dữ liệu mở rộng trên production: chưa xác minh với tài khoản; endpoint trước đó trả 404, chưa deploy trong lượt này.
