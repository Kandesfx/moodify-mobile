# Trạng thái hiện tại

Cập nhật: **04/11/2026**. Snapshot bàn giao; implementation không đồng nghĩa đã nghiệm thu production.

## Phạm vi và môi trường

- Root Flutter riêng: `D:\Hai\study\DATN\Moodify-Flutter`; remote `https://github.com/Kandesfx/moodify-mobile.git`, nhánh hiện tại `main`, baseline trước lượt cải thiện `ca93bcc`. Thay đổi lượt này còn ở working tree, chưa commit/push.
- Không sửa source web/backend/React Native, không khởi động backend, không DDL/migration/seed/truy cập DB. Production không có fixture/mock/fallback sang bài cố định.
- **M0 DONE; M1–M4 IN_PROGRESS; M5–M6 EXTERNAL_BRANCH; M7 NOT_STARTED.** Người dùng xác nhận cộng tác viên phụ trách karaoke và quảng cáo trên nhánh GitHub riêng. Không suy tiến độ nhánh đó từ checkout này.
- Người dùng yêu cầu kiểm tra Samsung ở **chế độ khách**, không đăng nhập hoặc tạo tài khoản để thử. APK giao diện theo RN đã cài cập nhật; package `lastUpdateTime=2026-11-04 21:46:29`, launch Status ok. Đã smoke guest trên máy, chưa coi là nghiệm thu toàn bộ tính năng/native hoặc hiệu năng release.

## Đã triển khai

- Auth: password login/register/profile/logout, device UUID, secure session theo API base, refresh single-flight/retry 401 một lần, terminal DEVICE_REVOKED, generation/cancel và secure cleanup. Restore lỗi mạng giữ credential nhưng ẩn profile chưa xác minh; có retry/clear và lối vào nhạc offline đã có license. Social OAuth chưa cấu hình native.
- Home/catalog: theo yêu cầu sửa thiết kế, bám source RN: header logo gọn, filter thể loại thật, quick grid 2 cột tối đa 6 bài, spotlight artwork mờ, shelf nhạc ngang, nghệ sĩ tròn, album và list bài. Search/mood trong tab tìm kiếm. Ẩn album shelf khi API rỗng; catalog phân trang/dedupe/error, album/artist detail. Không gọi catalog là trending/ranking/personalized khi thiếu chứng cứ.
- Search: text được giữ trong controller input, debounce/cancel/stale guard, mood submit thật, giữ LIMITED match/nhãn emotion từ DTO và không gọi bài gần nhất là đã đạt ngưỡng. Server history theo user có replay/delete/clear; chỉ ghi submit, không ghi mỗi phím. Header cuộn được khi bàn phím mở.
- Library: Playlist/Yêu thích/Album, favorite albums, liked tracks, tạo playlist riêng tư trong thư viện hoặc picker rồi thêm bài. Chủ playlist có remove song/delete/visibility, xác nhận trước xóa/công khai, chỉ báo thành công sau server. Provider/mutation theo user, không lẫn account cũ.
- Player: một coordinator/engine lazy cho stream/file/mini/full/OS controls; seek/next/previous/repeat/shuffle/history hữu hạn, volume, sleep timer, save/options, queue/lyrics sheets. LRC có timestamp thật và entitlement syncedLyrics từ server; không nội suy. Native share hiện chia sẻ tên bài/nghệ sĩ, chưa có public deep link được xác minh.
- UI/motion theo RN: palette #0C0C10/#171720/#1F1F2E/#8B5CF6, mini-player nổi có like/play/progress, tab gọn, full player cover mờ/play trắng/seek-volume mảnh/lyrics preview. Search hai segment; library list và guest card, account identity gọn. Press scale/fade/tab/section/route slide-up và cover crossfade có reduced motion. Không thêm engine/dependency animation; blur ảnh decode 360 px riêng, LRC parse theo track.
- Listening telemetry: UUID/session theo generation, event PLAY/RESUME/PAUSE/SEEK/HEARTBEAT/terminal từ engine/position thật, có thứ tự và không backfill/replay khi lỗi. Guest/offline không gửi revenue. Quảng cáo/policy phát chờ tích hợp nhánh cộng tác viên.
- Subscription/payment: typed DTO current/quotes/management, checkout có xác nhận, QR/copy thông tin, status phải khớp orderCode/amount. Poll tự động tối đa 180 lần, dừng khi nền/lỗi/thoát; phản hồi muộn không dựng lại checkout đã đóng. Lỗi tạo đơn chưa rõ kết quả buộc refresh lịch sử; còn pending thì chặn đơn mới, có kiểm tra/hủy trong lịch sử. Không gọi SANDBOX/dev-toggle/webhook hoặc tự cấp Premium.
- Notifications: list/read/read-all thật; lỗi không biến thành inbox rỗng. Billing link relative trong allowlist mở gói dịch vụ, không mở URL tùy ý. Account có entry gói/offline/inbox, refresh profile đúng tên và xác nhận logout.
- Offline: HTTPS media riêng không bearer, một lượt tải tối đa 40 MiB, AES-256-GCM nonce ngẫu nhiên + tag, `.part`/rename, SHA256/confirm/verify trước khi xuất hiện completed. File private/secure manifest theo API+user+device; expiry/clock rollback/revoke/remove/renew theo API thật. Cleanup intent chỉ chứa ID, reconcile reservation qua DELETE có sẵn sau lỗi/kill. Một plaintext phát tạm, dọn khi đổi bài/restart/close/logout; purge cả khi manifest chưa từng mở. Không nhập sandbox/MFY1/credential Expo cũ.

