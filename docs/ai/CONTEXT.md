# Ngữ cảnh nhanh

06/11/2026: đã lấy GitHub main06b3c27, giữ lyrics/splash local và tích hợp profile/checkout/karaoke/ads. Lyrics hiện không yêu cầu Premium theo upstream, vẫn cần LRC thật. 134tests/analyze/build đạt, APK đã cài Samsung; xem STATE và DEVICE_REVIEW_2026-11-06.md. Không chạy scripts/start-local-api.ps1 hoặc khởi động backend để smoke mobile.

Cập nhật: **05/11/2026**. Đọc tiếp `STATE.md` để biết việc thực sự đã hoàn thành. Đợt đang ưu tiên: tải/offline, lỗi/ràng buộc và lịch sử/hành vi; xem `../UX_PRIORITY_IMPLEMENTATION.md`.

Màn tải đã thiết kế lại và cài Samsung: quyền/quota thật trước khi xin tải, tác vụ có tên và lỗi/hành động, quản lý thư viện local. Tài khoản máy hiện tại Miễn phí nên chỉ kiểm chứng gate quyền; chưa nghiệm thu tải Premium thành công. Không đánh dấu toàn bộ audit hoàn tất.

Đợt lyrics tiếp theo: màn `/lyrics` toàn màn hình thay sheet, mở từ player header/preview, follow LRC thật + manual/recenter và transport chung. Giữ entitlement server; không nội suy plain lyrics. User chọn code/test/build trước, chưa nối máy cho lượt này; xem `../LYRICS_UX_2026-11-05.md`. Đã bổ sung màn splash chuyển động từ logo nền tảng (`lib/core/widgets/brand_splash.dart`) cùng nền launch native `#0C0C10`.

## Mục tiêu

Chuyển mobile Moodify từ Expo/React Native sang **Flutter**, trong repo độc lập. Chuyển những hành vi đã có trước; sau khi nghiệm thu chuyển đổi mới mở rộng chức năng từ backend/web và hoàn thiện thêm UX.

Đề cương yêu cầu mobile có catalog, gói dịch vụ/gia hạn, thanh toán online, phát/chuyển/tua, tìm kiếm và tìm theo cảm xúc, karaoke, offline. Backend thực tế dùng Spring Boot, MySQL và MongoDB; không đổi DB chỉ vì ví dụ công nghệ trong đề cương.

## Quy tắc ưu tiên

- Không tự thêm/xóa/sửa schema DB hoặc chạy auto-DDL. Thay đổi thực sự cần thiết phải có đề xuất cụ thể và người dùng đồng ý rõ ràng.
- API có sẵn và state/cache tạm có TTL/user scope trước; cache không thay thế sổ giao dịch, quyền tải hoặc Premium.
- Không mock trong production, không âm thầm đổi sang bài hát/dữ liệu cố định khi lỗi.
- Không tự đổi tổ chức kiến trúc. Theo feature-first + Riverpod + repositories; player toàn app.
- Không dùng thiết kế đầy chip/badge/nội dung giả; ưu tiên âm nhạc thật, chữ dễ đọc và điều khiển có tác dụng.
- Không đọc/copy key, env thật, dump, cache dependency từ workspace cũ.

## Chỉ đọc thêm khi cần

| Công việc | Đọc |
| --- | --- |
| Bắt đầu/code tiếp | `STATE.md`, `WORKFLOW.md`, `../MIGRATION_PLAN.md` |
| Tìm source | `SOURCE_MAP.md` |
| Tổ chức code, audio, offline, auth | `../ARCHITECTURE.md` |
| Endpoint/ID/payload | `../reference/API_CONTRACT.md` và controller được dẫn |
| Tính năng cũ, bẫy kế thừa | `../reference/LEGACY_AUDIT.md` |
| Giao diện | `../DESIGN.md` |
| Quyết định/phạm vi còn mở | `../DECISIONS.md` |

Repo này là mobile client. Web quản trị, worker Python, media server và database tiếp tục thuộc hệ thống cũ. Các repo cũ đang có thay đổi chưa commit; khảo sát dựa trên working tree, không chỉ Git HEAD.

Tài liệu source audit mô tả mã tại thời điểm khảo sát, chưa chứng minh endpoint đang được deploy hoặc chạy thành công. Đối chiếu code/live contract bằng môi trường được cấu hình trước khi nghiệm thu module.
