# Task: Màn hình Buzzer theo BinBlog `/devices/59`

- Ngày: 2026-09-17.
- Vai trò lập task: Architect, theo `ai/agents/architect.md`.
- Trạng thái: Đã triển khai Buzzer trên SwiftUI, Flutter và API BinBlog local; kiểm thử tự động đạt. Còn phát hành backend và nghiệm thu trên tài khoản/phần cứng thật.
- Loại thiết bị: **Buzzer/còi cảnh báo**, đã được người dùng xác nhận khi bắt đầu triển khai.
- Nền tảng: **Swift native và Flutter**, đã được người yêu cầu xác nhận.
- Yêu cầu giao diện: **SwiftUI native trên ứng dụng Swift và widget Flutter trên ứng dụng Flutter; không dùng WebView** để hiển thị màn hình hoặc bất kỳ phần chức năng nào của màn hình.
- Deliverable: code native/Flutter, API JSON có xác thực, unit/request/widget tests và tài liệu. Người dùng đã yêu cầu thực hiện task sau giai đoạn lập tài liệu.
- Kết quả và danh sách file: [báo cáo triển khai](../../docs/technical/device-detail-binblog-parity.md).
- Cập nhật Developer ngày 18/09: đã [thống nhất BuzzerAPIClient với PIRAPIClient](2026-09-18-buzzer-api-client-alignment.md), chuyển Swift client sang `Services/BuzzerAPIClient.swift`; endpoint và nghiệp vụ giữ nguyên.

## Goal

Từ danh sách thiết bị KVX, mở màn chi tiết có thông tin, thao tác và quy tắc nghiệp vụ tương đương màn `http://localhost:3000/devices/59` của BinBlog. Dùng UI native phù hợp từng nền tảng, dữ liệu thật và cùng ý nghĩa phản hồi của backend.

`59` chỉ là ID bản ghi tham chiếu, không hard-code trong app. API Buzzer mới dùng database ID trong URL; backend tra thiết bị có quyền rồi lấy `chip_id` để gửi lệnh phần cứng.

## Bằng chứng và giới hạn khảo sát

- Đã đọc `ai/PROJECT.md`, `ai/ARCHITECTURE.md`, `ai/CONVENTIONS.md`, `ai/WORKFLOW.md` và agent Architect.
- Đã đọc mã BinBlog tại `/Users/vinhnguyen/Documents/ror/binblog`: `app/views/devices/show.html.erb`, các partial `_switchon_form.erb`, `_dht_form.erb`, `_buzzer_form.erb`, controller web/API, routes và `app/services/buzzer_test_service.rb`.
- GET trang tham chiếu trả HTTP 302 trong phiên không đăng nhập; browser connector không khả dụng. Chưa xem trực quan màn 59; loại Buzzer được xác nhận trực tiếp bởi người dùng, dữ liệu thật chưa đối chiếu.
- Database SQLite development tìm được không có bảng `devices`; không dùng nó làm bằng chứng về thiết bị 59.
- Không gửi lệnh MQTT, restart, reset WiFi hoặc test buzzer trong quá trình khảo sát.
- Không suy luận thiết bị 59 là PIR/buzzer chỉ từ ID hoặc tên task cũ.

## Architecture Decision: Device detail parity

### Context

BinBlog render nhánh theo `device_type`: `switch`, `dht`, `pir`, `buzzer`. Swift hiện chỉ tách PIR; phần chi tiết còn lại có toggle và lịch giữ trong state cục bộ. DTO Swift/Flutter mới lấy ID, chip ID, tên, loại và status, bỏ qua `device_info`/`meta_info` mà API danh sách đã cung cấp. Cả hai mapper chưa nhận diện `buzzer`, dẫn tới fallback iPhone.

PIR đã triển khai ở cả hai app và được mô tả trong `docs/technical/PIR_SCREEN.md`. Relay đã có entity/widget và bộ task `2026-09-06-relay-control-*`; phải đối chiếu code thực tế, không xem task cũ là bằng chứng đã tích hợp API.

