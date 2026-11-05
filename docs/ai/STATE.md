# Trạng thái hiện tại

Cập nhật: **05/11/2026**. Snapshot bàn giao; implementation không đồng nghĩa đã nghiệm thu production.

## Bàn giao GitHub — 05/11/2026

Người dùng yêu cầu cập nhật GitHub. Đợt cải tiến tải/offline, lỗi, lịch sử, player continuity, artist/device và tài liệu kiểm chứng được gom vào commit trên `main` để đẩy tới `origin` (`Kandesfx/moodify-mobile`). Các dòng “chưa commit/push” bên dưới là snapshot của từng lượt triển khai trước yêu cầu này; xem Git log và đối chiếu `origin/main` để kiểm chứng trạng thái đồng bộ. Không đưa APK, log, ảnh/XML thiết bị hoặc dữ liệu runtime lên Git.

## Thiết kế lại trải nghiệm tải nhạc — 05/11/2026

- `/offline` có tác vụ ưu tiên ở đầu trang (ảnh/tên bài, phase, bytes thật hoặc indeterminate, hủy, lỗi và hành động phù hợp), thống kê số bản/dung lượng local, quyền gói và quota theo thiết bị, thư viện lazy có tìm/lọc hết hạn/phát bản hợp lệ/xác minh/gia hạn/xóa có xác nhận. Không hiển thị quota 0/0 khi gói không cho tải; lỗi kiểm tra quyền không bị biến thành gói miễn phí hoặc quota 0.
- `OfflineAccessRepository` dùng GET subscriptions/me + offline/my-downloads cùng deviceUuid thật. Trước mỗi lượt tải, đồng bộ cleanup đang chờ rồi kiểm tra lại entitlement/quota; không có quyền hoặc hết quota thì không gọi request-download/media. Hủy khi đang kiểm tra quyền ngăn tác vụ bắt đầu muộn. Server request/confirm/verify vẫn quyết định cuối cùng, không dùng cache để cấp quyền.
- Menu/player mở `/offline` ngay sau yêu cầu tải, giữ đúng bài và lỗi trên trang; thành công giữ tên tác vụ và bản tải đã xác minh. Phát bản có sẵn dùng coordinator hiện tại. Không sửa backend/DB hoặc thêm framework/dependency.
- Kiểm chứng: analyze sạch; **100 tests passed**, nhóm offline cuối **20 tests passed** sau chỉnh spacing; format **92 files/0 changed**, diff check sạch; APK debug arm64 production-config **PASS** (Gradle cuối 8,9s). Samsung install-r Success, package lastUpdateTime **05/11/2026 14:48:59**, giữ phiên đăng nhập.
- Trên Samsung: quyền thật Miễn phí, 0 bản/0.0 MiB, CTA mở đúng Gói dịch vụ; từ player 10 Ngàn Năm bấm tải → tác vụ Cần xử lý đúng bài, thông báo thiếu quyền và CTA gói/thiết bị, không completed giả. Ảnh/XML `artifacts/device/20261105/download-redesign-final-*` (ignore); báo cáo `../DEVICE_REVIEW_2026-11-05.md`.
- Gate: tài khoản hiện tại không có offline entitlement nên chưa thử được tải thành công/bytes/hủy media/phát mất mạng trên máy. Chưa có queue nhiều download, byte pause/resume hoặc tác vụ tải bền vững sau kill. Free disk preflight, RAM/file lớn, đầy bộ nhớ và native lifecycle vẫn cần kiểm chứng. Chưa commit/push.

## Kiểm tra tài khoản thật Samsung — 05/11/2026

- User tự login. Server current subscription=Miễn phí, devices1/1active và nhận diện máy hiện tại, library/followed load, search recent lưu10NganNam. Không thanh toán/upgrade/revoke/xóa dữ liệu hiện có.
- Offline0bài; request tải bị403. Đã sửa UI lỗi theo context OFFLINE_FORBIDDEN, CTA kiểm tra gói/thiết bị thay retry mù; cài và thấy đúng trên máy. Không coi đây là nghiệm thu tải thành công/offlinePremium.
- PLAY/HEARTBEAT thật HTTP200 accepted=true; history tăng nhưng metadata thiếu. Source backend PlatformTrafficService row mapper bỏ trackId, enrichment null→fallback; Flutter khóa play ở mục thiếu source/ID và báo thiếu dữ liệu server. Chưa sửa backend/DB. Chi tiết evidence/gate tại `../DEVICE_REVIEW_2026-11-05.md`.
- Debug observation log chỉ event/status/accepted, không credentials/payload/track/user. Lượt cuối95tests passed, analyze sạch, format90files; kết quả build/cài cuối xem báo cáo. Mục lịch sử nghe vẫn có blocker backend, không gắn DONE.

