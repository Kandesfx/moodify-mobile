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
| D24 | Karaoke và quảng cáo do cộng tác viên phụ trách | Ngày 04/11/2026 người dùng yêu cầu merge; karaoke từ `Thuan_Branch` được tích hợp theo D30–D32. Quảng cáo chưa có trong nhánh này; không suy rằng ad policy đã hoàn thành |
| D25 | Offline Flutter dùng AES-256-GCM trong sandbox mới | Giữ request/confirm/verify contract, không đổi backend/schema. Không nhập file MFY1/Expo cũ; secure manifest theo API+user+device, `.part`/rename, cleanup intent dùng DELETE hiện có. Tối đa 40 MiB/1 download; RAM native vẫn là gate |
| D26 | Player phụ thuộc cổng offline có kiểu, wire tại bootstrap | `OfflinePlaybackAccess` ở domain; cùng coordinator cho stream/file. Restore lỗi mạng chỉ mở cached offline identity, không coi profile cache là phiên đã xác minh; logout purges cả khi chưa mở màn download |
| D27 | Thanh toán chỉ dùng checkout/status/management thật | Xác nhận trước checkout, không tự retry; lỗi mơ hồ yêu cầu đọc lịch sử trước lần mới, chặn thêm đơn khi còn pending. Poll tối đa 180 lần, dừng nền/lỗi/thoát; SUCCESS và hiệu lực gói lấy từ server |
| D28 | Share native là metadata cho tới khi có public deep link thật | Không dựng URL bài hát hoặc hứa share link mở app khi chưa có route/backend hợp lệ. `share_plus` 13.3.1 và secure storage dùng chung win32 tương thích; AGP nâng 8.12.1 theo yêu cầu plugin, không đổi Kotlin/Gradle |
| D29 | Lịch sử/search/lyrics/telemetry không sinh dữ liệu thay thế | Chỉ ghi lịch sử khi submit; LIMITED mood giữ thông báo bài gần nhất; LRC thật + synced entitlement, không nội suy. Guest/offline không gửi revenue, heartbeat theo tiến độ engine và không backfill khi mạng lỗi |
| D30 | Merge `Thuan_Branch` vào main theo yêu cầu người dùng | Nguồn `9b070ec`, giữ checkpoint UI/core `f0b1669`. Shell có 5 tab theo nhánh karaoke: Trang chủ/Tìm kiếm/Karaoke/Thư viện/Tài khoản. Giữ UI/motion và toàn bộ M2–M4 hiện tại; ID D24–D27 bên nhánh karaoke được hợp nhất vào D30–D32, không ghi đè quyết định offline/payment |
| D31 | Nhạc nền karaoke dùng engine và coordinator hiện có | `KaraokePlayback` chuyển DTO/controls sang `PlayerController.loadKaraoke`; source KARAOKE dùng instrumental HTTPS thuộc moodify.click, không resolver catalog, không revenue nghe nhạc, không repeat/auto-next queue nhạc thường. OS play/pause/seek dùng cùng handler. Adapter theo ownership token ổn định qua OS retry/restart ngăn màn cũ dừng/tua màn mới; thoát tab reset stack karaoke; đổi user remount màn/capture |
| D32 | Giữ luồng solo/phòng cuối cùng của nhánh karaoke | Solo scorable tạo session/capture pitch/reference và submit khi hết bài; mic-check riêng, không raw audio. Giữ cách pause/resume/cancel thực tế trong source, chưa gọi là nghiệm thu parity web. Rooms có REST polling 4 giây, mediasoup/WebRTC voice và contribution/finish; state WebSocket/reconnect và hai máy/mic/score cần kiểm chứng. Các quyết định mic-only trước đó ở nhánh nguồn đã được thay thế |
| D33 | Phân lớp hiển thị: mọi modal bottom sheet đẩy lên root navigator | Người dùng yêu cầu loại chồng chéo sheet bị mini player/thanh điều hướng đè. Flutter mặc định `useRootNavigator: false` khiến sheet rơi vào branch navigator, dưới chrome của `MainShell`. Mọi sheet mở qua `showAppModalSheet` (`core/widgets/app_sheets.dart`) khoá `useRootNavigator: true`; trật tự lớp: nội dung tab → chrome shell → route/modal trên root navigator (sheet, player, dialog, snackbar theo thứ tự mở). Sheet mới không được gọi `showModalBottomSheet` trực tiếp |
| D34 | Giao diện Studio Dark (Anti-Slop taste-skill), loại bỏ nền tím | Người dùng yêu cầu đổi màu nền, bỏ cảm giác generic AI và gradient tím. Chuyển sang bảng màu Studio Dark (`#090A0D`, `#111318`, `#171A21`, viền hairline `0x1FFFFFFF`), giữ nguyên toàn bộ nhận diện logo mark & animation splash |

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
| Repo remote | Khi người dùng yêu cầu commit/push mới | Đã có `Kandesfx/moodify-mobile`; merge karaoke từ Thuan_Branch theo yêu cầu ngày 04/11/2026. Chỉ merge local, chưa push; quảng cáo chưa có trong nhánh nguồn |

