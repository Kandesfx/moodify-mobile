# Quy trình triển khai và bàn giao cho AI

Đọc AGENTS trước. Tài liệu này hướng dẫn cách làm, không cấp quyền đổi schema hoặc mở rộng phạm vi.

## 1. Bắt đầu một phiên

1. Đọc CONTEXT và STATE; xác định milestone/luồng đang làm.
2. Kiểm tra thay đổi sẵn có và đường dẫn làm việc. Chưa có `.git` thì nói rõ, không suy `git status` của parent là repo Flutter.
3. Chọn source qua SOURCE_MAP, đọc controller/DTO/call site đúng luồng; chỉ đọc thêm tài liệu chuyên trách liên quan.
4. Nêu kết quả cụ thể sẽ thực hiện và tiếp tục công việc đã được giao. Không hỏi lại quyền cho sửa code hoặc kiểm tra thông thường trong phạm vi đó.

## 2. Thực hiện một luồng

- Xác định trigger, dữ liệu đầu vào, endpoint, quyền và trạng thái success/empty/error/cancel.
- Dùng repository/DTO có sẵn trước khi thêm lớp. Nếu cần lớp mới, đặt vào feature đúng trách nhiệm theo ARCHITECTURE.
- Dùng API thật; khi thiếu môi trường hoặc API không hoạt động thì giữ lỗi/blocked có thông tin. Không dựng catalog, payment hoặc scoring giả để có màn hình.
- Giữ session/query/playback identity; hủy tác vụ cũ và rollback optimistic mutation nếu thất bại.
- Không thay HTTP method chỉ để khớp client cũ; đối chiếu controller trước. Không sửa backend để UI mới đỡ phải xử lý lỗi.
- Nếu cần native spike, mô tả câu hỏi kỹ thuật cần trả lời, chạy thử nhỏ có đo lường, ghi kết luận; không giữ demo dependency/assets trong release.

## 3. Khi cần thay schema

Không triển khai hoặc chạy thay đổi trước khi người dùng đồng ý rõ ràng. Hoàn thiện đề xuất trước khi hỏi:

| Nội dung bắt buộc | Cần làm rõ |
| --- | --- |
| Nhu cầu | Luồng nào không thể đáp ứng bằng API/cấu trúc hiện tại? |
| Phương án không đổi schema | RAM/cache TTL/file local hoặc tái sử dụng dữ liệu đúng nghĩa có đáp ứng không? |
| Thay đổi chính xác | Bảng/collection/cột/index/constraint nào, kiểu và quyền tác động |
| Ảnh hưởng | Client/API cũ, dữ liệu hiện tại, deployment/startup, performance |
| Thực hiện/rollback | Backfill nếu có, kiểm tra an toàn, cách phục hồi và giới hạn rollback |
| Quyết định cần người dùng | Câu hỏi rõ ràng về đúng thay đổi này, không hỏi chung “cho phép làm tiếp?” |

Trong khi chờ, tiếp tục phần độc lập. Schema thiếu không được giải quyết bằng tự bật auto-DDL. Không bịa giao dịch, quyền hoặc lịch sử vào cache để né quy tắc.

## 4. Kiểm chứng tương ứng rủi ro

| Loại thay đổi | Bằng chứng cần có |
| --- | --- |
| Chỉ tài liệu/config editor | Liên kết/path tồn tại, nội dung không mâu thuẫn, JSON parse được, ignore có hiệu lực tương ứng |
| Code Dart thông thường | Format, analyze; test cho logic có rủi ro, không viết test chỉ phản chiếu implementation |
| Auth/network | Refresh concurrency, logout/stale response, lỗi HTTP, API thật ở môi trường xác định |
| Player | Queue/race/retry/seek/telemetry và native background/audio focus/codec |
| Payment | Checkout/status/entitlement thật; test pending/expired/resume, không gọi endpoint cấp Premium giả |
| Offline | License/account isolation/file integrity/recovery và đo RAM/file I/O trên native |
| Karaoke | Mic/pitch/score thật, voice protocol; room nhiều thiết bị, version/reconnect/cleanup |

Khi có app Flutter, dùng lệnh đúng repo/SDK; thường gồm `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`. Chỉ đưa thư mục tồn tại vào lệnh; integration test cần môi trường/thiết bị được cấu hình. Format sửa file chạy trước lệnh kiểm tra format. Ghi đúng lệnh đã chạy và kết quả, không báo “mọi kiểm tra đạt” khi có phần chưa chạy.

Không chạy backend cũ để thử nhanh khi chưa xác minh startup side effects. `ddl-auto=validate/none` hoặc tắt maintenance mới chỉ là các cấu hình cần đánh giá, không phải bằng chứng đã chặn mọi DDL/seed. Thay đổi cấu hình môi trường dùng chung cần nằm trong phạm vi được giao.

## 5. Kết thúc và chuyển phiên

- Cập nhật STATE thành snapshot mới: module, evidence label, kết quả kiểm tra, blocker, bước tiếp theo.
- Cập nhật đúng hàng migration; IMPLEMENTED không đồng nghĩa API_VERIFIED, DEVICE_VERIFIED hoặc ACCEPTED.
- Source mới/contract mới: cập nhật SOURCE_MAP/API_CONTRACT và quyết định có ảnh hưởng lâu dài.
- Báo kết quả chính, đường dẫn file, kiểm chứng và giới hạn. Không lưu raw token/response nhạy cảm vào báo cáo.
- Tác vụ dài chia theo luồng dùng được; không kết thúc bằng hàng loạt stub hoặc tính năng chỉ có UI.

## 6. Điểm vào cho phiên triển khai đầu

Khi người dùng giao bắt đầu migration, tiếp tục **M1** trong MIGRATION_PLAN và STATE, không khảo sát lại toàn hệ thống. Tạo Flutter app tại chính root này, giữ tài liệu đã có, ưu tiên cấu hình/session/auth. Nếu chưa có OAuth credential thì làm luồng password/config trước và ghi blocker riêng cho social auth. Thiết kế và code theo DESIGN; không tự biến lần khởi tạo thành redesign web hoặc triển khai backend.
