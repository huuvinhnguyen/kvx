# Architecture Decision: xử lý kết quả review Buzzer

- Ngày: 2026-09-18.
- Vai trò: Architect, theo `ai/agents/architect.md`.
- Trạng thái: Developer đã hoàn tất T01–T04 ngày 2026-09-18; 73 regression examples đạt. Chưa deploy hoặc kiểm thử phần cứng thật.
- Phạm vi: độ tin cậy của Test Buzzer trên BinBlog, dùng chung cho web và mobile. Giữ SwiftUI/Flutter, `BuzzerAPIClient` và API detail hiện có.

## Kết luận về review

Ba phát hiện của Reviewer đều có cơ sở và đã tái hiện bằng script `/tmp/kvx-buzzer-review.rb`, dùng service thật với MQTT/event store giả lập, không kết nối broker hoặc thiết bị thật:

1. NullStore: hai lần gọi ngay liên tiếp → hai lần publish.
2. Publish thành công rồi ghi audit lỗi: hai lần gọi ngay liên tiếp → hai lần publish, dù dùng MemoryStore.
3. Publish thành công rồi disconnect lỗi: `IOError` thoát ra, không thuộc `BuzzerTestService::PublishError` mà API controller rescue.

Các lỗi nằm trong `binblog/app/services/buzzer_test_service.rb`, được API mới tái sử dụng. Chúng không phát sinh từ việc đổi tên `BinblogBuzzerRepository` thành `BuzzerAPIClient`. Không cần hoàn tác refactor client hoặc thiết kế lại toàn bộ mobile.

### Mức độ và giới hạn bằng chứng

- **R1 — P1 đối với tính năng Test Buzzer**: không thể coi cooldown là bảo đảm của backend khi dựa vào cache có thể tắt. Development hiện chọn NullStore khi thiếu `tmp/caching-dev.txt`; file này không tồn tại lúc review. Đây không phải bằng chứng production đang dùng NullStore. MemoryStore cũng không chia sẻ reservation giữa các process; mức độ ảnh hưởng deployment nhiều worker còn cần xác minh.
- **R2 — P2, phải sửa trước phát hành**: lỗi audit sau publish bị gộp thành lỗi gửi lệnh, xóa cooldown và khuyến khích gửi lại một lệnh đã được gửi.
- **R3 — P2, phải sửa trước phát hành**: exception của cleanup có thể che kết quả chính và làm response mất contract JSON đã định nghĩa.
- **Bổ sung của Architect**: publish timeout cũng là kết quả chưa xác định, không chứng minh chưa gửi. Do đó chỉ giữ cooldown khi publish trả thành công là chưa đủ; không nên xóa reservation ngay trên mọi nhánh lỗi.

## Context và nguyên nhân

`BuzzerTestService#call` hiện gộp connect, publish và ghi audit vào một `begin/rescue`; rescue mọi `StandardError`, xóa cooldown rồi chuyển thành PublishError. `disconnect` trong ensure không có rescue riêng.

Trong khi đó `BuzzerDeviceCommandService` đã xử lý disconnect riêng để tránh biến publish đã hoàn tất thành lỗi lệnh. Có thể áp dụng cùng nguyên tắc cho Test Buzzer mà không phải tạo thêm một abstraction MQTT dùng chung.

Các test cũ dùng MemoryStore và MQTT stub. Request tests phần lớn stub toàn bộ `BuzzerTestService`; chúng kiểm tra mapping HTTP tốt nhưng không phát hiện hành vi của store thật hoặc lỗi sau publish. Việc các test cũ đạt không phủ định ba phát hiện này.

## Approach

### 1. Tách giới hạn gửi lệnh khỏi Rails.cache

Thêm `BuzzerTestCooldown` là dependency được inject vào `BuzzerTestService`, với thao tác `acquire(device_id:)`. Tách hai kết quả: đang cooldown và storage không khả dụng.

**Chọn Redis chuyên cho reservation**, vì repo đã có trực tiếp `redis` và Sidekiq trong Gemfile.lock. Developer phải kiểm tra wiring Redis hiện có trước khi viết adapter; dùng endpoint/configuration đã được vận hành, key namespace riêng theo môi trường và database device ID. Không ghi URL/password vào code/log; không bật cache giao diện toàn app để chữa lỗi này.

