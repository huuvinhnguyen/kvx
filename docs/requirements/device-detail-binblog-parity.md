# Buzzer detail — yêu cầu đã chốt

Ngày cập nhật: 2026-09-18. Người dùng xác nhận thiết bị tham chiếu `/devices/59` là **Buzzer/còi cảnh báo**, triển khai **Swift native và Flutter**, **không WebView**.

## Phạm vi

Mọi thiết bị trả `device_type: buzzer` mở màn Buzzer; ID 59 chỉ dùng làm ví dụ/fixture. Màn được xây bằng SwiftUI và Flutter widgets, sử dụng API JSON. Không nhúng trang BinBlog, không bật/tắt local hoặc hẹn giờ giả trên Buzzer.

Các section theo `binblog/app/views/devices/show.html.erb` và `_buzzer_form.erb`:

1. Tên, chip ID, online/offline, lần kết nối cuối và Làm mới thiết bị.
2. Số PIR liên kết, lần trigger gần nhất, thời lượng test, Test Buzzer có xác nhận.
3. PIR nguồn: tên, chip ID, kênh và thời lượng ms; thông báo riêng khi rỗng.
4. Lịch sử motion: tối đa 20 sự kiện, thời gian Việt Nam UTC+7, nguồn PIR, thời lượng, nhãn “Đã nhận motion”.
5. Chip ID, firmware/app version khi có.
6. Khởi động lại và đổi WiFi, đều có xác nhận; đổi WiFi giải thích xóa cấu hình WiFi cũ.

## Quy tắc

- Online theo `device_info.update_at > now - 5 phút`, server tính cùng rule của web. Không thay bằng trạng thái `status` trong danh sách.
- Chỉ lấy PIR thuộc tập thiết bị người dùng có quyền, với `trigger.chip_id` bằng chip Buzzer.
- Giữ truy vấn lịch sử của web: 200 motion event mới nhất từ các PIR hiện liên kết, sort thời gian giảm dần rồi ID giảm dần, lọc `payload.target_chip_id`, lấy 20. Không đưa `buzzer_test_requested` vào lịch sử này.
- Test dùng relay đầu tiên, index 0, thời lượng nguyên 100–10.000 ms từ cấu hình server; cooldown server 3 giây theo thiết bị. Mobile không cho sửa thông số lệnh test.
- Không khóa thao tác chỉ vì snapshot báo offline: giữ hành vi web, nhưng không khẳng định phần cứng nhận lệnh.
- Sau lệnh thành công, hiển thị server đã gửi lệnh tới broker, chưa có xác nhận phần cứng; đọc lại snapshot bằng GET. GET lỗi không tự gửi lại POST.
- Kéo để tải lại và nút “Tải lại dữ liệu” chỉ GET. Nút “Làm mới thiết bị” gửi lệnh refresh rồi GET.
- 401 xóa snapshot của phiên cũ, cung cấp đăng nhập lại. 403/404 xóa snapshot không còn quyền truy cập. Retry do người dùng thực hiện, không tự replay mutation.
- Swift dùng màn đăng nhập hiện có; Flutter dùng lại luồng đăng nhập bằng thông tin cấu hình build hiện có.

## Giới hạn xác minh

Đã đối chiếu mã nguồn BinBlog và fixture giả lập. Phiên khảo sát URL trả chuyển hướng đăng nhập, nên chưa có ảnh chụp trực tiếp màn 59 để đối chiếu từng pixel. Đây là parity chức năng bằng UI native, không phải sao chép HTML/CSS. Chưa thử phát âm, restart hoặc reset WiFi trên phần cứng thật.

Xem [contract API](../api/device-detail-binblog-contract.md) và [báo cáo triển khai](../technical/device-detail-binblog-parity.md).