## Đợt artist/device và kiểm tra Samsung — 05/11/2026

- Source mới: ArtistRepository/profile + follow mutation và followed list theo user; Artist header ảnh/tên/bio/followers từ server, follow/share, play/shuffle, albums và lazy track sliver. Library thêm tab Nghệ sĩ; album/playlist thêm shuffle/share và lazy tracks; liked có play/shuffle. Thông tin artist là dữ liệu server, chưa coi mọi bio/ảnh nguồn là được kiểm duyệt.
- DeviceRepository/DeviceScreen tại `/devices`: list active/max, phân biệt máy hiện tại theo UUID thật, revoke một máy/others có xác nhận; current revoke đi logout. Account có entry thiết bị và avatar server. Source chưa nghiệm thu thao tác protected trên tài khoản thật.
- Samsung SM-A235F/R58TC0KWATX nhận ADB, cài update APK Success và launch Status ok. Guest Home 5tab, chọn10NgànNăm, full player/Android media PLAYING tiến độ tăng; queue24→23 sau bỏ bài sắp phát, không ngắt bài đang phát. Tải guest→login, Back về continuation vẫn giữ đúng10NgànNăm. Menu→artistPC load profile/list thật, mini giữ track và phát; follow guest→login. Chưa tự đăng nhập/mutation library/follow/device/payment.
- Thấy lỗi guest auth-return làm artist thành root không Back/Home: đã sửa AppBar fallback, build/cài lại và xác nhận loginBack→artistBack→Home5tab trên máy. File ảnh/XML chọn lọc ở artifacts/device/20261105/ (ignore). Chưa lấy guest smoke làm bằng chứng tải/Premium/history/lyrics sync/voice hoặc performance.
- Unit tests mới artist/device payload, double tap và disposed completion; regression Back trong continuity_test. Lượt cuối **94tests passed**, format90files/0changed, APKdebug arm64 **PASS**; package lastUpdateTime05/11/2026 09:54:08. Xem `../DEVICE_REVIEW_2026-11-05.md`. Kết thúc Home/mini paused, chưa userlogin; các kiểm tra protected chưa đạt bằng chứng.

## Đợt tiếp theo: tính liên tục và player — 05/11/2026

- Mini-player được gắn ở album/playlist/nghệ sĩ và phần nội dung đã đăng nhập của inbox/gói dịch vụ, ngoài shell/offline/history đã có. Vẫn cùng controller/engine; fullscreen player không có mini lặp. GuestPrompt của các trang protected chưa có mini riêng.
- Queue: thêm cuối/phát tiếp theo từ menu bài, bỏ bài sắp phát ở queue sheet. Giữ track/position/source và engine đang chạy; dedupe ID, giới hạn200, không sửa queue khi loading/offline/karaoke. Không có drag reorder hoặc snapshot restore sau restart.
- Lyrics: bám dòng timestamp thật, đo chiều cao theo text scale/font/width và cache theo dữ liệu/layout; kéo tay tạm dừng follow, nút Về câu đang phát. Reduced motion jump không animate; lỗi entitlement có retry, thiếu quyền có entry gói, thiếu LRC có nhãn. Không nội suy plain lyrics.
- Guest track intent: RAM TTL10 phút cho like/playlist/download, route `/continue-action` thuộc return allowlist; sau auth người dùng thấy đúng bài và xác nhận thao tác. Đăng xuất/đổi user xóa intent; bài đã liked không bị toggle bỏ thích. Không tự chạy checkout/download ngay khi login.
- Ba test mới trong `test/features/player/continuity_test.dart`: queue không restart engine; mini ở artist + intent login/logout; LRC follow/manual/recenter với reduced motion. Analyze sạch và toàn bộ **91 tests passed**. APK debug arm64 config production **PASS** (Gradle32,2s), format86files; giới hạn ở `../UX_PRIORITY_IMPLEMENTATION.md`; ADB vẫn không có thiết bị, chưa nghiệm thu motion/audio/auth thật sau thay đổi. Working tree chưa commit/push, không sửa DB/backend.

