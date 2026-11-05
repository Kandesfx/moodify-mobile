# Đợt ưu tiên tải, lỗi và lịch sử — 05/11/2026

## Phạm vi thực hiện

Giữ feature-first/Riverpod/Dio/go_router và một playback engine. Không sửa backend, schema/DB, chạy backend hoặc tạo dữ liệu production. Thay đổi hiện ở working tree, chưa commit/push.

| Phần | Hành vi đã có source | Còn lại |
| --- | --- | --- |
| Download/offline | Phase đúng công việc, bytes thật/indeterminate, hủy/retry bài lỗi, tiến độ có tên, menu/player mở trạng thái đã tải/đang tải; một transfer không khóa phát file hợp lệ cũ. Đợt thiết kế lại bên dưới thêm quyền/quota thật, preflight và quản lý thư viện local | Background bền vững, byte resume, queue nhiều job và disk-free preflight chưa làm; không hứa hỗ trợ |
| File/quota | Mã hóa hiện có, atomic file/confirm/verify, xóa local không mạng, cleanup intent; confirm transport mơ hồ đọc verify để tránh tải lại khi server đã nhận | RAM vẫn giữ file đầy bài tối đa 40 MiB; cần đo native, đầy bộ nhớ và kill/restart thật |
| Errors | Hủy tách session, lỗi file I/O/corrupt, 404/410 và offline request 429; lỗi job tại màn, danh sách giữ khi refresh lỗi | Không gọi taxonomy toàn app hoàn chỉnh; contract response code thiếu vẫn phải hiển thị trung thực |
| Search history | Chờ mood result có label/confidence thật; chỉ explicit-submit hoặc chọn bài; selection PATCH đúng history/query; lỗi history tách kết quả | Quản lý history phân trang/lọc riêng chưa làm; history server tối đa255 ký tự, input mood dài hơn vẫn tìm được nhưng báo chưa lưu |
| Listening history | Tài khoản → Lịch sử nghe, GET trang20, retry, phát lại cùng coordinator, xóa mục/toàn bộ có xác nhận, user remount và mini-player | Account thật/API production chưa kiểm chứng, chưa tìm/lọc/trace history |
| Hành vi | Giữ reporter play/pause/resume/seek/skip/completion engine và mutation library làm nguồn server; thêm search-selection | Recommendation feed/impression/attribution chưa port; không ghi guest/offline/karaoke vào revenue nghe nhạc |

## Kiểm chứng

Kiểm chứng cuối ngày 05/11/2026:

| Kiểm tra | Kết quả |
| --- | --- |
| Format `lib test` | 83 files, 0 changed |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | 88 tests passed |
| Android debug arm64, config production | PASS, Gradle 27,4 giây |
| `git diff --check` | Không lỗi whitespace |
| Thiết bị | ADB không có máy; chưa cài/chạy APK này trên điện thoại |
 Không dùng tests thay bằng chứng device. Các log ở `artifacts/priority-*.txt` bị ignore; APK ở `build/app/outputs/flutter-apk/app-debug.apk`.

Các test bổ sung bao gồm: phase tải; cancel khi confirm và reconcile; xóa local không gọi mạng/phục hồi intent sau restart; lỗi retry vẫn giữ library; phát offline trong lúc bài khác confirm; confirm timeout phục hồi bằng license response thật; màn320×640/text1.8 và progress không biết tổng; mood history payload/selection; invalid confidence; stale query không ghi history. Fixture chỉ ở test.

ADB 05/11 không có thiết bị. Protected API, gói thật/quota/license, lifecycle, mạng thật, I/O đầy đĩa, RAM lớn và release frame timing chưa nghiệm thu. Màn nhỏ test không thay TalkBack hoặc review thiết kế trên máy.

## Tiếp tục

1. Kiểm chứng Android/account thật cho download/cancel/verify/renew/remove/restart và history; người dùng tự đăng nhập.
2. Hoàn thiện CTA theo entitlement/quota và các mã nghiệp vụ server thực trả; thêm summary quota nếu contract được xác minh.
3. Mini-player detail, lyrics follow và intent auth đã có trong đợt continuity bên dưới; tiếp tục phần chưa có và nghiệm thu thiết bị. Không gắn DONE cho cả39 mục từ đợt ưu tiên này.

## Đợt continuity tiếp theo cùng ngày

| Hạng mục khảo sát | Source đã triển khai | Giới hạn |
| --- | --- | --- |
| 02 mini-player | Album/playlist/artist, nội dung đăng nhập inbox/subscription có mini cùng engine | GuestPrompt ở protected pages chưa gắn mini riêng; chưa claim global overlay hoàn chỉnh |
| 03 giữ ý định guest | RAM TTL10phút, like/playlist/download đi qua `/continue-action`, user xác nhận; xóa khi logout/đổi account; đã liked không đảo ngược | Không persist intent qua app kill; không auto replay mutation/tải/checkout khi auth thành công |
| 05 lyrics | Follow theo LRC thật, user scroll pause và recenter, reduced motion, entitlement error/retry/no-right/no-LRC | Chưa đo performance native bài LRC lớn/TalkBack; cần account có syncedLyrics thật |
| 12 queue | Enqueue/next/removeUpcoming, dedupe, max200, giữ vị trí bài đang chạy | Không drag reorder; thao tác thay queue bị từ chối khi loading/offline/karaoke; chưa restore snapshot |

