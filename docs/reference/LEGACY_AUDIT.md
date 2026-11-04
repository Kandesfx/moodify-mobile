# Khảo sát hệ thống cũ và các điểm cần xử lý khi port

Khảo sát source ngày **04/11/2026**, chỉ đọc working tree. Không chạy app/backend, không gọi DB/API, không đọc env/key. Alias source nằm trong `../ai/SOURCE_MAP.md`. Các endpoint cần đọc controller/DTO hiện tại khi triển khai, không coi tài liệu này là kết quả kiểm chứng production.

## 1. Đề cương và biên sản phẩm

`Proposal` ghi Reactjs/Flutter/Python, mobile có: catalog nhạc/album/playlist/nghệ sĩ/gói, đăng ký/gia hạn, thanh toán online, phát/chuyển/tua, tìm kiếm/cảm xúc, karaoke và offline. Repo mobile hiện dùng React Native nên cần Flutter độc lập. Các tài liệu DOCX/PDF trong `../Doc` chưa được khảo sát nội dung trong bước này; không khẳng định đã rà toàn bộ đề cương chi tiết.

Web gồm listener và các miền admin/moderator/artist/content-lead. Mobile Flutter này phục vụ listener; không chuyển dashboard quản trị chỉ vì web đã có.

## 2. Công nghệ và cách tổ chức đã thấy

| Phần | Quan sát từ source | Hệ quả khi chuyển |
| --- | --- | --- |
| Mobile | Expo 58, React Native 0.88, Expo Router, Axios, expo-audio, SecureStore, native pitch Android, RN WebRTC/mediasoup | Port hành vi/contract sang Dart/native; không copy JSX/Expo bridge hoặc build outputs |
| Web | Next App Router; `app/`, `components/`, `features/`, `lib/`; PlayerProvider toàn dashboard | Là nguồn tham chiếu UX/behavior, không bê cấu trúc layout desktop vào mobile |
| Backend | Java 21, Spring Boot; `api/ → services/ → repositories/`, `dto/`, `entities/` | API/service hiện có là nguồn contract nghiệp vụ |
| MySQL | Account/role, library/history/quyền, subscriptions/payment/devices/offline/notifications, karaoke rooms | Không thêm bảng cho state giao diện hoặc cache |
| MongoDB | Catalog tracks/artists/albums/playlists; recommendation state/events | Không tự thêm collection/index cho mobile |
| Supporting services | Python recommendation worker, Node mediasoup karaoke voice | Flutter gọi API/signaling đã có; không khởi chạy worker hay thay media architecture |

Không thấy Redis dependency/usage trong phần Java/pom được khảo sát; không đưa Redis vào thiết kế như một thành phần sẵn có. Phân bố SQL/Mongo có phần trùng domain, phải đọc service từng endpoint thay vì tự hợp nhất schema.

## 3. Phạm vi mobile quan sát được

4 tab: home, explore, library, profile; auth nằm ngoài tab stack. Có catalog/album, search thường/cảm xúc/history, playlist/liked/favorite albums, mini/full player, lyrics, queue, sleep/volume/share, subscription/QR/polling, inbox, offline, karaoke solo/rooms/voice/group scoring.

Đây là source-observed, chưa có bằng chứng chạy trên thiết bị. Ma trận chuyển đầy đủ ở `../MIGRATION_PLAN.md`; không được giảm phạm vi thành app chỉ có home/player rồi đánh dấu migration xong.

Home RN lấy 50 tracks/10 albums; quick access từ catalog đầu và spotlight random không phải personalized/recent API. Search và liked list có giới hạn trang đầu. Flutter cần phân trang/bounded cache, không port giới hạn đó thành giả định catalog nhỏ.

## 4. Hành vi UI chưa có backend hoặc dữ liệu giả cần bỏ

| Nguồn | Quan sát | Xử lý Flutter |
| --- | --- | --- |
| `Mobile/src/components/artist/ArtistDetailModal.tsx` | Follow chỉ đổi state; thiếu duration trả `3:20` | Không báo follow thành công hoặc hiển thị duration giả; follow thật là backlog qua API |
| `Mobile/src/app/(tabs)/profile.tsx` | Switch quality/data saver chưa điều khiển media; settings có nút thiếu handler | Không mang claim/toggle giả vào release |
| `Mobile/src/context/PlayerContext.tsx` | Lyrics plain được nội suy thời gian | Lời tĩnh khi không có timed lyrics; không giả đồng bộ karaoke |
| `Mobile/src/components/player/FullscreenPlayer.tsx`, `TrackActionModal.tsx` | Share có localhost URL, quality claim không chứng minh codec | Link theo config/route public thật; quality theo capability đã xác minh |
| `Web/components/dashboard/user-settings-modal.tsx` | Save profile chỉ callback local nhưng báo thành công | Không xem đây là bằng chứng API edit profile đã có |
| `Web/components/dashboard/album-card.tsx`, `playlist-card.tsx` | Stock cover fallback cố định | Dùng placeholder trung tính, không ảnh album khác |
| `Web/features/dashboard/karaoke/data/rooms.ts` | Có demo room definitions, chưa thấy caller qua tìm kiếm | Không port demo; không vì file này mà kết luận rooms thật đều mock |
| `Web/lib/auth/auth-client.ts`, `lib/api-client.ts` | Export seedDemoTraffic/devTogglePremium; chưa thấy consumer caller | Không chuyển helper dev vào Flutter |
| `Mobile/src/app/auth.tsx`, `Backend/src/main/java/com/laphuth/moodify/services/AuthenticationService.java` | Form đăng ký chọn genre nhưng backend chỉ xử lý genre cho CONTENT_LEAD | Listener USER không có bước chọn genre cho đến khi có contract lưu sở thích thật |

