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

- Chạy tại root Flutter: `flutter run -d <device-id> --dart-define-from-file=config/production.json`. File này chỉ chứa APP_ENV/API URL public. Local config ở config/local theo example; emulator IP không dùng cho máy thật. Không bật backend cũ.
- Dependency khóa bằng pubspec.lock: Riverpod 2.6.1, go_router 17.5.0, Dio 5.11.1, secure storage 11.2.0, uuid 4.6.0, just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, record 6.2.1, mediasfu_mediasoup_client 0.1.4. Không thêm app DB/schema; sqflite là package cache gián tiếp.
- Android ID `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; chưa chốt ID/OAuth/signing release. Social cần config app mới; backend bỏ qua genre đăng ký USER.
- Gradle 8.14.3-bin đã đối chiếu checksum official; AGP 8.11.1/Kotlin 2.2.20. Lần build audio đầu có Kotlin incremental cache lỗi khác ổ C:/D:, compiler fallback và APK vẫn PASS; lần sau PASS khoảng 35 giây. Doctor thiếu cmdline-tools/license status unknown; không tự chấp nhận license.
- Bàn giao Git theo yêu cầu người dùng; xem commit/remote thực tế bằng Git và thông báo kết quả, không ghi lịch sử chat vào đây. Giữ AGENTS/CONTEXT/STATE ngắn; đọc source qua SOURCE_MAP; mở root Flutter riêng để tránh index workspace cũ.

- 05/11/2026: Emulator dùng API local 10.0.2.2:8088; backend chưa chạy gây lỗi restore. Đã chạy backend với port 8088, DDL/seed/maintenance/scheduling/Compose tắt; GET tracks 200, emulator kết nối được và nhấn Thử lại vào Trang chủ. Startup vẫn chạy clearPresenceAfterBackendRestart: đánh dấu thành viên karaoke đang hoạt động là đã rời và tạm dừng phòng đang phát; chưa xác định số bản ghi bị ảnh hưởng. Chưa kiểm thử karaoke.

- 05/11/2026 karaoke Android: record mặc định xin audio focus, làm player bị pause khi bắt đầu thu. PitchCapture và MicrophoneCapture không xin focus riêng trên Android; player quản lý focus. Đã bật hostmicon cho emulator Pixel_9_Pro, RECORD_AUDIO đã cấp; debug APK build thành công và thử bài 3 Phải 6 Đừng: nhạc chạy tới 0:12 khi đang thu, nút Tạm dừng. flutter analyze không lỗi. Chưa xác minh giọng hát thực, điểm cuối bài, audio interruption hoặc iOS.

- 05/11/2026: Màn hình karaoke solo bỏ điểm ước tính realtime ở góc lời theo yêu cầu; bỏ tải reference và tính điểm realtime phía client. Luồng gửi pitch features và hiển thị điểm cuối bài từ backend giữ nguyên. Dart format và flutter analyze đạt; chưa kiểm thử lại giao diện trên thiết bị sau thay đổi này.

- 05/11/2026: Thiết kế lại màn hát solo với thẻ bài hát, lời màu dịu, chuyển trạng thái ngắn và nhãn micro theo PitchCapture/MicrophoneCapture. Đồng bộ trạng thái tạm dừng/buffering, kết thúc bài và báo lỗi stream; micro vẫn mở khi nhạc tạm dừng nhưng bỏ qua mẫu. flutter analyze và build APK debug đạt; emulator Pixel 9 Pro đã kiểm tra lúc đang thu và lúc tạm dừng, chưa kiểm chứng giọng thật, lỗi micro trên thiết bị hoặc iOS.

- 05/11/2026: Karaoke solo cho phép nhấn bật/tắt micro trong phiên chấm; dừng recorder khi tắt, thêm khoảng im lặng theo vị trí phát khi bật lại/kết bài để giữ timeline, bỏ dòng trạng thái micro và dùng biểu tượng mic/mic gạch chéo. flutter analyze, APK debug đạt; emulator đã thử tắt rồi bật khi đang phát. Chưa xác nhận điểm cuối bài sau các lần bật/tắt hoặc iOS.

- 05/11/2026: Làm mới giao diện chọn chế độ karaoke, màn hát solo và hộp điểm cuối bài bằng tông tím tối; giữ pipeline âm thanh/điểm và dữ liệu lời thật. Hộp điểm hỗ trợ reduced motion và cuộn khi không đủ chiều cao. Chưa xác minh giao diện mới hoặc luồng chấm điểm trên thiết bị.

- 05/11/2026: Lỗi khôi phục phiên trên emulator do cấu hình local 10.0.2.2:8088 nhưng backend không chạy. Đã khởi động backend cổng 8088 (DDL/seed/scheduling/maintenance/Compose tắt); sau Thử lại app vào Trang chủ. Backend startup có thể tạm dừng phòng và đánh dấu thành viên karaoke đã rời. Thêm scripts/start-local-api.ps1 và hướng dẫn cấu hình External Tool Before launch; đã kiểm tra nhánh API đang chạy, chưa kiểm tra nhánh script khởi động tiến trình mới hoặc cấu hình IDE.

- 05/11/2026: Làm mới giao diện đăng nhập/đăng ký với phân cấp tiêu đề, gợi ý và biểu tượng ô nhập; giữ luồng xác thực hiện có. Chưa kiểm tra giao diện trên thiết bị.

- 05/11/2026: Bổ sung nút Google/Facebook và kết nối SDK Android qua API auth hiện có, lưu phiên qua repository. Cấu hình OAuth chưa được cung cấp; chưa xác minh đăng nhập thật, iOS chưa cấu hình. Backend Facebook hiện gọi Graph /me nhưng chưa thấy xác minh token thuộc app Meta của Moodify; cần rà soát trước production.

- 05/11/2026: Thêm Google Web Client ID do người dùng cung cấp vào hai cấu hình chạy Flutter local/production. Đã kiểm tra XML và tham số; chưa kiểm thử OAuth thật hoặc xác minh GOOGLE_CLIENT_ID trên backend đang chạy.

- 05/11/2026: Cấu hình Run local Android Studio trong workspace vẫn dùng tham số cũ; bổ sung Google Web Client ID vào các file config JSON mà cấu hình đó đọc. Chưa xác minh đăng nhập Google thật.

- 05/11/2026: Đăng nhập Google trên emulator thất bại tại Google Play Services: Account reauth failed (16), chưa xác nhận token về app hay request đến backend. Chữ ký APK debug trùng SHA-1 đã đăng ký. Đã cải thiện thông báo lỗi Google; flutter analyze và 27 test auth đạt. Cần người dùng thử xác minh lại tài khoản Google và kiểm tra lại luồng thực tế.

- 05/11/2026: OAuth Google emulator lần thử 21:10 báo chi tiết UNREGISTERED_ON_API_CONSOLE trước Account reauth failed; chứng thư APK thực cài SHA-1 73:C1:BB:2D:E1:0C:29:85:2C:9B:E5:DD:77:BD:15:AA:5B:C3:74:71. Cần đối chiếu cấu hình Android client trong Google Cloud cùng project với Web Client ID; chưa chứng minh chính xác trường sai.

- 05/11/2026: Người dùng báo Facebook chưa cấu hình. Đã thêm Facebook App ID vào gradle.properties; còn thiếu Facebook Client token, flag chưa bật và chưa kiểm thử OAuth thực. Trang Meta trong ảnh còn cảnh báo tại key hash/tên gói Android, cần xác minh đã lưu thành công.

- 05/11/2026: Đã cấu hình App ID và Client token Meta từ ảnh người dùng cho SDK Android, bật cờ Facebook trong config local/production. Chưa kiểm chứng đăng nhập thực; Meta app chưa đăng và phần cấu hình Android từng hiện cảnh báo cần kiểm tra lại.

- 05/11/2026: Facebook custom tab trả URL không được cho phép / cần nền tảng gốc hợp lệ. Android merged manifest đã đăng ký callback fbconnect cho package app. Ảnh Meta trước đó vẫn báo lỗi phần hash và package, chưa chứng minh nền tảng được lưu; cần kiểm tra trong Meta Developer trước khi xác định nguyên nhân duy nhất.

- 05/11/2026: Chuyển quảng cáo audio vào Flutter với 9 MP3 và artwork web trong assets; entitlement đọc subscriptions/me, guest theo FREE; NO_ADS, DAILY_QUOTA và FULL_ADS, bỏ qua BASIC sau 5 giây, player dùng chung và chặn tua/chuyển trong ad. Counter ngày cục bộ theo tài khoản/API. flutter analyze, 64 test và APK debug đạt; APK có 9 file. Chưa kiểm tra phát thực trên emulator/iOS hoặc subscription API bằng tài khoản thật. Chưa nối campaign ACTIVE/impression, skip quota hàng ngày hay trang Premium; không coi hoàn tất parity web hay gate release.

- 05/11/2026: Bổ sung nút Nâng VIP/Lên FULL trong quảng cáo, mở trang Premium web theo PREMIUM_WEB_URL của local/production; chỉ bỏ qua quảng cáo hiện tại khi mở trình duyệt thành công. Web và mobile đăng nhập riêng; entitlement vẫn đọc API. Đã sửa giữ duration trả về từ setAsset; cần kiểm chứng mở trình duyệt và thanh toán/đồng bộ quyền thật trên thiết bị.

- 05/11/2026: Làm mới thẻ quảng cáo mobile thành một khối gọn với artwork, bài tiếp theo, tiến độ và nút nâng cấp; giữ luồng phát/bỏ qua. flutter analyze và 17 kiểm thử player đạt, gồm 320×640 chữ 1.8 cho cả hai trạng thái bỏ qua. Chưa kiểm tra giao diện mới trên emulator.

- 05/11/2026: Sửa lỗi màn hình đỏ sau khi tạo phòng karaoke: controller ô nhập bị dispose khi dialog vẫn đang đóng; đổi sang TextField tự quản lý và sửa tương tự dialog mã mời. Sửa ref bị dùng khi widget phòng dispose. Tái hiện lỗi cũ bằng widget test; 3 test tạo phòng, nhập mã và màn nhỏ đạt; flutter analyze đạt. Chưa thử lại với tài khoản/API thật hoặc voice trên emulator; lần tạo phòng lỗi có thể đã tạo phòng trên backend.

- 05/11/2026: Làm mới danh sách và chi tiết phòng karaoke: đưa bài đang phát/điều khiển lên đầu, trình bày lại voice, thành viên và hàng đợi theo dữ liệu phòng, giữ các callback hiện có. flutter analyze và 4 widget test phòng đạt, gồm phòng có bài và màn 320×640 chữ 1.8. Chưa kiểm tra giao diện mới, voice hoặc luồng phòng thật trên emulator.

- 05/11/2026: Thiết kế lại chi tiết phòng karaoke theo phản hồi: sheet thêm bài có ô tìm kiếm (debounce 350ms), bỏ mục Âm thanh phòng và chuyển kết nối voice/bật tắt micro thành nút icon trên AppBar, thành viên chỉ còn avatar tròn (không tên, giữ tooltip và sao chủ phòng) với bấm mở sheet chỉnh âm lượng từng người, đưa Đóng phòng/Rời phòng lên AppBar dạng icon kèm tooltip. Sửa thiếu import catalogRepositoryProvider làm analyzer lỗi. dart format, flutter analyze và 4 widget test phòng đạt; chưa kiểm tra giao diện mới và luồng voice thật trên emulator.

- 06/11/2026: Gộp card sân khấu và card lời bài hát trong chi tiết phòng thành một khối duy nhất; chuyển nút Thêm bài xuống dưới panel Hàng đợi thành nút riêng cho mọi thành viên (đổi thành Rút lượt hát của tôi khi user còn lượt pending, parity web; play disable khi IDLE và hàng đợi trống, skip chỉ hiện khi có bài). Bỏ hoàn toàn nút Bắt đầu/Hoàn tất chấm điểm nhóm và PopScope chặn pop: khi có playbackRunId mới, app tự mở phiên score-session chung, tự đăng ký participant và thu PitchCapture khi PLAYING, pause thì gửi segment, gần hết bài tự finish và hiện dialog điểm chung (_KaraokeScoreDialog) một lần mỗi phiên; poll 3s lấy kết quả nếu máy chủ chốt trước. Giới hạn mobile: khi micro voice đang bật thì không thu pitch (hint 1 lần) vì không tap được PCM từ stream mediasoup; segment thiếu 2s giọng rõ bị bỏ. dart format, flutter analyze và 74 test toàn repo đạt (thêm 1 test phiên tự động, sửa assertion nút dưới đáy list); chưa kiểm chứng luồng chấm thật trên emulator.

- 06/11/2026: Người dùng báo màn splash "Không thể kết nối máy chủ" trên emulator: backend local 8088 không chạy (MySQL/MongoDB vẫn mở). Chạy lại scripts/start-local-api.ps1, API trả 200 tại 127.0.0.1:8088, tiến trình nền giữ server; người dùng bấm Thử lại là vào app. Backend không tự sống sau restart máy — cần chạy lại script hoặc cấu hình External Tool Before launch.

- 06/11/2026: Sửa lời phòng karaoke không sáng theo nhạc: widget _SyncedRoomLyrics trước đây chỉ hiểu lyricTimeline (phụ thuộc field trong asset, hay null) nên rơi vào chữ tĩnh; nay dùng chung _parseKaraokeLyrics với màn solo, ưu tiên lyricTimeline rồi tự parse lyricsSynced (LRC, đúng cách web highlight trong phòng) và highlight dòng hiện tại theo positionStream, chặn trên rồi fallback 3 dòng lời trơn. Xóa icon tai nghe kết nối voice khỏi AppBar phòng kèm _connectVoice/_toggleVoice; _voice vẫn giữ cho sheet âm lượng thành viên nhưng thực tế sẽ luôn chưa kết nối. dart format, flutter analyze và 5 test karaoke đạt; chưa xem highlight thật trên emulator.

- 06/11/2026: Sửa lời phòng sáng nhầm câu đầu trong lúc nhạc dạo: bỏ clamp active về 0 khi chưa có câu nào bắt đầu; khi position trước câu đầu hiển thị tối đa 2 câu sắp tới mờ, không highlight câu nào (khớp màn solo). dart format, flutter analyze và 5 test karaoke đạt; người dùng xác nhận trên emulator.
## Chạy và bàn giao

- Root Flutter: `flutter run -d <device-id> --dart-define-from-file=config/production.json`. File chỉ có API URL public; không bật backend cũ. APK ở `build/app/outputs/flutter-apk/app-debug.apk`.
- Dependency: cryptography 2.9.0, path_provider 2.1.6, share_plus 13.3.1, intl 0.20.2, record 6.2.1, mediasfu_mediasoup_client 0.1.4; pubspec.lock được pub get giải lại từ bản core. AGP 8.12.1/Kotlin 2.2.20/Gradle 8.14.3 giữ nguyên. Kotlin incremental cache khác ổ C:/D: có thể fallback compiler; không tắt cấu hình dự án chỉ để né cảnh báo.
- Android ID `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; chưa chốt signing/OAuth phát hành. Không tự chấp nhận SDK license.
- `docs/UX_REVIEW.md` mô tả audit/luồng mới; SOURCE_MAP dẫn tới module đúng. Giữ CONTEXT/STATE ngắn, không nạp toàn workspace cũ, không commit artifacts/build/media/cache. Merge local theo yêu cầu; không push/publish ngoài yêu cầu.

- 06/11/2026: Merge origin/main vào Thuan_Branch (commit 99fc0e5) theo lựa chọn "tích hợp cả hai": player_controller gộp quảng cáo audio với offline/lịch sử nghe/sleep timer/karaokeOwner (quảng cáo bỏ qua offline và karaoke, không ghi listening khi phát ad); player_screen giữ UI mới của main, ghép ad mini-player/artwork/skip/nút nâng cấp; karaoke_screen giữ redesign + chấm điểm chung tự động, nhận KaraokePlayback dùng chung controller, realtime scorer vẫn bị bỏ. Sửa thêm: KaraokePlayback chặn mounted để dispose an toàn, main_shell_test sửa index tab Karaoke. flutter pub get tái tạo lock. flutter analyze 0 lỗi, 121/121 test đạt. Chưa kiểm tra UI gộp trên emulator.
