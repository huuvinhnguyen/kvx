# Triển khai màn Buzzer — Swift native và Flutter

Cập nhật: 2026-09-18. Task: [Device 59 / BinBlog](../../ai/tasks/2026-09-17-device-59-binblog-parity.md).

## Kết quả

Thiết bị có `device_type: buzzer` được nhận diện đúng trong danh sách và mở màn Buzzer riêng trên SwiftUI/Flutter. Có thông tin thiết bị, PIR liên kết, lịch sử motion, Test Buzzer, làm mới, khởi động lại và đổi WiFi. Không có WebView, HTML nhúng hoặc điều khiển/lịch hẹn giả lập trong luồng Buzzer thật.

Backend BinBlog local đã có API JSON xác thực, kiểm tra quyền và tái sử dụng logic test MQTT hiện có. **Cần phát hành backend lên môi trường app đang gọi trước khi dùng tính năng với dữ liệu thật.** Code mặc định tiếp tục dùng `https://khuonvien.vn`, giống luồng thiết bị hiện tại. Không tự deploy, không commit/push.

## Thiết kế

- Entity và repository contract của Buzzer tách khỏi UI/HTTP; use case xác minh identity và cấu hình test trước khi gửi.
- Swift dùng `@Observable` view model, Flutter dùng `ChangeNotifier`/Provider. Cả hai được inject use case, bỏ qua kết quả request cũ và không cập nhật sau khi màn mất hiệu lực/dispose.
- API detail trả metadata và dữ liệu Buzzer riêng; không đưa JSON thô vào model thiết bị chung. Mapper danh sách chỉ cần thêm loại `buzzer`; không làm đổi trạng thái các loại cũ.
- Flutter dùng chung datasource/token đang có; Swift dùng `AccessTokenProvider` hiện hữu. 401 xóa detail và mở luồng đăng nhập lại. Mất quyền/404 xóa snapshot để tránh tiếp tục điều khiển thiết bị không còn truy cập được.
- Phân biệt GET tải lại với POST refresh phần cứng. POST thành công chỉ báo gửi lệnh tới broker, sau đó GET lại. GET sau POST thất bại giữ thông tin lệnh đã gửi và báo lỗi tải dữ liệu; không replay POST.
- Cooldown test 3 giây do server quyết định, app khóa nút theo receipt/429. Không bỏ qua giới hạn khi bấm lặp. Request pending khóa các lệnh khác.
- Giữ online rule 5 phút, lịch sử 200 ứng viên → lọc target → 20 sự kiện và quyền nguồn PIR như BinBlog. Hiển thị UTC+7, duration ms, kênh index như web.
- Swift dùng màu semantic và control chuẩn. Flutter dùng màu theme, text wrapping và layout dọc; dark mode được giới hạn trong màn Buzzer để không ảnh hưởng các màn legacy có màu cố định.
- Dùng API riêng `/api/buzzers/:id` thay vì mở rộng các lệnh legacy chưa có cùng kiểm tra quyền. Xem [contract](../api/device-detail-binblog-contract.md).

## Kiểm chứng

Swift:

```bash
xcodebuild -project kvx.xcodeproj -scheme kvx -sdk iphonesimulator \
  -configuration Debug -derivedDataPath /tmp/kvx-buzzer-build \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild test -project kvx.xcodeproj -scheme kvx \
  -destination 'platform=iOS Simulator,id=C48C8E01-FE9E-4709-BCB8-5B54AD88C6B0' \
  -derivedDataPath /tmp/kvx-buzzer-build -only-testing:kvxTests CODE_SIGNING_ALLOWED=NO
```