## Bằng chứng hiện tại

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

## Gate còn lại

1. Guest smoke home/search/player/queue/plain lyrics/library → sign-in đã chạy trên Samsung bản mới. Còn mood worker/artist/share và kiểm chứng motion/performance bằng profile/release; không suy hiệu năng từ APK debug hoặc ảnh tĩnh. Screenshot/XML cục bộ trong `artifacts/device/` bị ignore, không đưa vào repo. Không tự đăng nhập hoặc gửi credential trong chat.
2. Tài khoản thật do người dùng tự thao tác: auth/restore/logout, favorite/playlist/history/inbox, checkout pending/success/cancel/expiry trong môi trường thanh toán phù hợp. Backend status không trả lại QR/bank cho đơn đã đóng; chỉ khôi phục kiểm tra trạng thái/hủy qua management.
3. Offline native: tải/xác minh/phát khi mất mạng, expired/revoked, thiếu file/key, storage full, kill/restart, thay account, license hết hạn giữa lúc phát; đo RAM với file lớn. Hiện giữ buffer toàn bài khi mã hóa/giải mã, giới hạn 40 MiB chưa thay thế đo RAM. Không gọi đây là DRM hoàn chỉnh.
4. Tích hợp nhánh karaoke/quảng cáo vào router/player dùng chung: giữ một engine/coordinator, audio focus, telemetry/quyền phát/ad đúng contract. Không tự merge nhánh của cộng tác viên. Shared files đã thay: router, bootstrap, player_controller/player_screen/playback_engine, catalog widgets/models và pubspec.
5. Social OAuth/app IDs/signing, iOS/macOS build, Bluetooth/interruption/lock screen, release performance và toàn catalog vẫn chưa nghiệm thu. Mood worker và album detail còn cần dữ liệu/môi trường tích hợp (album hiện rỗng).

## Chạy và bàn giao

- Root Flutter: `flutter run -d <device-id> --dart-define-from-file=config/production.json`. File chỉ có API URL public; không bật backend cũ. APK ở `build/app/outputs/flutter-apk/app-debug.apk`.
- Thêm cryptography 2.9.0, path_provider 2.1.6, share_plus 13.3.1, intl 0.20.2; pubspec.lock khóa dependency. AGP 8.12.1 theo yêu cầu share_plus, Kotlin 2.2.20/Gradle 8.14.3 giữ nguyên. Đã gặp Kotlin incremental cache khác ổ C:/D: ở lần build trước, compiler fallback vẫn build được.
- Android ID `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; chưa chốt signing/OAuth phát hành. Không tự chấp nhận SDK license.
- `docs/UX_REVIEW.md` mô tả audit/luồng mới; SOURCE_MAP dẫn tới module đúng. Giữ CONTEXT/STATE ngắn, không nạp toàn workspace cũ, không commit artifacts/build/media/cache. Không tự commit/push trong lượt này.