## Đợt ưu tiên UX ngày 05/11/2026

- Đã triển khai source: tải có phase chuẩn bị/bytes/mã hóa/confirm/verify, tổng bytes chưa biết dùng indeterminate; hủy, retry đúng bài, lỗi cố định trên màn, đường mở tiến độ từ menu/player; nút player/menu nhận biết đã tải/đang tải. Không pause/resume byte hoặc background-download guarantee.
- Transfer riêng trong repository hiện có, vẫn một job tải; giữ hàng tuần tự cho playback/file và serialize secure manifest writes. Phát file cũ không chờ transfer/confirm bài mới. Xóa local không cần mạng; intent đồng bộ quota được lưu và flush khi verify/download tiếp. Confirm timeout/5xx đọc verify thật trước, chỉ completed nếu quyền server hợp lệ.
- Error: phân biệt hủy với session, lỗi file storage/corrupt, nội dung 404, ticket 410, hạn mức request-download 429 theo ngữ cảnh. Giữ danh sách đã biết khi refresh lỗi, không thay bằng thư viện rỗng. Chưa phải hoàn thiện taxonomy lỗi toàn app hoặc mọi native failure.
- History/hành vi: mood DTO giữ confidence thật; chỉ explicit submit thành công ghi history; click chọn bài từ kết quả thường cũng tạo history nếu chưa submit rồi PATCH selection. Chờ request tạo history khi cần, guard query/user/stale result; lỗi ghi hiện riêng, kết quả tìm vẫn dùng được. Reporter engine hiện có giữ nguyên: không gộp click, guest/offline/karaoke vào revenue nghe nhạc.
- Thêm `/history` từ Tài khoản: GET history phân trang 20, retry, phát lại qua coordinator, DELETE mục/toàn bộ có xác nhận. Remount theo user, có mini-player. Chưa có filter/tìm history hoặc trace-event UI.
- Phạm vi yêu cầu và backlog: khảo sát 39 mục tại workspace cũ `../Moodify/tasks/mobile-ux-parity-audit-2026-11-05.md`; các mục 01/06/07/18/37/38/39 được xử lý một phần theo bằng chứng trên. Không đánh dấu 39 mục hoàn tất. Các nguồn hành vi favorite/playlist vẫn là mutation server hiện có, chưa port recommendation/impression/feedback/device management trong đợt này.
- Kiểm chứng cuối: **88 tests passed**, analyze **No issues found**, format **83 files/0 changed**, APK debug arm64 production-config **PASS** (Gradle27,4s), diff check sạch. Giới hạn: xem `../UX_PRIORITY_IMPLEMENTATION.md`. ADB ngày 05/11 không có thiết bị; chưa cài APK này, chưa xác minh protected APIs/Premium/offline trên account thật hoặc hiệu năng RAM/profile. Code chưa commit/push; không sửa backend/schema/DB.

## Phạm vi và môi trường

- Root Flutter riêng: `D:\Hai\study\DATN\Moodify-Flutter`; remote `https://github.com/Kandesfx/moodify-mobile.git`, nhánh `main`. Checkpoint toàn bộ core/UI trước merge: `f0b1669`; nguồn karaoke `origin/Thuan_Branch` tại `9b070ec`. Người dùng yêu cầu merge ngày 04/11/2026. Commit merge xem Git log; chưa push lên origin.
- Không sửa source web/backend/React Native, không khởi động backend, không DDL/migration/seed/truy cập DB. Production không có fixture/mock/fallback sang bài cố định.
- **M0 DONE; M1–M6 IN_PROGRESS; M7 NOT_STARTED.** Karaoke đã tích hợp từ nhánh cộng tác viên; quảng cáo không có trong commit nguồn và vẫn là gate riêng. Không coi merge/build thành nghiệm thu karaoke/native.
- Người dùng yêu cầu kiểm tra Samsung ở **chế độ khách**, không đăng nhập hoặc tạo tài khoản để thử. APK giao diện theo RN đã cài cập nhật; package `lastUpdateTime=2026-11-04 21:46:29`, launch Status ok. Đã smoke guest trên máy, chưa coi là nghiệm thu toàn bộ tính năng/native hoặc hiệu năng release.

