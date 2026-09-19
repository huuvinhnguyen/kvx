# API Buzzer cho Swift và Flutter

Ngày cập nhật: 2026-09-18. Contract đã được triển khai trong **working tree BinBlog local**, chưa chứng nhận đã deploy lên `https://khuonvien.vn`.

## Xác thực và định danh

Mọi endpoint dưới đây yêu cầu `Authorization: Bearer <access_token>` và `Accept: application/json`. POST dùng `Content-Type: application/json` và body `{}`. Tái sử dụng cơ chế JWT của BinBlog; session web hợp lệ cũng được backend hỗ trợ.

`id` trong URL là **database device ID**, được tra trong `current_user.devices_for_current_user` và bắt buộc loại `buzzer`. Server lấy `chip_id` từ bản ghi đã kiểm tra quyền để gửi MQTT. Không chấp nhận chip ID, relay index hoặc duration của caller để đổi đích lệnh.

Các API mới đặt riêng dưới `/api/buzzers`, vì route web `/devices/:id/test_buzzer` dùng session/redirect, còn các route legacy `/api/devices/restart`, `reset_wifi`, `refresh_device` chưa có cùng lớp kiểm tra quyền. Mobile Buzzer không gọi các route legacy đó. Chúng không bị thay đổi trong task này.

## GET `/api/buzzers/:id`

HTTP 200: object có các trường:

- `id`, `name`, `chip_id`: string, định danh không rỗng.
- `online`: boolean, tính theo epoch giây `device_info.update_at > 5.minutes.ago.to_i`.
- `last_seen`: ISO 8601 có offset hoặc null, từ `meta_info.last_seen`. Metadata không đọc được trả null.
- `build_version`, `app_version`: string hoặc null.
- `test_duration_ms`: integer hoặc null, lấy relay đầu tiên. Giá trị ngoài 100–10.000 vẫn có thể được đọc nhưng test bị vô hiệu hóa ở app và bị server từ chối.
- `sources`: array `{id, name, chip_id, relay_index, duration_ms}`. ID string, index integer không âm, duration integer ms hoặc null. Index được hiển thị như web, không cộng 1.
- `events`: array `{id, source_id, source_name, source_chip_id, occurred_at, duration_ms}`. Thời gian ISO 8601 có offset; duration ms hoặc null. Tối đa 20, thứ tự do server xác định.

`sources` và `events` luôn là array, có thể rỗng. Missing array/duplicate identity hoặc event không thuộc source trong response bị mobile coi là dữ liệu lỗi; không dựng lịch sử giả.

Fixture không chứa dữ liệu thật dùng chung cho Swift và Flutter: `kvxTests/Fixtures/buzzer-detail.json`.

## POST `/api/buzzers/:id/test`

Tái sử dụng `BuzzerTestService` với cấu hình server, relay index 0, `longlast` nguyên trong 100–10.000 ms. Cooldown 3 giây theo database device ID, dùng `BuzzerTestCooldown` với Redis `SET NX EX 3`, namespace `binblog:<Rails.env>:buzzer:test:cooldown:<device-id>` dùng chung web/API, độc lập với `Rails.cache`. Gửi MQTT đến `<stored_chip_id>/switchon`, không retain, QoS 1; sau publish ghi `buzzer_test_requested`. Nếu ghi audit hoặc disconnect lỗi, vẫn trả accepted/broker_only và ghi tín hiệu log riêng. Reservation luôn hết theo TTL, không bị xóa trên nhánh lỗi.

HTTP 200:

```json
{
  "status": "accepted",
  "acknowledgement": "broker_only",
  "relay_index": 0,
  "longlast": 1000,
  "cooldown_seconds": 3
}
```

Đây chỉ là kết quả gửi lệnh của server, không phải xác nhận Buzzer đã phát âm. UI bắt buộc có dialog trước POST, khóa bấm lặp khi pending và đếm cooldown sau thành công/429.

## POST lệnh quản lý