Analyze đã đạt, toàn bộ91 tests passed; format86files. Ba test mới kiểm queue continuity, artist mini + auth intent và lyrics follow/recenter/reduced motion. APK debug Android arm64 với config production đã build thành công, Gradle32,2giây; diff check sạch. Không có thiết bị ADB; APK chưa cài trên máy. Các thông số88tests/83files ở đợt đầu phía trên là bằng chứng lịch sử, không phải trạng thái cuối mới nhất.

Các hạng mục tiếp theo còn mở: artist/collection header/play-shuffle, multi-type search, public browsing khi restore lỗi, history filtering, follow artist/device management, Home content diversity/section errors/unread count, recommendation/attribution, shared transitions và các yêu cầu download/native còn lại. Không đánh dấu cả39 mục DONE.

## Đợt artist/device và guest smoke Samsung 05/11

Đã có source cho08/09/19/20/28/32: artist public profile + follow, followed artists tab, lazy detail list, collection/liked play-shuffle-share, devices list/revoke/revoke-others và avatar account. Không gọi đây là hoàn tất mọi UI/contract hoặc nghiệm thu protected. Search đa loại, recommendation và các mục khác còn mở.

Samsung R58TC0KWATX đã cài APK/debug arm64 config production và mở thành công. Guest smoke: Home5tab →10NgànNăm PLAYING/position tăng → full/queue24 → remove-upcoming còn23 → download yêu cầu login → authBack giữ pending đúng bài → artistPC có ảnh/bio/list/mini → follow yêu cầu login. Không nhập credential. Pause ở artist bằng mini, native media PAUSED. Ảnh/XML `artifacts/device/20261105/` local ignore. Tìm thấy auth-return root artist thiếu Back, đã bổ sung fallback Home, build/cài lại và kiểm chứng loginBack→artistBack→Home5tab trên Samsung. Lượt cuối94tests, format90files, APK build/cài thành công; báo cáo tại DEVICE_REVIEW_2026-11-05.md. Không suy khả năng download/license/history account hoặc microphone từ smoke này.

## Kiểm tra signed-in Samsung

User tự đăng nhập, server trảgóiMiễn phí. Library/devices/search-history thật load; recent10NganNam xuất hiện. Download request403→0completed đúng quyền, đã sửa CTA theo lỗi để mở gói/thiết bị và cài kiểm tra lại. Không checkout/revoke hoặc xóa dữ liệu user.

Reporter PLAY/HEARTBEAT HTTP200accepted=true, số history tăng; API đọc history thiếutrackId do row mapper PlatformTrafficService, nên metadata/replay chưa nghiệm thu. Flutter không dựng tên/ảnh giả và khóa replay item thiếu dữ liệu; blockerbackend ghi tại DEVICE_REVIEW_2026-11-05.md. Chưa sửa backend/schema. Thành công download/licensing vẫn chờ accountoffline hợp lệ.
## Thiết kế lại tải nhạc, kiểm tra bản 14:48:59

Màn Nhạc đã tải tách tác vụ, bộ nhớ local/quyền quota và thư viện. Tác vụ đang tải hoặc lỗi ở đầu; artwork/tên/nghệ sĩ không bị mất sau lỗi hoặc hoàn tất. Library có tìm tên/nghệ sĩ, lọc hết hạn, phát các bản hợp lệ, xác minh/gia hạn, xóa xác nhận với dung lượng và ảnh hưởng phát nhạc. Menu/player mở trang ngay; không lặp Snackbar lỗi. Progress dùng bytes thật, tổng chưa biết dùng indeterminate.

Preflight qua subscriptions/me và offline/my-downloads theo deviceUuid thật; đồng bộ cleanup đang chờ trước kiểm tra quota. Gói không có offline hoặc quota đầy ngăn xin ticket/media, hủy lúc chờ quyền ngăn bắt đầu muộn. Lỗi đọc quyền khác với bị từ chối quyền; không giả quota0. Quyền vẫn xác minh lại ở request/confirm/verify, giữ cơ chế mã hóa/coordinator hiện tại.

Kiểm chứng source: analyze No issues found, 100 tests passed; nhóm offline cuối20tests sau chỉnh spacing; format92files/0changed, diff check sạch. Build debug arm64 production-config cuối Gradle8,9s PASS. Samsung install-rSuccess, package lastUpdateTime05/11/2026 14:48:59, giữ phiên user.

Đã xem trên máy: 0 bản/0.0MiB, Tài khoản Miễn phí, CTA xem gói mở đúng trang subscription; không thanh toán. Player10NgànNăm→Tải mở thẳng/offline, task đúng artwork/tên/PC, thiếu quyền rõ và CTA gói/thiết bị, 0completed. Quota0/0 ẩn khi không có quyền. Ảnh/XML download-redesign-final-free, download-redesign-final-blocked và subscription-link trong artifacts/device/20261105 (ignore).

Giới hạn còn lại: tài khoản Free chưa cho phép xác minh transfer thành công, bytes/cancel media thật/renew/phát mất mạng; native đầy đĩa/RAM/file lớn/kill-restart chưa nghiệm thu. Chưa có background durable/byte resume/multi-download queue/free-disk preflight. History metadata vẫn có blockerbackend đã ghi ở trên. Không sửa backend/DB, không commit/push.