- Reservation dùng một thao tác nguyên tử có điều kiện chưa tồn tại và TTL 3 giây, không tách `exists?` rồi `write`.
- Mọi process phục vụ web/API dùng cùng namespace/store; không có fallback âm thầm sang MemoryStore/NullStore.
- Storage lỗi hoặc cấu hình thiếu: từ chối Test Buzzer trước MQTT, trả lỗi có kiểm soát. Không tiếp tục publish khi chưa có reservation.
- Sau khi acquire thành công, để TTL hết tự nhiên, **không xóa reservation trong rescue**. Đổi lại, ngay cả lỗi connect chắc chắn chưa gửi cũng có thể phải chờ tối đa 3 giây; đây là trade-off nhỏ để tránh gửi lặp khi kết quả chưa rõ hoặc xóa nhầm reservation mới.
- Cooldown là khoảng cách giữa các lần được chấp nhận bắt đầu request, như hiện tại; không bảo đảm không có hai lần phát âm chồng nhau khi duration lớn hơn 3 giây, và không cung cấp exactly-once delivery.

### 2. Tách kết quả publish, audit và cleanup

Luồng đích: validate → acquire cooldown → connect/publish → ghi audit → disconnect.

- Validation lỗi: 422, không acquire/publish.
- Acquire bị từ chối: 429, không connect/publish.
- Store không dùng được: 503 có JSON, không connect/publish.
- Connect/publish lỗi: giữ reservation tới hết TTL; trả 502 theo contract lỗi hiện có, UI không tự retry.
- Publish trả thành công: xác lập kết quả accepted/broker_only. Ghi `buzzer_test_requested` trong nhánh riêng.
- Audit lỗi sau publish: giữ kết quả accepted và cooldown, ghi log/metric có cấu trúc để vận hành xử lý; không chuyển thành PublishError, không publish lại.
- Disconnect lỗi: ghi nhận riêng, không ghi đè kết quả accepted hoặc exception chính. Luôn thử đóng kết nối nếu đã tạo được client.
- Việc ghi log phụ cũng không được làm mất kết quả chính hoặc giải phóng cooldown.

**Trade-off audit**: cách sửa nhỏ này chấp nhận có thể thiếu event test khi database lỗi sau publish. Lịch sử motion PIR vẫn giữ nguyên. Nếu yêu cầu audit bền vững cho mọi lần gửi là bắt buộc, cần một task command journal/outbox riêng; không thể biến publish MQTT và ghi database thành một transaction nguyên tử chỉ bằng thay rescue.

### 3. Giữ contract mobile, bổ sung lỗi vận hành

Giữ response thành công `status: accepted`, `acknowledgement: broker_only`, `cooldown_seconds: 3`; giữ 422/429/502 và `Retry-After` hiện tại. Thêm 503 với mã lỗi ổn định cho storage unavailable; không trả stack trace hoặc thông tin Redis.

Swift/Flutter hiện đã xử lý non-200 và không tự gửi lại mutation, nên không cần đổi architecture/UI để sửa ba lỗi. Có thể bổ sung message cụ thể cho 503 trong task riêng nếu cần; không được báo gửi thành công khi reservation thất bại.

## Layer Changes / files ảnh hưởng

Trong repo BinBlog:

- `app/services/buzzer_test_service.rb`: inject limiter, bỏ release-on-error, tách publish/audit/cleanup.
- `app/services/buzzer_test_cooldown.rb` (mới): reservation atomic, TTL, ánh xạ lỗi storage.
- Configuration/initializer Redis phù hợp cấu trúc repo: lựa chọn sau khi kiểm tra wiring có sẵn, không đổi cache của toàn ứng dụng.
- `app/controllers/api/buzzers_controller.rb`: response 503 cho limiter unavailable; giữ các response khác.
- `app/controllers/devices_controller.rb`: cập nhật rescue của route web test cho cùng lỗi limiter; tránh API đã xử lý nhưng web vẫn HTTP 500.
- `spec/services/buzzer_test_service_spec.rb`, spec limiter mới, `spec/requests/api/buzzers_spec.rb`, `spec/requests/devices_test_buzzer_spec.rb`.

Trong KVX: cập nhật contract và kết quả kiểm chứng khi backend đã sửa. Không đổi `BuzzerRepository`, `BuzzerUseCases`, `BuzzerAPIClient`, view model/provider hoặc schema detail chỉ vì các lỗi này.