### Constraints

- Không dùng `WKWebView`, WebView Flutter hoặc nhúng trang HTML BinBlog. BinBlog chỉ là nguồn tham chiếu UI/nghiệp vụ và backend API; giao diện phải được triển khai bằng SwiftUI và widget Flutter.
- Dependency flow: Presentation → Application → Domain ← Data.
- Tái sử dụng authentication hiện có; không nhúng credential hoặc kết nối MQTT trực tiếp từ mobile.
- Không gọi route HTML/session như API Bearer khi chưa có contract JSON.
- Màn hình phải xử lý loading, empty, error/retry, offline, phiên hết hạn và dữ liệu đến sai thứ tự.
- Không đưa thông tin nhạy cảm của tài khoản/thiết bị thật vào fixture.

### Approach

Chốt loại thiết bị và contract trước, sau đó mở rộng model/DTO, repository và use case hiện có. Detail router chọn theo loại thiết bị, nhận stable identity; view model/provider điều phối load và mutation. Chỉ triển khai nhánh tương ứng màn tham chiếu; các nhánh dưới đây là checklist chọn phạm vi, không phải yêu cầu làm cả bốn loại.

Tách thao tác đọc lại dữ liệu khỏi lệnh refresh thiết bị: `POST refresh_device` chỉ gửi lệnh; cần GET lại để nhận snapshot mới. Không coi HTTP thành công là phần cứng đã thi hành lệnh. Không tự retry mutation sau timeout vì có thể gửi lệnh lặp.

### Layer Changes

- **Domain**: bổ sung trường metadata/capability cần cho loại đã chốt; repository contract cho đọc detail và lệnh tương ứng. Không đưa JSON/MQTT/UI vào entity.
- **Data**: map `device_info`, `meta_info`, timestamp và response lỗi; tái sử dụng token provider/datasource; tách ID database khỏi chip ID rõ ràng.
- **Application**: use case tải chi tiết, refresh và từng lệnh được hỗ trợ; validate đầu vào, không biến mọi thao tác thành một hàm map không định kiểu.
- **Presentation**: màn chi tiết theo loại, view model/provider inject use case, trạng thái request riêng cho mỗi thao tác; vô hiệu hóa bấm lặp khi đang gửi; hủy/bỏ qua response cũ khi rời màn hoặc đổi thiết bị.

### Alternatives Considered

- Nhúng WebView: **loại bỏ theo yêu cầu của người dùng**, không phải phương án triển khai hoặc fallback.
- Viết lại độc lập toàn bộ detail/API stack: tăng trùng lặp với PIR, relay và auth hiện hữu.
- **Chọn mở rộng native theo lớp hiện có**: giữ parity nghiệp vụ và kiểm thử được; API còn thiếu phải có task backend riêng.

## Hành vi tham chiếu đã xác minh trong source

### Phần chung

- Tên thiết bị; lần kết nối cuối từ `meta_info.last_seen` nếu có.
- Làm mới: `POST /api/devices/refresh_device`, tham số `chip_id`; mobile yêu cầu JSON bằng `Accept: application/json`.
- Hiển thị chip ID, `meta_info.build_version`, `meta_info.app_version` khi có; không tự điền phiên bản giả khi thiếu dữ liệu.
- Khởi động lại: `POST /api/devices/restart`, `chip_id`, có xác nhận.
- Đổi WiFi: `POST /api/devices/reset_wifi`, `chip_id`, xác nhận rõ xóa WiFi cũ và chuyển chế độ cấu hình.
- API danh sách `GET /api/devices` đã trả `device_info` và `meta_info`; phải xác minh ý nghĩa status, độ mới snapshot và contract cho từng action.
- Trong controller API đã đọc, `authenticate_api_user!` chỉ được khai báo cho index/motion_stats/motion_heatmap. Task backend cần xác minh bảo vệ thực tế ở lớp cha và kiểm tra quyền sở hữu cho các action sẽ dùng, không mặc định tất cả action đã hỗ trợ Bearer an toàn.

