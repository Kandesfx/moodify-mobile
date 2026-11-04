# Quyết định kiến trúc và phạm vi

Baseline ngày **04/11/2026**. Đã có implementation M1; phân biệt lựa chọn kỹ thuật, kiểm chứng và nghiệm thu của người dùng.

## 1. Quyết định đang áp dụng

| ID | Quyết định | Căn cứ và hệ quả |
| --- | --- | --- |
| D01 | Flutter trong thư mục/repo độc lập | Yêu cầu người dùng và đề cương. Không thay framework trong repo Expo đang dùng |
| D02 | Chuyển chức năng cũ trước, mở rộng sau | Yêu cầu người dùng. Offline/karaoke rooms đã có source nên thuộc phạm vi parity |
| D03 | Không tự thay DB/schema | Yêu cầu người dùng. Áp dụng cả auto-DDL, Mongo indexes, seed và startup side effects; thay đổi thật cần chấp thuận cụ thể |
| D04 | Giữ backend hiện có là nguồn dữ liệu nghiệp vụ | Không thêm backend/DB mới cho mobile. Cache tạm không quyết định giá, Premium, bản quyền hay giao dịch |
| D05 | Feature-first + controller/repository/service | Baseline kỹ thuật cho repo mới. Domain chỉ ở nơi có logic cần độc lập; không sinh tầng trống |
| D06 | Riverpod, go_router, Dio | Một lựa chọn cho mỗi trách nhiệm để cấu trúc không phân mảnh; phiên bản chốt khi M1 theo SDK tương thích |
| D07 | Một playback coordinator toàn app | Mini/full/OS control dùng cùng engine và queue; karaoke/audio focus có điều phối |
| D08 | Secure token; state/file theo user | Sửa lỗi cách ly tài khoản trong lúc port là điều kiện đúng đắn, không phải lý do thêm bảng |
| D09 | Không copy hành vi giả và fallback sai | Follow local, duration cố định, lyrics nội suy, success giả và SANDBOX không là yêu cầu parity |
| D10 | Nền tối + tím Moodify, nội dung nhạc thật | Baseline Flutter theo nguồn web/brand đã khảo sát; DESIGN là bộ quy tắc duy nhất cho UI mới |
| D11 | Context ngắn + source map + ignore theo công cụ | Giảm việc index/đọc cả workspace. Không copy old repos/dependencies/media vào dự án mới |
| D12 | Android kiểm chứng sớm; iOS theo dõi riêng | Mã pitch cũ chỉ có Android; không hạ scope iOS hoặc tuyên bố cross-platform đạt khi chưa thử |
| D13 | M1 triển khai password auth trước social, shell nhạc ở M2 | Không hiển thị tab/nút tính năng chưa có. OAuth còn cần client/redirect/signing của app mới |
| D14 | App ID phát triển riêng | Android `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; không phải ID phát hành đã được chốt. Tên hiển thị Moodify, chưa cấu hình release signing |
| D15 | Môi trường explicit, secure token theo API base | `config/production.json` chỉ chứa URL public. Không fallback ngầm; release bắt buộc HTTPS, không mang token sang host khác |
| D16 | Lỗi mạng khi restore/refresh không tự xóa phiên | Startup chưa xác minh thì ẩn profile, cho thử lại hoặc xóa phiên. Auth bị từ chối/hết hạn thì đóng phiên; logout hủy request cũ và serialize secure cleanup |
| D17 | Không port chọn thể loại khi đăng ký USER | Backend chỉ xử lý genre cho CONTENT_LEAD; lựa chọn ở form RN không được lưu cho người nghe. Không tạo UI hứa lưu sở thích khi server bỏ qua |
| D18 | Gradle 8.14.3 bản bin cùng nhánh scaffold | Wrapper 8.14-all tải bị treo; dùng bản vá 8.14.3 đã có tại máy, URL official và SHA-256 đã đối chiếu. Không đổi AGP/Kotlin chỉ để né build |
| D19 | Home/search public như RN; xác thực ở thao tác cá nhân | Đối chiếu `Mobile/src/app/_layout.tsx`: tabs không có auth guard toàn cục. Flutter mở `/home`, giữ 4 tab, return path nội bộ có allowlist; không tạo debug account/bypass token |
| D20 | Bố cục mobile bám React Native theo yêu cầu sửa thiết kế | Ngày 04/11/2026 người dùng yêu cầu dựng theo app cũ: quick grid 2 cột, spotlight cover mờ, kệ nhạc/nghệ sĩ/album, mini nổi, full player trượt lên, search segment và library list. Thay hướng home search-first trước đó. Không sao chép nhãn trending/rank giả, random personalization hay lỗi media; xem DESIGN/UX_REVIEW |
| D21 | Kiểm tra detail localPath trước stream | Resolver cũ có bài fallback khi thiếu localPath. Flutter từ chối trường hợp này; gọi stream public không bearer, kiểm tra scheme redirect. File 404 báo lỗi, không đổi sang bài khác |
| D22 | Một native engine khởi tạo khi phát, queue thuộc controller | Native load serialize và có generation; pause trong load giữ ý định dừng. Shuffle duyệt hữu hạn, previous theo lịch sử tối đa 100 mục. Session đổi dừng/xóa queue; mini/full/OS commands cùng coordinator |
| D23 | M2–M4 là bản debug, chưa nghiệm thu release | Listening telemetry đã triển khai từ event native; entitlement/ad policy chờ nhánh cộng tác viên. Không gọi SANDBOX/cấp Premium local; chưa có bằng chứng protected API/payment/offline trên tài khoản thật |
| D24 | Karaoke và quảng cáo thuộc nhánh cộng tác viên | Người dùng xác nhận làm trên nhánh GitHub riêng. Không tự merge hay sửa feature đó; shared router/player phải tích hợp có kiểm chứng và giữ một engine |
| D25 | Offline Flutter dùng AES-256-GCM trong sandbox mới | Giữ request/confirm/verify contract, không đổi backend/schema. Không nhập file MFY1/Expo cũ; secure manifest theo API+user+device, `.part`/rename, cleanup intent dùng DELETE hiện có. Tối đa 40 MiB/1 download; RAM native vẫn là gate |
| D26 | Player phụ thuộc cổng offline có kiểu, wire tại bootstrap | `OfflinePlaybackAccess` ở domain; cùng coordinator cho stream/file. Restore lỗi mạng chỉ mở cached offline identity, không coi profile cache là phiên đã xác minh; logout purges cả khi chưa mở màn download |
| D27 | Thanh toán chỉ dùng checkout/status/management thật | Xác nhận trước checkout, không tự retry; lỗi mơ hồ yêu cầu đọc lịch sử trước lần mới, chặn thêm đơn khi còn pending. Poll tối đa 180 lần, dừng nền/lỗi/thoát; SUCCESS và hiệu lực gói lấy từ server |
| D28 | Share native là metadata cho tới khi có public deep link thật | Không dựng URL bài hát hoặc hứa share link mở app khi chưa có route/backend hợp lệ. `share_plus` 13.3.1 và secure storage dùng chung win32 tương thích; AGP nâng 8.12.1 theo yêu cầu plugin, không đổi Kotlin/Gradle |
| D29 | Lịch sử/search/lyrics/telemetry không sinh dữ liệu thay thế | Chỉ ghi lịch sử khi submit; LIMITED mood giữ thông báo bài gần nhất; LRC thật + synced entitlement, không nội suy. Guest/offline không gửi revenue, heartbeat theo tiến độ engine và không backfill khi mạng lỗi |

## 2. Các quyết định còn mở trước bước liên quan

Không cần chốt tất cả để bắt đầu code M1; tiếp tục phần độc lập và hỏi đúng lúc có ảnh hưởng thực tế.

| Việc cần chốt | Thời điểm | Mặc định/giới hạn |
| --- | --- | --- |
| Application ID, app name chính thức, signing | Khởi tạo/native OAuth | Không dùng Expo ID/signing key cũ một cách mặc định hoặc tự chọn ID cho bản phát hành |
| API/media/voice môi trường dev và staging | Trước API/device test | Cấu hình public riêng; không tự đọc/copy env production hoặc private key |
| Credential Google/Facebook và redirect | Khi làm social login | Giữ contract, không hardcode client secret; thiếu config ghi blocker riêng |
| Target thiết bị và mức hỗ trợ iOS | Trước nghiệm thu native/release | Android-first là thứ tự kiểm chứng, chưa phải người dùng đồng ý bỏ iOS |
| Adapter Flutter/native mediasoup/WebRTC | Spike đầu dự án | Chứng minh tương thích protocol trước khi chọn dependency hoặc port toàn UI |
| Quyền asset, quảng cáo, font | Trước bundle/release | Không xem giấy phép template Expo là quyền cho mọi logo/audio/catalog |
| Repo remote | Khi người dùng yêu cầu commit/push mới | Đã có `Kandesfx/moodify-mobile`; lượt cải thiện này chưa commit/push. Không tự merge nhánh karaoke/quảng cáo |

## 3. Cách cập nhật

Quyết định nhỏ trong baseline: ghi ID, lý do, hệ quả, ngày và bằng chứng. Thay đổi schema hoặc kiến trúc tổ chức lớn: ghi đề xuất và câu hỏi cụ thể, chờ người dùng chốt trước phần phụ thuộc. Không ghi “đã được duyệt” nếu chỉ do AI tự chọn. Quyết định bị thay thế giữ tham chiếu ngắn đến quyết định mới, không nối toàn bộ cuộc trao đổi.
