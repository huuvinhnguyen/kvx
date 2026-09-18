# Architecture Decision: BuzzerAPIClient tương ứng PIRAPIClient

- Ngày: 2026-09-18.
- Vai trò: Architect, theo `ai/agents/architect.md`.
- Trạng thái: hoàn tất — Developer đã đổi tên/chuyển client, cập nhật wiring và kiểm chứng build/unit tests thành công.
- Yêu cầu: tổ chức luồng Buzzer Detail tương tự các luồng Device/PIR hiện có, có `BuzzerAPIClient` giống cách đặt `PIRAPIClient`.
- Phạm vi: Swift; Flutter tiếp tục giữ parity nghiệp vụ và cách tổ chức datasource/repository hiện có. Không WebView.

## Context

- `kvx/Services/PIRAPIClient.swift`: `PIRAPIClient: PIRRepository`, thực hiện HTTP, inject token provider/session/baseURL, decode và validate response.
- Trước refactor, `kvx/Data/Repositories/BinblogBuzzerRepository.swift` trực tiếp thực hiện HTTP và mapping, conform `BuzzerRepository`. Nay implementation này đã được chuyển thành `kvx/Services/BuzzerAPIClient.swift`.
- `BuzzerViewModel` đang gọi `BuzzerUseCases`; use case phụ thuộc contract `BuzzerRepository`. Cách này giữ business rule ngoài view và phù hợp `ai/ARCHITECTURE.md`.
- `PIRViewModel` hiện gọi repository trực tiếp; đây là khác biệt có sẵn. Không cần bỏ use case của Buzzer để đồng nhất tên API client.
- Luồng danh sách Device có `FetchDevicesUseCase → RemoteDeviceRepository → BinblogDeviceDataSource` (trong `DeviceAPIClient.swift`). Phần Device Detail legacy chưa có API detail riêng; không dùng state local của nó làm mẫu tải dữ liệu Buzzer.

## Constraints

- SwiftUI render state và gửi intent; không gọi HTTP trực tiếp.
- Giữ xác thực, timeout, xử lý 401/404/422/429, cooldown, stale response và không tự retry mutation.
- Không thay đổi schema/backend hoặc chuyển database ID thành chip ID chỉ vì đổi tên client.
- Không thêm dependency, không đổi kiến trúc PIR/Device/Flutter ngoài phạm vi.

## Approach

Đổi tên và chuyển implementation hiện hữu từ `BinblogBuzzerRepository` sang **`BuzzerAPIClient`**, đặt tại **`kvx/Services/BuzzerAPIClient.swift`**, cùng vị trí với `PIRAPIClient.swift`.

`BuzzerAPIClient` conform `BuzzerRepository`, tiếp tục cung cấp `detail(deviceID:)` và `send(_:deviceID:)`. Giữ khả năng inject `AccessTokenProvider`, `URLSession` và `baseURL`, cùng default configuration đang dùng. Client chịu trách nhiệm HTTP, decode/validate DTO và map lỗi transport.

Luồng đích: `DeviceDetailView → BuzzerDetailView → BuzzerViewModel → BuzzerUseCases → BuzzerRepository`, với implementation được inject là `BuzzerAPIClient`.

`BuzzerDetailDTO` cùng các DTO response tiếp tục nằm ở data/transport boundary. Trong lần đổi tên này có thể chuyển nguyên file cùng các DTO sang `Services/`; không cần tạo thêm một lớp repository chỉ chuyển tiếp sang client.

## Layer Changes

- **Domain**: giữ `BuzzerDetail`, `BuzzerRepository` và rule duration.
- **Data/Services**: đổi tên/move implementation; giữ hành vi HTTP và DTO hiện có.
- **Application**: giữ `BuzzerUseCases` và kiểm tra identity/duration.
- **Presentation**: thay constructor inject ở `DeviceListView` và preview `DeviceDetailView` bằng `BuzzerAPIClient`; `BuzzerViewModel`/`BuzzerDetailView` tiếp tục phụ thuộc use case.
- **Flutter**: giữ `BinblogBuzzerRepository → BinblogDeviceDataSource`, dùng chung token; không tạo client Swift-style chỉ để đồng nhất tên giữa hai ngôn ngữ.

## Alternatives Considered