### Nếu thiết bị 59 là buzzer

**Nhánh được chọn và đã triển khai.** Contract thực tế tại `docs/api/device-detail-binblog-contract.md` dùng `/api/buzzers/:id` và các member POST test/refresh/restart/reset_wifi. Phần mô tả route hiện có dưới đây ghi nhận trạng thái trước triển khai.

- Thẻ tên/chip; online khi `device_info.update_at` (epoch giây) lớn hơn thời điểm hiện tại trừ 5 phút. Đây là rule riêng trong partial, không tự thay bằng `status == 1`.
- Số PIR liên kết: PIR thuộc tập thiết bị người dùng được truy cập, có `trigger.chip_id` trùng chip buzzer. Hiển thị tên, chip, `relay_index` (mặc định 0), `longlast` theo ms (thiếu thì dấu gạch).
- Lịch sử: từ các PIR đang liên kết, lấy `motion_detected`, sort `occurred_at DESC, id DESC`, giới hạn 200 trước khi lọc `payload.target_chip_id`, sau đó lấy tối đa 20. Đây là hành vi hiện tại; thay đổi truy vấn để có lịch sử đầy đủ hơn cần ghi quyết định riêng.
- Lần trigger gần nhất lấy từ sự kiện đầu danh sách trên; thời gian hiển thị Asia/Ho_Chi_Minh. Label sự kiện “Đã nhận motion” không chứng minh buzzer đã phát âm.
- Test Buzzer có xác nhận; server dùng relay đầu tiên, index 0, `longlast` nguyên 100–10.000 ms, cooldown 3 giây theo thiết bị. Tái sử dụng `BuzzerTestService`, không sao chép logic MQTT vào mobile.
- Route hiện có là `POST /devices/:id/test_buzzer` dùng web session và redirect. Routes API đã đọc chưa có API detail/test buzzer tương đương. Cần thiết kế endpoint JSON xác thực + kiểm tra quyền, response/cooldown/error trước khi tích hợp app; URL mới phải ghi là đề xuất, không mô tả như API có sẵn.
- Thành công chỉ báo server gửi lệnh tới broker, chưa có xác nhận từ buzzer. Event test là `buzzer_test_requested`, không trộn vào lịch sử motion từ PIR.

### Nếu là switch/relay

Ngoài phạm vi triển khai lần này; giữ để tham khảo khảo sát ban đầu.

- Tab theo `device_info.relays`, tiêu đề Kênh 1…N nhưng API dùng index 0…N−1.
- Trạng thái bật theo `switch_value == 1`; kích hoạt theo thời lượng, quản lý hẹn giờ và bật/tắt nhóm hẹn giờ theo từng kênh.
- Tôn trọng quyền reminder của `UserRelayFeature`; cần API capability tương ứng, không giả định mọi tài khoản có quyền.
- Tái sử dụng bộ task relay cũ; bổ sung gap về endpoint, đơn vị thời lượng, timezone, identity lịch và xử lý failure sau khi đối chiếu controller/JavaScript đầy đủ.

### Nếu là PIR hoặc DHT

Ngoài phạm vi triển khai lần này; giữ chức năng hiện có và kiểm thử regression PIR.

- PIR: lấy `docs/technical/PIR_SCREEN.md` và triển khai hiện tại làm baseline; đối chiếu partial/JavaScript thực tế về chọn ngày, heatmap, lịch sử trước khi bổ sung phần thiếu. Không xây lại dashboard đã có.
- DHT: web partial có nhiệt độ/độ ẩm và thao tác Connect DHT; chưa xác minh transport realtime từ partial. Dùng task requirements/API contract để xác minh trước; tài liệu environmental hiện tại chỉ xác nhận nguồn local/simulated, không dùng làm bằng chứng production.

## Implementation Steps / task nhỏ

### T01 — Xác nhận màn tham chiếu và phạm vi