- `/api/buzzers/:id/refresh`: gửi `{action: "refresh", sent_time: ...}` tới `<stored_chip_id>/refresh`.
- `/api/buzzers/:id/restart`: gửi action `restart` tới topic tương ứng, có xác nhận UI.
- `/api/buzzers/:id/reset_wifi`: gửi action `reset_wifi` tới topic tương ứng, UI xác nhận xóa WiFi cũ.

Body caller `{}`; `sent_time` theo format server hiện hữu `%Y-%m-%d %H:%M:%S`. Dùng cấu hình MQTT hiện tại của BinBlog, không retain, QoS 1, disconnect sau publish.

HTTP 200 cho các lệnh trên:

```json
{"status":"accepted","acknowledgement":"broker_only"}
```

App đọc lại GET sau thành công. Lần đọc đó có thể vẫn là snapshot cũ khi thiết bị chưa phản hồi; không đổi `last_seen` hoặc giả lập trạng thái mới ở client. Không tự retry POST khi timeout hoặc GET tiếp theo thất bại.

## Lỗi

- 401: chưa đăng nhập/token không hợp lệ. Swift yêu cầu đăng nhập bằng màn hiện có; Flutter xóa token trong datasource và đăng nhập lại khi người dùng bấm retry.
- 404: không tìm thấy, không có quyền hoặc sai device type. Backend không tiết lộ sự tồn tại thiết bị khác. Nếu server chưa deploy API mới thì cũng có thể trả 404.
- 422, `error: invalid_configuration`: cấu hình test không hợp lệ, không publish.
- 429, `error: cooldown`, `retry_after_seconds: 3`, header `Retry-After: 3`: chưa hết cooldown.
- 502, `error: command_failed`: lỗi gửi lệnh; không lộ chi tiết broker. Client báo kết quả chưa xác định và không tự gửi lại.
- 503, `error: cooldown_unavailable`: thiếu cấu hình hoặc Redis không khả dụng; dừng trước MQTT. Swift/Flutter hiển thị lỗi lệnh qua nhánh non-200 hiện có, không tự retry POST. Route web redirect về thiết bị kèm thông báo lỗi.
- GET không đúng schema: hiển thị lỗi dữ liệu/retry, không xem là empty thành công.

Các response lỗi không trả broker credentials, topic riêng tư hoặc stack trace.

## Deploy và xác minh

Backend cần phát hành 3 lớp mới `Api::BuzzersController`, `BuzzerDetailQuery`, `BuzzerDeviceCommandService`, routes mới và bản sửa `BuzzerTestService`, `BuzzerTestCooldown`, rescue của route web. Không có migration mới.

Request/service tests chạy trên test database, mock MQTT; đã kiểm tra auth, quyền sở hữu, cửa sổ lịch sử 200→20, empty/malformed, online boundary, duration boundary, cooldown, các lệnh và regression PIR. Không suy diễn kết quả này thành kiểm chứng broker/phần cứng production.

Cấu hình cùng `BUZZER_TEST_REDIS_URL` (ưu tiên) hoặc `REDIS_URL` cho tất cả web/API workers; không có fallback localhost/MemoryStore. Redis cần không eviction reservation; các deployment độc lập phải tách database. Khi rollout, tránh chạy đồng thời worker cũ dùng cache và worker mới dùng Redis; tạm dừng Test Buzzer hoặc cập nhật đồng bộ. Chi tiết: BinBlog `docs/buzzer-test-cooldown.md`.

Kiểm chứng remediation 2026-09-18: 73 RSpec examples đạt, gồm Redis cô lập thật với 8 client cạnh tranh, TTL 3 giây, quota web/API, NullStore, outage/missing config, audit/disconnect/logging lỗi và timeout. OpenAPI Test Buzzer được sinh từ Rswag và các response đã chạy request test. Không xác minh Redis deployment hoặc MQTT/phần cứng thật. Cooldown giới hạn thời điểm bắt đầu request, không đảm bảo âm thanh không chồng nhau hoặc exactly-once delivery.