## 3. Cách cập nhật

Quyết định nhỏ trong baseline: ghi ID, lý do, hệ quả, ngày và bằng chứng. Thay đổi schema hoặc kiến trúc tổ chức lớn: ghi đề xuất và câu hỏi cụ thể, chờ người dùng chốt trước phần phụ thuộc. Không ghi “đã được duyệt” nếu chỉ do AI tự chọn. Quyết định bị thay thế giữ tham chiếu ngắn đến quyết định mới, không nối toàn bộ cuộc trao đổi.

## Bổ sung ngày 05/11/2026

- D33: Một transfer tải trong OfflineRepository hiện có chạy độc lập với serial playback; secure manifest writes được serialize. Không thêm download framework/engine. Xóa local trước, cleanup quota bền vững qua API sẵn có lúc verify/download; lỗi đồng bộ không được coi file chưa xóa. Ticket/confirm/verify vẫn bắt buộc trước completed.
- D34: Search history chỉ ghi khi submit thành công hoặc chọn kết quả có chủ đích; mood ghi nhãn/confidence thật, selection dùng history ID từ server. Reporter nghe giữ từ engine thật, không bổ sung click/timer giả vào đường doanh thu. Lịch sử nghe chỉ đọc/xóa qua API hiện có; snapshot local không thay server history.

- D35 (05/11): Pending guest action chỉ là RAM TTL10phút gồm track/action/return route, không persist credential hoặc tự replay mutation khi auth. User xác nhận tại continuation page; clear khi account đổi, kiểm tra liked trước thao tác lưu để tránh toggle ngược.
- D36 (05/11): Queue thêm/bỏ tương lai trong controller hiện có, giữ native source/position; LRC follow dùng chiều cao đo có cache và lazy builder, không thêm package animation/scroll/engine. Mini gắn vào scaffold các trang detail để không che nội dung/CTA.
- D37 (05/11): Download preflight đọc entitlement từ subscriptions/me và quota current-device từ offline/my-downloads, làm mới trước mỗi lượt tải; không dùng tên gói hoặc cache để suy quyền. Thiếu quyền/full quota chặn trước request-download, lỗi mạng/contract giữ trạng thái chưa xác minh. UI tách bộ nhớ file local và quota server; task/lỗi được ưu tiên trước thống kê, thành công chỉ sau confirm/verify hiện có. Không đổi DB/backend hoặc thêm engine/download framework; background durable, byte resume và queue nhiều job chưa triển khai.
# 06/11/2026 — Hàng chờ và mic karaoke

- Theo yêu cầu và chấp thuận rõ của người dùng, bỏ quy tắc một bài/người trong
  queue. Chuẩn bị migration đổi unique `(room_id, requester_user_id)` sang index
  thường và CREATE TABLE đầy đủ; không chạy DB trong lượt sửa. Dùng bảng nghiệp vụ
  và khóa room hiện có, không lưu queue thay thế bằng RAM/cache. Chặn trùng cùng
  track của cùng người bằng service dưới khóa room; không giới hạn số bài/người.
- Voice dùng adapter mediasoup hiện có qua factory Riverpod; mức âm lượng từng
  thành viên chỉ tác động âm thanh nghe trên máy mình, giữ tạm trong RAM của phiên.
  Không tự bật mic khi retry. Voice capture và pitch capture dùng mic lần lượt;
  khi mute không cho poll tự bật capture trở lại.

# 06/11/2026 — Quản lý hồ sơ

Trang quản lý tài khoản sửa họ tên và số điện thoại qua endpoint xác thực dùng cột sẵn có. Email và tên đăng nhập giữ chỉ đọc vì là thông tin định danh; không bổ sung quy trình đổi định danh hoặc đổi schema trong đợt này.