- Giữ tên `BinblogBuzzerRepository`: ít thay đổi nhưng không đáp ứng cách tổ chức client mà người dùng yêu cầu.
- Thêm `BuzzerAPIClient` bên dưới repository hiện tại: thêm lớp chuyển tiếp không có trách nhiệm mới trong phạm vi hiện nay.
- Cho view model gọi concrete client trực tiếp: làm giảm khả năng thay thế bằng fake và bỏ qua use case đang chứa validation.
- **Chọn rename/move implementation, giữ contract/use case**: tương ứng cách `PIRAPIClient` implement protocol, thay đổi nhỏ và giữ testability.

## Implementation Steps

1. **Client**: chuyển `kvx/Data/Repositories/BinblogBuzzerRepository.swift` thành `kvx/Services/BuzzerAPIClient.swift`, đổi tên struct, không giữ hai implementation hoặc alias cũ không cần thiết.
2. **Wiring**: cập nhật `kvx/Views/DeviceListView.swift`, `kvx/Views/DeviceDetailView.swift` và `kvxTests/BuzzerTests.swift`; giữ constructor injection cho test.
3. **Documentation**: cập nhật đường dẫn/tên client trong `docs/technical/device-detail-binblog-parity.md` và tham chiếu liên quan. Contract API giữ nguyên.
4. **Verification**: build Swift và chạy `kvxTests`, kiểm tra không còn reference code tới tên cũ. Flutter/backend chỉ cần chạy lại khi có thay đổi ảnh hưởng chúng.

## Testing Strategy / Acceptance Criteria

- [x] Có `Services/BuzzerAPIClient.swift`, struct `BuzzerAPIClient: BuzzerRepository`.
- [x] Không còn implementation/reference Swift `BinblogBuzzerRepository`.
- [x] Detail vẫn GET `/api/buzzers/:id`; lệnh vẫn POST member endpoints theo contract đã triển khai.
- [x] Inject được token/session/baseURL; HTTP tests tiếp tục kiểm tra Bearer và database ID.
- [x] Giữ validation duration, cooldown, login, mất quyền, stale response và không replay POST khi GET lỗi.
- [x] Các test Buzzer/PIR/Device trong `kvxTests` và build Swift đạt.
- [x] Giao diện vẫn SwiftUI/Flutter native, không WebView; không đổi hành vi Flutter/backend.

Lệnh kiểm chứng trong lượt Developer:

```bash
xcodebuild test -project kvx.xcodeproj -scheme kvx \
  -destination 'platform=iOS Simulator,id=65A80E5B-E316-471D-9BD7-E1B9D8FF2D01' \
  -derivedDataPath /tmp/kvx-buzzer-build \
  -only-testing:kvxTests -parallel-testing-enabled NO \
  IPHONEOS_DEPLOYMENT_TARGET=17.6 CODE_SIGNING_ALLOWED=NO
```

Kết quả: **TEST SUCCEEDED**, build và **93 tests đạt** (73 XCTest + 20 Swift Testing) trên iPhone 16 Pro iOS 18.1. Deployment target chỉ được override cho lệnh test, không sửa project. Phiên iOS 26.1 ban đầu đã dừng vì chờ simulator, không được tính là test pass.

Log: `/tmp/kvx-buzzer-client-alignment-ios18-tests.log`.

## Thay đổi thực hiện

- Move/rename `kvx/Data/Repositories/BinblogBuzzerRepository.swift` → `kvx/Services/BuzzerAPIClient.swift`.
- Đổi constructor trong `kvx/Views/DeviceListView.swift`, `kvx/Views/DeviceDetailView.swift`, `kvxTests/BuzzerTests.swift`.
- Cập nhật đường dẫn hiện tại trong `docs/technical/device-detail-binblog-parity.md`.
- Cập nhật trạng thái task này và `ai/tasks/2026-09-17-device-59-binblog-parity.md`.
- Đã đối chiếu trước/sau: bốn file Swift chỉ thay tên type; logic HTTP/DTO và test không đổi. File client cũ đã được chuyển, không giữ alias/lớp chuyển tiếp.
- `git diff --check`: PASS. Không sửa Flutter/backend; không chạy lại tests của hai phần đó cho lần rename này.
- Chưa commit/push; không thử lệnh phần cứng trong lượt này.

## Risks

- Rename thiếu chỗ inject/test gây lỗi compile: tìm toàn bộ reference tên cũ và build.
- Đổi tên client dễ bị hiểu thành đổi contract sang endpoint PIR: không đổi `/api/buzzers/:id` hoặc identity hiện tại trong task này.
- API Buzzer vẫn cần được phát hành lên môi trường app gọi; rename client không giải quyết việc server chưa có endpoint mới.
