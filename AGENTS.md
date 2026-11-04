# Moodify Flutter — quy tắc bắt buộc cho AI

## Bắt đầu mỗi phiên

1. Đọc `docs/ai/CONTEXT.md` và `docs/ai/STATE.md`.
2. Chọn đúng module qua `docs/ai/SOURCE_MAP.md`; chỉ đọc tài liệu và source liên quan.
3. Đối chiếu nhiệm vụ với `docs/MIGRATION_PLAN.md`. Hiện ưu tiên **chuyển tính năng React Native sang Flutter trước, mở rộng sau**.
4. Kiểm tra thay đổi sẵn có. Không reset, ghi đè hoặc hoàn nguyên việc của người dùng.

## Ranh giới dữ liệu và backend

- App Flutter là client của backend Moodify hiện có. Không kết nối trực tiếp MySQL, MongoDB, Redis hoặc media database.
- Không tự thêm/xóa bảng; không tự sửa cột, collection, index, constraint, schema hoặc chạy migration/reset/seed/DDL. Không khởi động backend chỉ để khảo sát: backend cũ có auto-DDL, xem `docs/reference/LEGACY_AUDIT.md`.
- Ưu tiên API và cấu trúc đã có. Dùng state trong RAM, cache TTL, file cục bộ theo user có giới hạn khi chỉ cần lưu tạm; không lạm dụng field DB khác nghĩa hoặc biến cache thành nguồn dữ liệu nghiệp vụ.
- Nếu chức năng thực sự cần thay schema: lập đề xuất cụ thể gồm nhu cầu, phương án không đổi schema, thay đổi chính xác, ảnh hưởng, migration/rollback; **hỏi người dùng và chờ chấp thuận rõ ràng** trước khi viết/chạy thay đổi đó. Sự im lặng không phải đồng ý.
- Không sửa hoặc triển khai backend/web cũ ngoài phạm vi người dùng đã giao. Có thể tiếp tục module Flutter độc lập khi gặp một blocker backend.

## Kiến trúc và phạm vi

- Theo `docs/ARCHITECTURE.md`: feature-first, View → Riverpod controller → repository → remote/local service. Lớp domain chỉ thêm cho nghiệp vụ cần thiết.
- Một cơ chế state/DI (Riverpod), một router (go_router), một HTTP client (Dio), một playback coordinator toàn app. Không tự thêm framework song song, microservice, monorepo hoặc đổi cách tổ chức.
- Ghi quyết định nhỏ vào `docs/DECISIONS.md`. Đề xuất thay đổi kiến trúc ảnh hưởng nhiều module phải trình bày lý do và chờ người dùng chốt.
- Mỗi lần chuyển một luồng hoàn chỉnh với API thật; đánh dấu trạng thái theo bằng chứng. Có source không đồng nghĩa đã chạy được trên thiết bị.
- Không coi nút giả, switch local-only, lỗi/rủi ro cũ là yêu cầu phải sao chép. Theo cách xử lý đã ghi trong kế hoạch.
- Chỉ tạo thư mục/lớp khi có mã thật cần đặt vào. Không sinh hàng loạt repository/use-case/DTO rỗng hay file placeholder.

## Dữ liệu thật và trải nghiệm

- Production tuyệt đối không dùng mock catalog, fake user/giá/điểm hát/thanh toán/lượt nghe, hoặc thay bài lỗi bằng một bài cố định.
- Hạn chế mock lúc phát triển. Fixture/fake chỉ nằm trong test khi cần kiểm thử xác định, không được import vào `lib/` hoặc đóng gói vào release.
- API rỗng/lỗi/thiếu quyền → trạng thái rỗng/lỗi/khóa thật có hành động phù hợp. Không dùng `catch => demoData` hoặc random để làm màn hình có vẻ hoạt động.
- Dữ liệu cache phải xuất phát từ API thật, có TTL/version/user scope. Không hiển thị cache như giao dịch hay quyền Premium hiện tại.
- Tuân thủ `docs/DESIGN.md`: nội dung có mục đích, bỏ chip/badge/slogan vô nghĩa, không chép dashboard quản trị vào app người nghe.
- Không sao chép secret, private key, backup, DB dump hoặc toàn bộ repo cũ vào repo này. Không coi dart-define là nơi giữ bí mật.

## Tìm kiếm và duy trì ngữ cảnh

- Mở repo Flutter này làm workspace riêng để tránh index cả hệ thống cũ.
- Tìm trong module cụ thể bằng `rg`, đọc từng đoạn; không dump toàn repo hoặc đọc mọi tài liệu mỗi phiên.
- `.gitignore`, `.ignore`, `.vscode/settings.json` giới hạn phạm vi tương ứng; không có bảo đảm chúng chặn mọi AI indexer. Cấu hình thêm theo công cụ nếu cần, không tự bịa file ignore được hỗ trợ.
- Không commit dependency cache, build, media tải xuống, báo cáo lớn, transcript hội thoại. Commit `pubspec.lock` sau khi khởi tạo app.
- Giữ CONTEXT ngắn, STATE là trạng thái hiện tại; quyết định và bằng chứng nằm ở tài liệu chuyên trách. Không nối lịch sử chat vào AGENTS.

## Kết thúc nhiệm vụ

- Chạy kiểm tra tương ứng phần đã sửa. Khi có Dart: format, analyze và test nghiệp vụ có rủi ro; native/audio/payment/offline cần bằng chứng thiết bị phù hợp.
- Không báo test/build/runtime đạt nếu chưa chạy; ghi rõ blocker và phần chưa kiểm chứng.
- Cập nhật `docs/ai/STATE.md`, mục migration và source map khi cấu trúc/contract thay đổi.
- Báo ngắn gọn kết quả, file liên quan, kiểm chứng và bước tiếp theo. Không tự commit/push/publish nếu người dùng chưa yêu cầu.