## Đã triển khai

- Auth: password login/register/profile/logout, device UUID, secure session theo API base, refresh single-flight/retry 401 một lần, terminal DEVICE_REVOKED, generation/cancel và secure cleanup. Restore lỗi mạng giữ credential nhưng ẩn profile chưa xác minh; có retry/clear và lối vào nhạc offline đã có license. Social OAuth chưa cấu hình native.
- Home/catalog: theo yêu cầu sửa thiết kế, bám source RN: header logo gọn, filter thể loại thật, quick grid 2 cột tối đa 6 bài, spotlight artwork mờ, shelf nhạc ngang, nghệ sĩ tròn, album và list bài. Search/mood trong tab tìm kiếm. Ẩn album shelf khi API rỗng; catalog phân trang/dedupe/error, album/artist detail. Không gọi catalog là trending/ranking/personalized khi thiếu chứng cứ.
- Search: text được giữ trong controller input, debounce/cancel/stale guard, mood submit thật, giữ LIMITED match/nhãn emotion từ DTO và không gọi bài gần nhất là đã đạt ngưỡng. Server history theo user có replay/delete/clear; chỉ ghi submit, không ghi mỗi phím. Header cuộn được khi bàn phím mở.
- Library: Playlist/Yêu thích/Album, favorite albums, liked tracks, tạo playlist riêng tư trong thư viện hoặc picker rồi thêm bài. Chủ playlist có remove song/delete/visibility, xác nhận trước xóa/công khai, chỉ báo thành công sau server. Provider/mutation theo user, không lẫn account cũ.
- Player: một coordinator/engine lazy cho stream/file/mini/full/OS controls; seek/next/previous/repeat/shuffle/history hữu hạn, volume, sleep timer, save/options, queue/lyrics sheets. LRC có timestamp thật và entitlement syncedLyrics từ server; không nội suy. Native share hiện chia sẻ tên bài/nghệ sĩ, chưa có public deep link được xác minh.
- Karaoke sau merge: tab riêng giữa Tìm kiếm/Thư viện, solo catalog/detail/lyrics, session/pitch PCM16-YIN/reference/realtime score và submit khi hết bài; mic-check riêng. Phòng có public/private/queue/playback/voice ticket + mediasoup-WebRTC/contribution/finish; REST poll 4 giây, chưa có state WebSocket/reconnect parity. Record 6.2.1 và mediasfu_mediasoup_client 0.1.4 đã hợp nhất dependency; giữ cryptography/share/offline/payment hiện tại.
- Tích hợp audio: bỏ AudioPlayer karaoke riêng, thêm `KaraokePlayback` adapter vào PlayerController/engine chung. Instrumental HTTPS moodify.click đi thẳng engine, không catalog resolver/fallback hoặc revenue nghe nhạc. Không auto-next/repeat queue thường khi karaoke kết thúc. Adapter theo ownership token ngăn dispose/seek màn cũ đụng màn mới, giữ điều khiển sau retry/restart từ OS; reset nested karaoke stack khi thoát tab và remount theo user để dọn capture/voice. Guest không gửi request protected chỉ vì mở solo/rooms; sign-in return allowlist gồm route karaoke.
- UI/motion theo RN: palette #0C0C10/#171720/#1F1F2E/#8B5CF6, mini-player nổi có like/play/progress, tab gọn, full player cover mờ/play trắng/seek-volume mảnh/lyrics preview. Search hai segment; library list và guest card, account identity gọn. Press scale/fade/tab/section/route slide-up và cover crossfade có reduced motion. Không thêm engine/dependency animation; blur ảnh decode 360 px riêng, LRC parse theo track.
- Listening telemetry: UUID/session theo generation, event PLAY/RESUME/PAUSE/SEEK/HEARTBEAT/terminal từ engine/position thật, có thứ tự và không backfill/replay khi lỗi. Guest/offline không gửi revenue. Quảng cáo/policy phát chờ tích hợp nhánh cộng tác viên.
- Subscription/payment: typed DTO current/quotes/management, checkout có xác nhận, QR/copy thông tin, status phải khớp orderCode/amount. Poll tự động tối đa 180 lần, dừng khi nền/lỗi/thoát; phản hồi muộn không dựng lại checkout đã đóng. Lỗi tạo đơn chưa rõ kết quả buộc refresh lịch sử; còn pending thì chặn đơn mới, có kiểm tra/hủy trong lịch sử. Không gọi SANDBOX/dev-toggle/webhook hoặc tự cấp Premium.
- Notifications: list/read/read-all thật; lỗi không biến thành inbox rỗng. Billing link relative trong allowlist mở gói dịch vụ, không mở URL tùy ý. Account có entry gói/offline/inbox, refresh profile đúng tên và xác nhận logout.
- Offline: HTTPS media riêng không bearer, một lượt tải tối đa 40 MiB, AES-256-GCM nonce ngẫu nhiên + tag, `.part`/rename, SHA256/confirm/verify trước khi xuất hiện completed. File private/secure manifest theo API+user+device; expiry/clock rollback/revoke/remove/renew theo API thật. Cleanup intent chỉ chứa ID, reconcile reservation qua DELETE có sẵn sau lỗi/kill. Một plaintext phát tạm, dọn khi đổi bài/restart/close/logout; purge cả khi manifest chưa từng mở. Không nhập sandbox/MFY1/credential Expo cũ.