## Alternatives Considered

- Bật MemoryStore: sửa được tình huống local đơn process, không đáp ứng shared cooldown; không chọn làm giải pháp cuối.
- Dùng database reservation/conditional update: hợp lệ, dùng chung nhiều worker và ít phụ thuộc hạ tầng thêm, nhưng cần migration và kiểm thử lock trên MySQL/SQLite; là phương án thay thế nếu Redis hiện tại không phù hợp.
- Redis atomic reservation: chọn vì dependency đã có và TTL ngắn phù hợp, nhưng phải kiểm chứng cấu hình thực và hành vi khi Redis lỗi; việc có Sidekiq không tự chứng minh cấu hình cooldown đã đúng.
- Outbox/idempotency toàn bộ hệ thống: mạnh hơn cho audit/retry nhưng vượt phạm vi sửa ba lỗi; chưa đề xuất thực hiện ở task này.

## Implementation Steps

1. **T01 — Chốt limiter configuration/contract**: kiểm tra wiring Redis, xác định namespace/store chung và mapping lỗi 503 cho cả API/web. AC: không phụ thuộc `Rails.cache`, không hard-code secret, có plan deploy.
2. **T02 — Sửa service và adapter**: atomic acquire; không release khi lỗi; tách audit/cleanup. AC: một publish cho một invocation, kết quả chính không bị audit/disconnect ghi đè.
3. **T03 — Regression tests**: tái hiện cả ba lỗi của Reviewer và publish-timeout; sửa test cũ đang yêu cầu release cooldown khi publish lỗi. AC: tests chạy với MQTT giả lập, có assertion call count và response.
4. **T04 — Integration và tài liệu**: kiểm thử nhiều client dùng cùng Redis test instance, web/API chung quota; cập nhật contract/rollout và báo cáo. AC: kiểm chứng failure của store không phát lệnh, không dùng Redis/broker production trong test tự động.

## Testing Strategy / Acceptance Criteria

- [x] Rails.cache là NullStore nhưng limiter thật vẫn chặn request thứ hai trong 3 giây.
- [x] Hai client/process dùng cùng test Redis cạnh tranh cùng device: chỉ một acquire thành công; không chỉ kiểm thử tuần tự trên fake MemoryStore.
- [x] Device khác có quota riêng; hết TTL cho phép request mới; Redis unavailable không gọi MQTT.
- [x] API trả 429 với Retry-After; lỗi storage trả JSON 503; route web có thông báo lỗi và không 500 ngoài ý muốn.
- [x] Publish thành công/audit lỗi: publish đúng một lần, accepted vẫn trả về, cooldown còn hiệu lực, có tín hiệu lỗi audit.
- [x] Publish timeout: báo kết quả không xác định, không tự retry và không xóa cooldown.
- [x] Connect lỗi: không publish, reservation vẫn hết theo TTL.
- [x] Disconnect lỗi sau thành công: accepted; disconnect lỗi sau publish failure: giữ PublishError ban đầu.
- [x] Validation, auth, quyền thiết bị, duration boundary và payload/topic không regression.
- [x] Swift/Flutter không tự retry mutation hoặc báo phần cứng đã thi hành lệnh.

## Giới hạn và quyết định bàn giao

Reviewer đúng về hành vi lỗi; kết luận cần sửa trước khi phát hành tính năng là phù hợp. Không nâng mức ảnh hưởng thành một sự cố production đã xảy ra khi chưa có bằng chứng.

Tại thời điểm thiết kế, Architect đã chạy probe với Ruby 3.1.2 và tái hiện ba lỗi, chưa sửa code. Developer sau đó đã hoàn tất T01–T04: Redis atomic reservation, phân tách publish/audit/cleanup, 503 API/web, regression và OpenAPI/rollout docs. 73 RSpec examples đã đạt với Redis cô lập và MQTT mock; Reviewer độc lập không tìm thấy blocker trong patch. AC Swift/Flutter được kiểm tra bằng đọc code hiện tại, không chạy lại build/test mobile ở lượt remediation. Xem [báo cáo triển khai](../../docs/technical/buzzer-review-remediation.md) để phân biệt kiểm chứng tự động với các giới hạn production/phần cứng chưa xác minh.