- Xác nhận `device_type` của 59 qua phiên đăng nhập hợp lệ hoặc thông tin người dùng; phạm vi đã chốt gồm Swift native và Flutter.
- Ghi các section, action, điều kiện hiển thị và ảnh đối chiếu đã loại thông tin nhạy cảm vào `docs/requirements/device-detail-binblog-parity.md`.
- AC: biết chính xác nhánh cần làm, đã phân biệt chức năng hiện hữu và gap; không còn suy đoán ID → loại.
- Dependency: không có; là điều kiện bắt đầu T02–T06 theo nhánh.

### T02 — Chốt contract và phần backend thiếu

- Viết `docs/api/device-detail-binblog-contract.md`: method/path, auth, ID/chip ID, payload, response, timestamp/unit, permission, error/cooldown; phân biệt endpoint hiện có và đề xuất.
- Với buzzer, thiết kế API đọc summary/source/history và API test dùng service hiện có. Với action chung, kiểm tra JSON/auth/ownership bằng request tests trước khi mở trên mobile.
- AC: fixture đã làm sạch cho success/empty/malformed/error; test backend không gửi MQTT thật; xác định rõ phần nào cần deploy backend.
- Dependency: T01. Backend đã được triển khai tại repo BinBlog trong lượt Developer và kiểm tra với MQTT giả lập; chưa deploy production.

### T03 — Domain và mapping

- Cập nhật entity/enum cho loại cần hỗ trợ; map metadata/capability và DTO detail; giữ stable identity và chip ID khi cập nhật.
- File hiện hữu: `kvx/Models/Device.swift`, `kvx/Services/DeviceAPIClient.swift`, `kvx_flutter/lib/domain/entities/device.dart`, `kvx_flutter/lib/data/models/binblog_device_dto.dart`.
- AC: loại thiết bị điều hướng đúng; thiếu/null/JSON lỗi không crash; test đơn vị thời gian và missing data; không đổi nghĩa status của các loại khác.
- Dependency: T02.

### T04 — Repository, use case và state

- Mở rộng contract phù hợp trong `kvx/Domain/Repositories/`, implementation trong `kvx/Data/`, use case trong `kvx/Domain/UseCases/`.
- Flutter tương ứng `lib/domain/repositories/`, `lib/data/`, `lib/application/usecases/`; tái sử dụng `binblog_device_datasource.dart` để xác thực.
- AC: fake repository kiểm tra load/retry, refresh gửi lệnh rồi đọc lại, failure không hiện success, 401 về luồng login, không tự retry lệnh, response cũ không ghi đè state.
- Dependency: T03; API mock theo contract cho phép phát triển trước khi backend deploy.

### T05 — Swift detail và navigation

- Mở rộng `kvx/Views/DeviceDetailView.swift`, thêm view/view model theo loại đã chốt; tái sử dụng widget relay/PIR phù hợp.
- AC: các section theo T01; không hiển thị toggle/lịch local giả cho loại không hỗ trợ; xác nhận restart/reset WiFi/test buzzer; hỗ trợ Dynamic Type, VoiceOver, dark mode.
- Dependency: T04.

### T06 — Flutter detail và navigation

- Mở rộng `kvx_flutter/lib/presentation/screens/device_detail_screen.dart`, provider và widget cần thiết; không gọi datasource trực tiếp từ widget mới.
- AC: cùng rule và semantics với Swift; dispose controller/subscription; mounted/cancellation guard, text scaling và accessibility.
- Dependency: T04; bắt buộc triển khai cùng Swift để hoàn thành phạm vi đã chốt.

### T07 — Kiểm thử parity, nghiệm thu và tài liệu vận hành

- Đối chiếu cùng fixture giữa BinBlog/Swift/Flutter; kiểm tra không ảnh hưởng routing PIR và các loại hiện có.
- Cập nhật `docs/technical/device-detail-binblog-parity.md`, ghi backend version/deployment prerequisite và hạn chế chưa xác minh trên thiết bị thật.
- AC: tiêu chí nghiệm thu dưới đây đạt, có kết quả lệnh thực chạy; mọi lỗi nền có sẵn được phân biệt với regression.
- Dependency: T05/T06 thuộc scope và backend cần thiết đã sẵn sàng cho kiểm thử tích hợp.