## Bằng chứng trước merge

| Kiểm tra | Kết quả |
| --- | --- |
| Toolchain | Flutter 3.41.6 / Dart 3.11.4, Java 21, Android minSdk 24 |
| Test lượt thiết kế theo RN | **71 tests passed** với `flutter test --no-pub --reporter expanded`; fixture chỉ ở test |
| Test có rủi ro | Auth/session/mutation/load races, player one-engine/repeat/shuffle/seek/sleep, LRC, offline encryption/tamper/user isolation/restart/failed confirm/revocation/logout, ambiguous checkout/double tap/late status, mood LIMITED |
| UI widget | Guest home → player → library guest prompt → search/mood, 320×640 text scale 1.8 và bàn phím inset 280 không overflow, thêm reduced-motion scenario; auth cũng có test màn nhỏ. Đã sửa AnimatedSize tự dirty khi duration 0 và helper cuộn tới login trước khi tap |
| Analyze/format | `flutter analyze --no-pub`: **No issues found**; `dart format --output=none --set-exit-if-changed lib test`: **72 files, 0 changed**; `git diff --check` không lỗi whitespace |
| APK | **PASS** bản cuối: `flutter build apk --no-pub --debug --target-platform android-arm64 --dart-define-from-file=config/production.json`; Gradle 15,9 giây. APK debug, không phải release |
| Samsung bản mới nhất | SM-A235F/R58TC0KWATX: `adb install -r` Success, package lastUpdateTime 04/11/2026 21:46:29, launch Status ok. Đã xem screenshot home/mini/full/search/library; tìm `10 Ngan Nam` trả đúng `10 Ngàn Năm`; phát bài đó, Android media session PLAYING và tiến độ tăng. Queue 24 bài, lyrics sheet thật, thu nhỏ/Back/tab và guest library → sign-in hoạt động. Đã pause qua media session, kết thúc ở Home với mini paused. Không đăng nhập/mutation |
| Thiết bị baseline trước redesign | Samsung SM-A235F Android 14/API34: home/catalog/search và `10 Ngàn Năm` phát/pause/seek/background/OS play đã chạy thật. Đây là bằng chứng baseline, không áp dụng cho tính năng mới |
| API chỉ đọc baseline | Catalog 538 bài, albums 0; một số stream Range206 audio/mpeg. `03 Hay Là`, `1-800-LOVE` media404; báo lỗi, không đổi bài. Resolver backend thiếu localPath có fallback sai, Flutter chặn trước stream/download |
| Protected API | Chưa xác minh login/register/library/inbox/payment/offline bằng tài khoản thật; test không thay thế bằng chứng này |

## Bằng chứng sau merge