# 06/11/2026 — Lời đồng bộ

Theo yêu cầu người dùng, hiển thị lời có timestamp cho mọi người dùng, không kiểm tra gói; dữ liệu lời tĩnh vẫn không được tự suy ra mốc thời gian.

- D38 (05/11): Lyrics chuyển từ bottom sheet sang route `/lyrics`, dùng coordinator/Riverpod/go_router sẵn có. Sau tích hợp06/11, giữ hành vi remote: lời có LRC mở cho mọi người dùng; thiếu timing đọc tĩnh. Follow dựa trên timestamp/position engine, chiều cao TextPainter và prefix offsets có cache; animation chỉ theo dòng, không nội suy timing từ plain lyrics hoặc sửa catalog/DB. Đổi bài reset view, chạm cue và scrub đều kiểm tra identity trước seek. Theo user, lượt này code/test/build trước, chưa cài thiết bị hoặc tự push.
- D39 (05–06/11): Màn hình mở đầu dùng `SplashLaunchGate` + `BrandSplashHero` (`lib/core/widgets/brand_splash.dart`) từ mark `assets/brand/moodify-mark.png` sẵn có, kết hợp nền native launch `#0C0C10` trên Android/iOS và `@drawable/launch_mark` căn giữa trên Android. Không thêm package animation ngoài; đợi viewport thực khác 0 (`size.width > 0 && size.height > 0` + `addPostFrameCallback`) trước khi chạy controller hữu hạn (1850 ms vào + 380 ms thoát) để tránh `AudioServiceActivity` tiêu thụ mất animation lúc pre-warm engine `0×0`, rồi tự gỡ khỏi widget tree sau khi hoàn tất cùng `SessionPhase.restoring`. Tôn trọng reduced motion và giữ nguyên điều hướng `/restoring` khi lỗi mạng.
- D40 (06/11): Chuẩn hóa hệ thống bo góc `AppRadii` và bề mặt thẻ đặc trưng Moodify (`TrackTile` bo 16px, chip viên thuốc, `SectionHeading` có thanh nhấn gradient, `MiniPlayer` nổi bo 18px, gom nhóm thẻ `AccountScreen` bo 22px) đồng thời tối ưu độ mượt: tách widget con lắng nghe `position` (`_MiniPlayerProgress`, `_PlayerSeekSection`), tiết lưu `positionStream` 200 ms và tránh phát lại `playbackState` qua platform channel khi chỉ đổi vị trí, bỏ `ImageFilter.blur` trong thẻ cuộn `hero: true` và dùng `ValueNotifier` cho `Pressable`.
- D41 (06/11): Giữ nguyên màn hình `BrandSplashHero` sóng nhạc đặc trưng trong Flutter (`_WaveRevealMark`, `_SplashAuraPainter`, `_SoundwaveEqualizer`, `_AnimatedWordmark`) kèm `_loopController` lặp liên tục khi đang khôi phục phiên; ở giai đoạn trước màn splash trên Android dùng `@drawable/avd_launch_logo` (khung tròn tím phát sáng + vẽ 2 nét chữ `M` + 5 cột sóng nhạc) lặp liên tục trong `MainActivity.kt` cho đến `onFlutterUiDisplayed()`; icon ngoài màn hình chính (`mipmap-anydpi-v26`, `mipmap-*/ic_launcher.png`) dùng mẫu khung vuông bo góc nền tím đậm (`#2D224C` → `#0E0C18`), viền tím sáng và chữ `M` ở giữa; đổi `InkSparkle` sang `InkRipple` và bọc `RepaintBoundary` ở `TrackTile`.

# 08/11/2026 — Social login đa nền tảng

- D42 (08/11): Mở Google/Facebook login cho iOS ngoài Android native, dùng lại
  hợp đồng `POST auth/{provider}` (idToken/accessToken + device) không đổi.
  Google dùng Web Client ID làm `serverClientId` trên cả hai nền tảng để
  idToken khớp audience backend; iOS thêm dart-define `GOOGLE_IOS_CLIENT_ID`
  (iOS OAuth Client riêng) và `GIDClientID` + URL scheme đảo ngược trong
  Info.plist. Facebook cấu hình iOS qua Info.plist (AppID/ClientToken/scheme
  `fb<id>`); key hash vẫn chỉ áp dụng Android. Không thêm package mới.