## Acceptance criteria tổng thể

- [x] Màn Swift được xây bằng SwiftUI native; màn Flutter được xây bằng widget Flutter. Không dùng WebView hoặc nhúng HTML BinBlog cho bất kỳ section/action nào.
- [x] Nền tảng được xác nhận: Swift native và Flutter.
- [x] Loại của thiết bị 59 được xác nhận; route không phụ thuộc ID 59.
- [x] UI có đủ section/action theo source Buzzer; chưa đối chiếu pixel với phiên web đăng nhập.
- [x] ID/chip ID, milliseconds/seconds, timezone, quyền truy cập được kiểm tra bằng fixture/request tests.
- [x] Không có thao tác chỉ đổi state cục bộ nhưng báo đã điều khiển thiết bị thật.
- [x] Phân biệt lệnh được server nhận/gửi với xác nhận phần cứng; không tạo lịch sử giả.
- [x] Loading, empty, missing metadata, offline, lỗi/retry, 401, request chậm và bấm lặp có tests.
- [x] Refresh không gọi restart/reset/test; dialog xác nhận và cancel đã được kiểm tra trong Flutter, Swift được rà soát code.
- [x] Buzzer: kiểm tra 100/10.000 ms hợp lệ, ngoài biên bị từ chối, cooldown, quyền nguồn PIR, lọc target chip và cửa sổ lịch sử 200→20.
- [ ] Nghiệm thu accessibility bằng VoiceOver/TalkBack và bố cục Swift trên thiết bị thật. Flutter đã qua widget tests sáng/tối, 390×844, text scale 1,6.
- [x] Build Swift/Flutter iOS và toàn bộ unit/widget tests đạt, gồm regression PIR/relay. `flutter analyze` toàn repo vẫn có lỗi demo relay có sẵn; phần Buzzer kiểm tra riêng không có issue.
- [ ] Phát hành API mới lên server ứng dụng đang dùng và kiểm thử với tài khoản/thiết bị thật.

## Testing Strategy và verification commands

- Unit: DTO/null/date/unit, entity/type mapping, use case, state transitions với fake; test thời gian bằng clock cố định nếu dùng rule online/cooldown.
- Backend request: auth/ownership, response JSON, error/cooldown và MQTT service được stub; không dùng thiết bị thật trong CI.
- UI/widget: mở từ danh sách, các state, dialog confirm/cancel, test/refresh, navigation back và request đang chạy.
- Manual: đối chiếu màn đăng nhập BinBlog với app trên cùng loại thiết bị; ghi rõ các lệnh có tác động thiết bị trước khi thử.

Lệnh kiểm chứng; kết quả thực tế được ghi trong báo cáo triển khai:

```bash
# Tại thư mục kvx_flutter
flutter analyze
flutter test

# Tại root KVX, chọn simulator thực có trên máy
xcodebuild -list -project kvx.xcodeproj
xcodebuild test -project kvx.xcodeproj -scheme kvx -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>'
```

Với backend, chạy các request/service specs tương ứng endpoint thực được thêm/sửa; không ghi test pass dựa trên tài liệu lần trước.

## Risks và follow-up

- Nhánh Buzzer đã được người dùng xác nhận; Swift và Flutter đều triển khai đúng nhánh này.
- API web dùng session/redirect và API mobile dùng Bearer khác nhau: T02 phải giải quyết trước mutation thật.
- Snapshot metadata có thể cũ; refresh không bảo đảm thiết bị phản hồi ngay: hiển thị độ mới dữ liệu và trạng thái gửi lệnh, không làm giả acknowledgement.
- Thiết bị offline vẫn có thể gửi lệnh tới broker: chốt hành vi theo contract, không tự đặt rule khóa action làm lệch BinBlog.
- Tài liệu này chưa chứng nhận parity trực quan hoặc hoạt động trên firmware thật.