Web/RN còn ad assets/fallback cố định. Chỉ chuyển chiến dịch/audio thật được xác minh chính sách/quyền; không xem quảng cáo hardcode là hợp đồng production. Lỗi network bị một số helper biến thành list rỗng; Flutter phân biệt error và empty.

## 5. Rủi ro backend có bằng chứng source

| ID | Nguồn | Rủi ro và cách xử lý |
| --- | --- | --- |
| R01 | `Backend/src/main/resources/application.properties` | `spring.jpa.hibernate.ddl-auto=update` có thể sửa schema khi startup. Không tự chạy backend trong audit |
| R02 | `Backend/src/main/java/com/laphuth/moodify/services/OfflineDownloadService.java` | `@PostConstruct` tạo `offline_downloads` nếu maintenance bật; thiếu bảng phải ghi blocker, không tự chạy init |
| R03 | `Backend/src/main/java/com/laphuth/moodify/services/SubscriptionService.java` | `initDefaultPackages()` insert/upsert package/tier khi maintenance bật, mặc định true. Startup có thể ghi giá/quyền, không chỉ tạo dữ liệu khi DB rỗng |
| R04 | `Backend/src/main/java/com/laphuth/moodify/repositories/RecommendationPersistence.java` | Readiness có thể ensure Mongo indexes/TTL; kiểm soát cả index/collection side effect |
| R05 | `Backend/src/main/java/com/laphuth/moodify/services/AudioUrlResolver.java` | Thiếu localPath có thể trả một bài cố định. Flutter không copy fallback; debt backend phải xử lý trước release bị ảnh hưởng |
| R06 | `Backend/src/main/java/com/laphuth/moodify/services/SubscriptionService.java` | `/subscriptions/subscribe` kích hoạt và tạo payment SANDBOX/SUCCESS; dev-toggle cũng cấp quyền dev. Không dùng trong production Flutter |
| R07 | `Backend/src/main/java/com/laphuth/moodify/api/AuthenticationApi.java` | Logout chỉ clear SecurityContext, không vô hiệu JWT đã cấp. Client dọn local đầy đủ và không hứa revoke toàn bộ token |

Các điểm trên chưa được sửa ở lượt chuẩn bị này. Không tự thay code/config backend để giải quyết; khi đến luồng liên quan, mô tả thay đổi cụ thể trong phạm vi người dùng giao. Chỉ tắt một flag maintenance không chứng minh đã chặn mọi DDL/seed.

## 6. Session/player/offline

Auth flat response; các API không có envelope chung. Device API backend có method khác vài client cũ: revoke **PATCH**, ping **GET**. Xem API_CONTRACT trước khi port.

RN refresh chưa single-flight; logout chưa dọn đầy đủ provider/player/offline. Flutter cần session generation/cancellation và cách ly user. Token/device ID không được tự tái tạo tùy screen. Cùng UUID installation dùng theo contract với platform enum đúng endpoint.

Web có regression audit `Web/docs/PLAYER_PLAYBACK_AUDIT_20261029.md`: bài mới reset 0, restore paused, retry đúng session, repeat off dừng queue, shuffle hữu hạn, Previous theo lịch sử, callback A→B→A không trộn telemetry. Đây là bộ acceptance tham chiếu; kết quả test web trong tài liệu cũ không chứng nhận Flutter.

Offline RN dùng `src/services/offline/` và `OfflineContext.tsx`. Backend cấp URL audio/key/license, **client tải rồi mã hóa** file local. MFY1 là format file của client: header 32 bytes, magic 4 bytes, IV 16 bytes, expiry epoch-seconds bytes 20–23, payload AES-256-CTR; không có authentication tag. Không mô tả như file backend trả đã mã hóa hoặc DRM hoàn chỉnh.

Manifest/key RN theo track ID, chưa namespace user; toàn file đi qua base64/arrays dễ tăng RAM; progress là mốc cứng; confirm lỗi có thể bị bỏ qua. Flutter phải tách user/device, lấy progress thật, file `.part`/atomic rename, reconcile confirm và cleanup cache giải mã. App mới không mặc định truy cập được sandbox/token/file của Expo cũ; **migration mã chức năng không đồng nghĩa tự chuyển dữ liệu cục bộ giữa hai app**. Nếu người dùng cần nhập file cũ thì là yêu cầu riêng có đánh giá quyền/định dạng.

Offline expiry có chuỗi LocalDateTime không timezone; không mặc định UTC khi parse. Kiểm quyền khi không mạng và chống clock rollback cần đánh giá thực tế, không giả server đã giải quyết hoàn chỉnh.

## 7. Karaoke/native và tài sản

Native Android: `Mobile/modules/karaoke-pitch/android/src/main/java/expo/modules/karaokepitch/KaraokePitchModule.kt`, AudioRecord + YIN, mono PCM16 22050 Hz, frame 2048, hop 512. Có thể port thuật toán/bridge qua platform channel sau xác minh nguồn/quyền. Chưa có native iOS đối ứng trong source cũ.

Room WebSocket Spring chỉ truyền state/signaling, voice media dùng Node mediasoup + ticket. Flutter cần spike tương thích native protocol trước khi chọn package, giữ expectedVersion/clock/resync và mic arbitration. Không giả voice/score khi thiếu adapter hoặc backend.

Reuse candidates: logo/icon Moodify, thuật toán pitch, policy/contract, brand colors. Không copy Expo/react template badge/ảnh vào Flutter. Chưa thấy inventory chứng minh quyền cho toàn bộ audio quảng cáo/logo/fonts; license MIT template Expo không tự cấp quyền cho các tài sản khác. Font web WOFF2 cần nguồn font Flutter hợp lệ khi bundle. Asset/catalog remote tiếp tục lấy URL API thật, không dump vào repo.