- Build: **PASS**.
- Unit tests: lần kiểm chứng mới nhất sau [đổi tên BuzzerAPIClient](../../ai/tasks/2026-09-18-buzzer-api-client-alignment.md) có **93 PASS** (73 XCTest + 20 Swift Testing), trong đó **11 Buzzer**; gồm các test PIR, relay và tải thiết bị có sẵn. Task refactor ghi lệnh và simulator thực dùng cho lần kiểm chứng này.
- Kiểm tra fixture chung, timezone, duration boundary, auth, snapshot cũ, duplicate command, cooldown, failure và response sau khi rời màn.
- Swift UI automation/VoiceOver trên màn Buzzer: **NOT RUN**. Logic view được rà soát và compile, không suy diễn unit tests thành kiểm chứng UI đầy đủ.

Flutter (từ `kvx_flutter/`):

```bash
flutter test
flutter build ios --simulator --no-pub
```

- Tests: **62 PASS**, gồm **15 Buzzer** và regression PIR/relay.
- Buzzer widget tests: route native Flutter, dialog test confirm/cancel, cancel reset WiFi, offline/empty/error/retry; kích thước 390×844, text scale 1,6, sáng/tối.
- Build iOS simulator: **PASS**.
- `flutter analyze` trên 13 file Buzzer/tích hợp/test: **PASS, no issues**. Bao gồm use case, entity, contract, DTO, repository, datasource auth, provider, Buzzer screen, list mapping, presentation extension, app entry và test Buzzer.
- `flutter analyze` toàn repo: **FAIL do lỗi có sẵn** trong `relay_widgets_demo_screen.dart` (imports tới `widgets/relay/` không tồn tại và các symbol liên quan), cùng warning/deprecation ở các file legacy. Không sửa demo relay trong task này.

Backend (từ repo `binblog/`):

```bash
bundle exec rspec spec/requests/api/buzzers_spec.rb \
  spec/services/buzzer_device_command_service_spec.rb \
  spec/services/buzzer_test_service_spec.rb \
  spec/requests/devices_test_buzzer_spec.rb \
  spec/requests/api/device_motion_statistics_spec.rb
```

- **39 examples, 0 failures**. MQTT được mock, database ở test environment.
- Kiểm tra mọi endpoint cần auth, thiết bị không có quyền/sai loại không phát lệnh, history window/filter, dữ liệu rỗng/lỗi, online boundary, cooldown, duration biên, error response và tương thích route test web/PIR.
- `git diff --check` ở KVX và BinBlog: **PASS**.
- Không gửi lệnh lên thiết bị/broker thật trong kiểm thử.

## Acceptance criteria

- [x] Người dùng xác nhận Buzzer, Swift native và Flutter; code không phụ thuộc ID 59.
- [x] SwiftUI/Flutter widgets, không WebView.
- [x] Đủ section/action của nhánh Buzzer theo mã BinBlog.
- [x] Identity, timezone, duration, quyền nguồn PIR và history được test.
- [x] Không báo phần cứng thành công chỉ vì HTTP/MQTT publish thành công.
- [x] Loading/error/empty/offline, retry, 401, mất quyền, stale response và duplicate commands có kiểm thử.
- [x] Refresh chỉ gửi refresh; lệnh test/reset/restart có dialog. Flutter kiểm thử tương tác confirm/cancel; Swift rà soát code.
- [x] Duration 100–10.000 ms và cooldown có kiểm thử backend/mobile.
- [x] Unit/widget tests và build hai nền tảng đạt.
- [ ] Đối chiếu trực quan với trang 59 đã đăng nhập; phiên khảo sát chưa mở được trang đó.
- [ ] Nghiệm thu VoiceOver/TalkBack và UI Swift trên thiết bị thật.
- [ ] Deploy API lên môi trường thực, đăng nhập và xác minh với Buzzer thật.

## Files thay đổi

Trong KVX — Swift:

- `kvx/Models/Device.swift`
- `kvx/Models/BuzzerDetail.swift`
- `kvx/Services/DeviceAPIClient.swift`
- `kvx/Domain/Repositories/BuzzerRepository.swift`
- `kvx/Domain/UseCases/BuzzerUseCases.swift`
- `kvx/Services/BuzzerAPIClient.swift`
- `kvx/ViewModels/BuzzerViewModel.swift`
- `kvx/Views/Buzzer/BuzzerDetailView.swift`
- `kvx/Views/DeviceDetailView.swift`
- `kvx/Views/DeviceListView.swift`
- `kvxTests/BuzzerTests.swift`
- `kvxTests/Fixtures/buzzer-detail.json` — fixture giả lập dùng chung hai nền tảng.

Trong KVX — Flutter:

- `kvx_flutter/lib/domain/entities/device.dart`
- `kvx_flutter/lib/domain/entities/buzzer_detail.dart`
- `kvx_flutter/lib/domain/repositories/buzzer_repository.dart`
- `kvx_flutter/lib/application/usecases/buzzer_usecases.dart`
- `kvx_flutter/lib/data/datasources/binblog_device_datasource.dart`
- `kvx_flutter/lib/data/models/binblog_device_dto.dart`
- `kvx_flutter/lib/data/models/buzzer_detail_dto.dart`
- `kvx_flutter/lib/data/repositories/binblog_buzzer_repository.dart`
- `kvx_flutter/lib/presentation/providers/buzzer_provider.dart`
- `kvx_flutter/lib/presentation/screens/buzzer_detail_screen.dart`
- `kvx_flutter/lib/presentation/screens/device_detail_screen.dart`
- `kvx_flutter/lib/presentation/extensions/device_presentation.dart`
- `kvx_flutter/lib/presentation/widgets/device_info_header.dart`
- `kvx_flutter/lib/main.dart`
- `kvx_flutter/test/buzzer/buzzer_test.dart`

Trong KVX — tài liệu:

- `ai/tasks/2026-09-17-device-59-binblog-parity.md`
- `docs/requirements/device-detail-binblog-parity.md`
- `docs/api/device-detail-binblog-contract.md`
- `docs/technical/device-detail-binblog-parity.md`

Trong `/Users/vinhnguyen/Documents/ror/binblog`:

- `app/controllers/api/buzzers_controller.rb`
- `app/services/buzzer_detail_query.rb`
- `app/services/buzzer_device_command_service.rb`
- `app/services/buzzer_test_service.rb`
- `config/routes.rb`
- `spec/requests/api/buzzers_spec.rb`
- `spec/services/buzzer_device_command_service_spec.rb`
- `spec/services/buzzer_test_service_spec.rb`

## Hạn chế và ngoài phạm vi

- Không triển khai lại PIR/DHT/relay, không sửa các lỗi demo relay được phát hiện bởi analyze. Nên xử lý demo relay trong task riêng.
- Cooldown backend đã chuyển sang Redis atomic dùng chung web/API, có kiểm thử cạnh tranh 8 client và TTL trên Redis cô lập thật. Deployment phải cấu hình cùng endpoint/database cho mọi worker; chưa xác minh hạ tầng production. Xem [báo cáo remediation](buzzer-review-remediation.md).
- API mới chưa được xác minh trên production; trước deploy app có thể thấy thông báo thiếu endpoint/không tìm thấy Buzzer.
- Snapshot sau refresh có thể chưa mới do thiết bị chưa phản hồi. Không có telemetry xác nhận phần cứng trong contract hiện tại.
- Không thu thập hoặc ghi credential/token thật vào fixture, tài liệu hoặc log kiểm thử.

## Bản sửa sau review — 2026-09-18

Đã khắc phục R1/R2/R3 bằng `BuzzerTestCooldown` và tách xử lý publish/audit/disconnect trong BinBlog. Backend fail-closed 503 khi Redis không khả dụng; không release reservation trên mọi nhánh lỗi. SwiftUI, Flutter và `BuzzerAPIClient` giữ nguyên. 73 regression examples Buzzer/PIR đạt; chi tiết file, lệnh, acceptance criteria và giới hạn trong [báo cáo remediation](buzzer-review-remediation.md).
