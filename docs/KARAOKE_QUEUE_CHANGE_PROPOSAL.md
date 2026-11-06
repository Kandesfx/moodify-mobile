# Đề xuất sửa giới hạn hàng chờ karaoke — 06/11/2026

Hiện backend chặn `existsByRoom_IdAndRequester_Id`; MySQL còn có unique index
`uk_karaoke_room_queue_requester (room_id, requester_user_id)`. Mobile cũng thay
nút Thêm bài bằng Rút lượt khi người dùng có một bài. Vì vậy chỉ sửa giao diện
không đủ để thêm bài thứ hai.

Phương án không đổi schema: giữ mỗi người một bài và cho đổi/xóa bài đã chọn.
Phương án này không đáp ứng yêu cầu thêm nhiều bài vào hàng chờ. Không dùng RAM
hoặc cache thay cho hàng chờ nghiệp vụ vì sẽ mất dữ liệu khi backend khởi động lại.

Người dùng đã đồng ý sửa và yêu cầu kèm CREATE TABLE để tự áp dụng MySQL sau này:

- Thay unique index nói trên bằng index thường cùng hai cột; giữ bảng, cột,
  foreign key và thứ tự FIFO hiện có. Không xóa bản ghi.
- Backend cho một người thêm nhiều bài khác nhau, chặn trùng cùng bài của cùng
  người trong hàng chờ; vẫn khóa room khi ghi. Không đặt giới hạn số bài/người.
- Mobile luôn hiện Thêm bài, xóa riêng từng bài và báo lỗi nghiệp vụ cụ thể.
- Migration áp dụng lúc tạm ngưng ghi hàng chờ; triển khai backend/app sau đó.
  Không khởi động backend để kích hoạt auto-DDL và không tự triển khai production.
- Rollback: quay về client/backend cũ; đợi hàng chờ rỗng hoặc còn tối đa một bài
  mỗi người rồi phục hồi unique index. Nếu còn nhiều bài phải giữ nguyên dữ liệu
  và hoãn rollback index, không tự xóa bài để ép rollback.

Đã chuẩn bị DDL, chưa chạy hoặc thay schema database thực tế:
`E:/moodify-backend/database/create_karaoke_room_queue.sql` cho bảng mới;
`E:/moodify-backend/database/allow_multiple_karaoke_queue_items.sql` cho bảng đang có.