| Kiểm tra | Kết quả |
| --- | --- |
| Nguồn và phạm vi | `origin/Thuan_Branch` tại `9b070ec` hợp nhất trên checkpoint `f0b1669`; giữ core/UI, thêm karaoke; chưa push |
| Analyze/format | `flutter analyze --no-pub`: **No issues found**; format `lib test`: **80 files**, đã format file thay đổi; kiểm tra format cuối không còn thay đổi |
| Test | `flutter test --no-pub --reporter expanded`: **78 tests passed**. Thêm 7 test karaoke dùng một engine, instrumental retry, chuyển nguồn/dispose màn cũ, OS restart sau completion/failure và từ chối nguồn không hợp lệ; guest shell 5 tab có kiểm tra màn nhỏ/text lớn/reduced motion |
| Android build | **PASS** `flutter build apk --no-pub --debug --target-platform android-arm64 --dart-define-from-file=config/production.json`; Gradle 15,8 giây; APK debug ở `build/app/outputs/flutter-apk/app-debug.apk` |
| Native | `adb devices -l` không có thiết bị. APK sau merge chưa cài/chạy trên Samsung; mic/scoring/voice/phòng chưa được xác minh trên thiết bị |

## Gate còn lại

1. Guest smoke home/search/player/queue/plain lyrics/library → sign-in đã chạy trên Samsung bản mới. Còn mood worker/artist/share và kiểm chứng motion/performance bằng profile/release; không suy hiệu năng từ APK debug hoặc ảnh tĩnh. Screenshot/XML cục bộ trong `artifacts/device/` bị ignore, không đưa vào repo. Không tự đăng nhập hoặc gửi credential trong chat.
2. Tài khoản thật do người dùng tự thao tác: auth/restore/logout, favorite/playlist/history/inbox, checkout pending/success/cancel/expiry trong môi trường thanh toán phù hợp. Backend status không trả lại QR/bank cho đơn đã đóng; chỉ khôi phục kiểm tra trạng thái/hủy qua management.
3. Offline native: tải/xác minh/phát khi mất mạng, expired/revoked, thiếu file/key, storage full, kill/restart, thay account, license hết hạn giữa lúc phát; đo RAM với file lớn. Hiện giữ buffer toàn bài khi mã hóa/giải mã, giới hạn 40 MiB chưa thay thế đo RAM. Không gọi đây là DRM hoàn chỉnh.
4. Karaoke đã merge theo yêu cầu. Còn nghiệm thu Android: instrumental/scoring reference/score thật, xin/từ chối quyền mic, rời tab trong lúc load/thu, interruption/background, hai máy voice/room/reconnect. Samsung không xuất hiện trong ADB lúc merge; APK sau merge chưa được cài lên máy. Quảng cáo/quyền phát/ad policy chưa có trong nhánh nguồn, chưa merge hoặc xác minh.
5. Social OAuth/app IDs/signing, iOS/macOS build, Bluetooth/interruption/lock screen, release performance và toàn catalog vẫn chưa nghiệm thu. Mood worker và album detail còn cần dữ liệu/môi trường tích hợp (album hiện rỗng).

## Chạy và bàn giao

- Root Flutter: `flutter run -d <device-id> --dart-define-from-file=config/production.json`. File chỉ có API URL public; không bật backend cũ. APK ở `build/app/outputs/flutter-apk/app-debug.apk`.
- Dependency: cryptography 2.9.0, path_provider 2.1.6, share_plus 13.3.1, intl 0.20.2, record 6.2.1, mediasfu_mediasoup_client 0.1.4; pubspec.lock được pub get giải lại từ bản core. AGP 8.12.1/Kotlin 2.2.20/Gradle 8.14.3 giữ nguyên. Kotlin incremental cache khác ổ C:/D: có thể fallback compiler; không tắt cấu hình dự án chỉ để né cảnh báo.
- Android ID `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; chưa chốt signing/OAuth phát hành. Không tự chấp nhận SDK license.
- `docs/UX_REVIEW.md` mô tả audit/luồng mới; SOURCE_MAP dẫn tới module đúng. Giữ CONTEXT/STATE ngắn, không nạp toàn workspace cũ, không commit artifacts/build/media/cache. Merge local theo yêu cầu; không push/publish ngoài yêu cầu.
