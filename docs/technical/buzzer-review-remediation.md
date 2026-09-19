# Kết quả triển khai Buzzer review remediation

Ngày 2026-09-18. Thực hiện theo `ai/agents/developer.md` và task
`ai/tasks/2026-09-18-buzzer-review-remediation.md`.

## Kết quả

Đã sửa ba vấn đề Reviewer xác nhận: cooldown phụ thuộc cache có thể tắt,
audit lỗi làm mất cooldown sau publish, và disconnect lỗi che kết quả chính.
Không thay đổi ứng dụng SwiftUI/Flutter hoặc schema Buzzer detail.

`BuzzerTestCooldown` dùng Redis `SET NX EX 3`, namespace theo Rails environment
và database device ID. Mọi web/API worker cần cùng endpoint/database. Ưu tiên
`BUZZER_TEST_REDIS_URL`, fallback sang `REDIS_URL`; thiếu cấu hình hoặc Redis lỗi
thì dừng trước MQTT. Không fallback sang Rails.cache và không xóa reservation.

`BuzzerTestService` tách lỗi connect/publish khỏi audit và cleanup. Publish lỗi
trả 502 với kết quả chưa xác định, giữ nguyên exception cause và TTL. Publish
thành công rồi audit/disconnect lỗi vẫn accepted/broker_only. Log có cấu trúc
chỉ chứa service/event/device ID/error class; lỗi logging không đổi kết quả.
API trả 503 `cooldown_unavailable` khi limiter không dùng được; route web có
thông báo lỗi và redirect. Payload MQTT, QoS 1 và non-retain giữ nguyên.

## Các file thay đổi trong lượt remediation

Repo `/Users/vinhnguyen/Documents/ror/binblog`:

- `app/services/buzzer_test_cooldown.rb` — mới, Redis reservation.
- `app/services/buzzer_test_service.rb` — xử lý kết quả và dependency injection.
- `app/controllers/api/buzzers_controller.rb` — mapping 503.
- `app/controllers/devices_controller.rb` — xử lý lỗi limiter trên web.
- `spec/services/buzzer_test_cooldown_spec.rb` — mới, concurrency/TTL/config/outage.
- `spec/services/buzzer_test_service_spec.rb` — regression audit/timeout/cleanup/logging.
- `spec/support/isolated_buzzer_redis.rb` — mới, Redis test riêng qua Unix socket.
- `spec/requests/api/buzzers_spec.rb` — bổ sung mapping lỗi 503.
- `spec/requests/buzzer_reliability_spec.rb` — mới, quota chung và response thực của service.
- `spec/requests/api/buzzer_test_swagger_spec.rb` — mới, contract response bằng Rswag.
- `swagger/v1/swagger.yaml` — operation Test Buzzer được sinh từ Rswag.
- `docs/buzzer-test-cooldown.md` — mới, cấu hình và rollout.

Repo KVX:

- `ai/tasks/2026-09-18-buzzer-review-remediation.md` — trạng thái và acceptance criteria.
- `docs/api/device-detail-binblog-contract.md` — Redis/503/audit semantics.
- `docs/technical/device-detail-binblog-parity.md` — cập nhật giới hạn sau sửa.
- `docs/technical/buzzer-review-remediation.md` — báo cáo này.

Các thay đổi từ lượt triển khai trước được giữ nguyên; không commit hoặc push.

## Kiểm thử đã thực hiện

Chạy trong repo BinBlog với Ruby 3.1.2:

```sh
/Users/vinhnguyen/.rbenv/versions/3.1.2/bin/ruby -r bundler/setup \
  -e 'load Gem.bin_path("rspec-core", "rspec")' -- \
  spec/services/buzzer_test_cooldown_spec.rb \
  spec/services/buzzer_test_service_spec.rb \
  spec/services/buzzer_device_command_service_spec.rb \
  spec/requests/buzzer_reliability_spec.rb \
  spec/requests/api/buzzers_spec.rb \
  spec/requests/api/buzzer_test_swagger_spec.rb \
  spec/requests/devices_test_buzzer_spec.rb \
  spec/requests/api/device_motion_statistics_spec.rb \
  spec/requests/api/device_motion_statistics_swagger_spec.rb
```

**PASS: 73 examples, 0 failures, 8,22 giây** (không tính boot).
MQTT mock; Redis thật nhưng cô lập, không TCP port/persistence, tự dọn sau test.

```sh
/Users/vinhnguyen/.rbenv/versions/3.1.2/bin/ruby -r bundler/setup \
  -e 'load Gem.bin_path("rspec-core", "rspec")' -- \
  spec/requests --format Rswag::Specs::SwaggerFormatter --dry-run --order defined
```

OpenAPI generation: PASS. 68 examples trong dry-run là nguồn sinh tài liệu,
không phải 68 tests được thực thi. Chỉ giữ operation Buzzer mới từ output;
không đưa các thay đổi sinh lại của endpoint khác vào task. YAML parse và
kiểm tra đủ response 200/401/404/422/429/502/503: PASS. `git diff --check`: PASS.
Rswag có deprecation warning sẵn về `swagger_endpoint`; ngoài phạm vi task.

Build Swift/Flutter: NOT RUN. Mobile tests: NOT RUN ở lượt này vì không sửa
source mobile. Hardware/MQTT thật/deployment: NOT PERFORMED.

## Acceptance criteria

- [x] NullStore không làm mất cooldown: service và request integration tests.
- [x] Tám client Redis cạnh tranh đồng thời: chỉ một acquire thành công.
- [x] Device/environment khác có quota riêng; TTL thật hết cho phép acquire lại.
- [x] Redis outage/thiếu config không connect MQTT; API JSON 503 và web alert.
- [x] API 429 có `Retry-After: 3`, web/API dùng chung quota theo cả hai chiều.
- [x] Audit lỗi sau publish: accepted, publish một lần, giữ quota, log riêng.
- [x] Publish timeout: 502/kết quả chưa xác định, không retry, giữ reservation.
- [x] Connect lỗi không publish, reservation còn hiệu lực và dùng TTL của adapter.
- [x] Disconnect/logging lỗi không che accepted hoặc PublishError/cause ban đầu.
- [x] Auth, quyền truy cập, duration boundary, payload/topic và PIR regression đạt.
- [x] Đọc code xác nhận Swift/Flutter không tự retry mutation; thông báo broker-only,
  non-200 đi vào lỗi. Đây là kiểm tra source, không phải kiểm thử thiết bị.

Reviewer độc lập đã đọc patch/code/tests và không tìm thấy blocker. Reviewer
không tự chạy lại suite, không đánh giá deployment hoặc phần cứng.

## Giới hạn và bàn giao vận hành

Cần cấu hình Redis chung cho mọi worker trước khi phát hành. Sidekiq initializer
hiện không chủ động cấu hình URL nên việc có Sidekiq không đủ xác nhận web worker
có Redis. Rollout phải tránh trộn worker cache cũ với worker Redis mới. Redis
cần không eviction reservation; mất key do failover/flush có thể làm yếu cooldown.

Chưa xác minh production hoặc phát lệnh còi thật. Giới hạn ba giây là giữa các
request bắt đầu, không bảo đảm âm thanh không chồng nhau hay exactly-once.
Audit có thể thiếu khi database lỗi sau publish; durable journal/outbox là task
riêng. Các vấn đề demo relay Flutter từ lượt trước và deprecation Rswag không sửa.
