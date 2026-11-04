# Contract API cho Flutter

Khảo sát source ngày **04/11/2026**, từ working tree hiện có. Phần lớn **chưa kiểm chứng runtime/deployment**. Probe đọc cùng ngày tại `https://api.moodify.click/api`: `/tracks?page=0&size=1` trả 200 đúng envelope, `/auth/me` không token trả 401. Chưa xác minh password auth thành công trên server thật.
Endpoint tồn tại trong source không chứng minh dịch vụ hoặc plugin native đang hoạt động.

Probe M2 cùng ngày: catalog có 538 bài, albums total 0, artists query trả list thật. Stream trả 302 HTTPS sang media host; Range trên file hợp lệ trả 206 audio/mpeg. `03 Hay Là` và `1-800-LOVE` trả 404 tại media, `10 Ngàn Năm`/`1000 Ánh Mắt`/`2 4` trả 206. Đây là snapshot, không đảm bảo mọi bài có localPath đều tồn tại. Không sửa DB hoặc dùng fallback để che lỗi. Android đã phát `10 Ngàn Năm`; mood/auth/library cần xác minh luồng thật riêng.
`Backend/` là alias repo backend trong `../ai/SOURCE_MAP.md`, không phải thư mục sẽ copy vào repo Flutter.
Mọi đường dẫn source bên dưới tính từ alias đó; mở controller và DTO liên quan trước khi triển khai.
Không khởi động backend để đọc contract: có auto-DDL/seed, xem `LEGACY_AUDIT.md`.

## 1. Quy ước chung

- Flutter chỉ gọi HTTP/WebSocket; không truy cập database hoặc worker trực tiếp.
- Base URL lấy từ cấu hình môi trường; không hardcode host production hoặc giữ secret trong dart-define.
- Protected HTTP gửi `Authorization: Bearer <accessToken>` và `X-Device-Uuid` ổn định.
- Không gửi bearer token sang media host khác khi follow redirect nếu host đó không cần xác thực.
- Track/artist/album/playlist IDs phải giữ dạng chuỗi; không giả định tất cả là Spotify ID hoặc số.
- `TrackResponse.id` và `spotifyId` là hai trường riêng; backend có thể fallback `spotifyId` sang internal `id`.
- Tham số có tên `trackSpotifyId` vẫn phải đối chiếu controller/service, không tự đổi thành Mongo ID.
- `durationMs`, `positionMs`, `targetPositionMs`, offset/latency có hậu tố `Ms` dùng milliseconds.
- `expiresIn`, `refreshExpiresIn` của auth dùng seconds; không nhân/chia tùy tiện giữa DTO và domain.
- `Instant` thường là ISO-8601; offline dùng chuỗi `yyyy-MM-dd HH:mm:ss` từ `LocalDateTime`.
- Chuỗi ngày không timezone chưa đủ để suy ra UTC; xác minh timezone server trước nghiệm thu expiry.
- DTO cho phép field nullable đúng nguồn; thiếu lyrics ở summary không đồng nghĩa bài không có lyrics.
- Không retry tự động mọi POST; đặc biệt checkout, tạo playlist/session và confirm download có side effect.

## 2. Response, lỗi và phân trang

Không có envelope chung `data` hoặc `data.data`; parser thuộc từng repository.

| API | Dạng response quan sát |
| --- | --- |
| Tracks | `content`, `page`, `size`, `totalElements`, `totalPages` |
| Liked library | `tracks`, `currentPage`, `pageSize`, `totalElements`, `totalPages` |
| Album list, search/emotion history | Spring Page, có `content` và metadata phân trang |
| Playlists, artists, packages | List trực tiếp |
| Notifications | `items`, `unreadCount` |
| Auth, track detail, playlist detail | Object trực tiếp |
| Một số mutation | Body rỗng 200/204 hoặc object `success` |

Các API `page/size` đang dùng page bắt đầu từ **0**; giới hạn/cap phải xem service từng API.
`ResponseStatusException` thường trả `timestamp`, `status`, `message`, `error`.
401 có thể không có body; 403 từ JWT filter có thể chỉ có `error`, `message`.
Không biến lỗi parse, 401/403, mất mạng hoặc list rỗng thành dữ liệu demo.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/config/GlobalExceptionHandler.java`;
`Backend/src/main/java/com/laphuth/moodify/dto/track/TrackPageResponse.java`;
`Backend/src/main/java/com/laphuth/moodify/dto/library/LibraryPageResponse.java`.

## 3. Auth và thiết bị

| Method | Endpoint | Contract chính |
| --- | --- | --- |
| POST | `/api/auth/login` | `identifier`, `password`; tùy chọn `deviceUuid`, `deviceName`, `platform` |
| POST | `/api/auth/register` | Theo `RegisterRequest`; không tự đổi tên field |
| POST | `/api/auth/refresh` | Body `refreshToken` |
| POST | `/api/auth/google` | Theo `GoogleAuthRequest` |
| POST | `/api/auth/google/code` | `code`, `codeVerifier`, `redirectUri`, `clientId`, device metadata |
| POST | `/api/auth/facebook` | Theo `FacebookAuthRequest` |
| POST | `/api/auth/logout` | 204; hiện chỉ clear SecurityContext server |
| GET | `/api/auth/me` | Profile hiện tại |
| POST | `/api/auth/avatar` | Multipart field **`file`** |
| GET | `/api/auth/devices` | Danh sách thiết bị |
| POST | `/api/auth/devices/register` | `deviceUuid`, `deviceName`, `platform` |
| PATCH | `/api/auth/devices/{id}/revoke` | Thu hồi thiết bị theo ID |
| POST | `/api/auth/devices/revoke-others` | Body tùy chọn `deviceUuid` hiện tại |
| GET | `/api/auth/devices/ping` | Header `X-Device-Uuid`; kiểm tra còn active |

Auth trả object phẳng: `accessToken`, `refreshToken`, `tokenType`, `expiresIn`, `refreshExpiresIn`,
`userId`, `fullName`, `email`, `username`, `role`, `status`.
JWT phân ACCESS/REFRESH; refresh kiểm tra tài khoản ACTIVE rồi cấp lại cặp token.
Chưa thấy refresh replay detection/blacklist; `/logout` không thu hồi JWT đã cấp.
Flutter xóa token secure storage và state theo tài khoản khi logout; không hứa server revoke mọi token.
Một refresh đang chạy dùng chung cho các request; chỉ retry request lỗi 401 tối đa một lần sau refresh.
403 `DEVICE_REVOKED` là trạng thái thu hồi thiết bị, không được lặp refresh.
OAuth native cần cấu hình client ID, redirect/deep link và kiểm chứng trên thiết bị mới.
Register listener dùng `fullName`, `phone`, `email`, `username`, `password`, `confirmPassword`, `role: USER`. Phone bắt buộc 8–20 ký tự theo regex DTO; username 4–50, password 6–255. Request register không có device metadata nên app đồng bộ thiết bị sau khi lưu phiên. Backend chỉ xử lý genre cho CONTENT_LEAD, không lưu lựa chọn genre từ form RN cho USER; Flutter bỏ lựa chọn không có tác dụng này.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/AuthenticationApi.java`;
`Backend/src/main/java/com/laphuth/moodify/dto/auth/`;
`Backend/src/main/java/com/laphuth/moodify/security/JwtAuthenticationFilter.java`;
`Backend/src/main/java/com/laphuth/moodify/services/AuthenticationService.java`.

## 4. Catalog, tìm kiếm và thư viện

| Method | Endpoint | Ghi chú |
| --- | --- | --- |
| GET | `/api/tracks` | `page`, `size`, `query`, `genre`, `mode` |
| GET | `/api/tracks/{id}` | Detail có lyrics; summary có thể bỏ lyrics |
| GET | `/api/artists` | `query`; có alias `/api/artist` |
| GET | `/api/artists/{artistId}` | Public profile |
| GET | `/api/artists/{artistId}/tracks` | `page`, `size` |
| GET | `/api/artists/followed`, `/api/artists/followed-ids` | Artist follow hiện có |
| POST | `/api/artists/{artistId}/follow` | Toggle; không retry mù gây đảo trạng thái hai lần |
| GET/POST | `/api/artists/{artistId}/reviews` | GET phân trang; POST theo DTO review |
| GET | `/api/albums` | `q`, `page`, `size` |
| GET | `/api/albums/{id}`, `/api/albums/favorites/me` | Detail/favorites |
| POST | `/api/albums/{id}/favorite` | Toggle; GET `/{id}/favorite/status` để đọc trạng thái |
| GET | `/api/users/me/library/tracks` | `page`, `size`; envelope riêng |
| GET | `/api/users/me/library/track-ids` | List ID bài thích |
| GET | `/api/users/me/library/tracks/{trackSpotifyId}/exists` | Trả `exists` |
| POST/DELETE | `/api/users/me/library/tracks/{trackSpotifyId}` | Thêm/bỏ bài thích |
| GET/POST | `/api/playlists` | GET public có `q`; POST tạo playlist |
| GET | `/api/playlists/me`, `/api/playlists/{id}` | Của tôi/detail có kiểm tra quyền |
| PATCH | `/api/playlists/{id}/visibility` | Query `isPublic` |
| POST | `/api/playlists/{id}/tracks` | Body `trackSpotifyId` |
| DELETE | `/api/playlists/{id}/tracks/{trackSpotifyId}`, `/api/playlists/{id}` | Bỏ bài/xóa playlist |
| GET/POST/DELETE | `/api/users/me/search-history` | GET: `page`, `size`, `type`, `q` |
| PATCH | `/api/users/me/search-history/{historyId}/selection` | Theo selection DTO |
| DELETE | `/api/users/me/search-history/{historyId}` | Xóa một mục |
| POST | `/api/emotions/predict`, `/api/emotions/recommend` | Body `text`, `strategy`, `limit` theo DTO |
| GET | `/api/emotions/history` | `page`, `size`; cần đăng nhập |

Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/`:
`TrackApi.java`, `ArtistApi.java`, `AlbumApi.java`, `UserLibraryApi.java`, `PlaylistApi.java`,
`SearchHistoryApi.java`, `EmotionApi.java`; DTO tương ứng dưới `Backend/src/main/java/com/laphuth/moodify/dto/`.

## 5. Streaming và telemetry

`GET /api/tracks/{id}/stream` có alias `/api/tracks/stream/{id}`.
Backend kiểm tra public/license; thường trả **302** tới remote audio, local fallback hỗ trợ Range/206.
Contract này không có signed streaming URL; không tự thêm cơ chế ký URL hoặc bypass quyền.
Ảnh/media có thể là absolute URL hoặc path `/uploads`, `/data`; resolve theo host đúng môi trường.
**Blocker kế thừa:** `AudioUrlResolver.resolve()` có fallback một bài cố định khi thiếu `localPath`.
Không port fallback đó. Bài thiếu nguồn phải unavailable; cần xử lý debt backend trước release liên quan.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/TrackApi.java`;
`Backend/src/main/java/com/laphuth/moodify/services/AudioUrlResolver.java`.

`POST /api/analytics/listening-session` gửi `trackId`, `eventType`, `positionMs`, `targetPositionMs`,
`sessionKey`, `source`, `sourceId`, `deviceType`, `deviceUuid`; `queueToken` nếu backend đã cấp.
Có `sessionKey` đi revenue pipeline; thiếu trường này đi fallback analytics cũ.
Event hợp lệ: `PLAY`, `RESUME`, `PAUSE`, `SEEK`, `HEARTBEAT`, `COMPLETE`, `SKIP_NEXT`,
`SKIP_PREVIOUS`, `TRACK_CHANGED`, `PLAYBACK_STOPPED`.
Gắn event với playback thật; không sinh lượt nghe từ render UI hoặc timer khi audio không chạy.
History: GET `/api/analytics/my-history` (`page`, `size`, `search`),
GET `/api/analytics/my-history/{historyId}/events`, DELETE `/api/analytics/my-history/{historyId}`.
Ads: GET `/api/ads/active`, POST `/api/ads/{id}/impression`; không tạo impression giả.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/TrafficAnalyticsApi.java`, `AdApi.java`;
`Backend/src/main/java/com/laphuth/moodify/services/RevenuePlaybackService.java`.

## 6. Gói cước, thanh toán và thông báo

- GET `/api/packages`, `/api/subscriptions/me`, `/api/subscriptions/package-quotes`.
- GET `/api/subscriptions/me/management`; POST `/api/subscriptions/me/{subscriptionId}/cancel`.
- Checkout thật: POST `/api/subscriptions/checkout`, body `packageId`.
- Poll GET `/api/subscriptions/payment-status/{orderCode}`; trạng thái PENDING/SUCCESS/CANCELLED/EXPIRED.
- Dừng polling khi terminal, hết hạn hoặc rời luồng; đồng bộ quyền bằng subscription API sau SUCCESS.
- Không tự coi mở QR, hết timer hoặc quay lại app là thanh toán thành công.
- **Cấm production gọi `/api/subscriptions/subscribe`: code tự tạo giao dịch SANDBOX/SUCCESS.**
- **Không đưa `/api/subscriptions/dev-toggle` vào consumer Flutter.**
- Webhook `/hooks/sepay-payment` chỉ dành provider→backend; mobile không giả callback hoặc giữ signing key.
- Notifications: GET `/api/notifications/me?limit=30`, POST `/api/notifications/{id}/read`, `/read-all`.
- Inbox REST không đồng nghĩa push mobile đã có; `linkUrl` web phải whitelist/map sang route native.
- Không dùng cache local làm nguồn quyết định Premium, số tiền hoặc quyền tải.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/SubscriptionApi.java`, `SepayPaymentApi.java`,
`NotificationApi.java`; `Backend/src/main/java/com/laphuth/moodify/services/SubscriptionService.java`.

## 7. Offline — thuộc phạm vi parity RN

| Method | Endpoint | Body/query |
| --- | --- | --- |
| POST | `/api/offline/request-download` | Body `trackId`, `deviceUuid`, `deviceName`, `platform` |
| POST | `/api/offline/confirm-download` | Body `downloadToken`, `fileHash`, `fileSize`, `localPath` |
| POST | `/api/offline/verify-license` | Body `deviceUuid`, list `trackIds` |
| GET | `/api/offline/my-downloads` | Query `deviceUuid` |
| DELETE | `/api/offline/remove` | Query `deviceUuid`, `trackId` |
| POST | `/api/offline/renew-all` | **Query** `deviceUuid`, không phải batch JSON |

Request response: `success`, `downloadToken`, `downloadUrl`, `encryptionKey`, `expiresAt`,
`tokenExpiresAt`, `track`, `quota` (`used`, `max`). Ticket HMAC TTL 15 phút, khác hạn license offline.
Confirm response: `success`, `message`, `trackId`. Chỉ confirm sau tải/mã hóa file thành công.
Verify thường trả `deviceActive`, `isPremium`, `subscriptionExpiresAt`, `validTrackIds`,
`expiredTrackIds`, `revokedTrackIds`, `serverTime`; nhánh device revoked có thể khác, phải đọc service.
My-downloads: `tracks`, `quota`, `isPremium`, tùy nhánh có `subscriptionExpiresAt`.
Renew-all: `success`, `renewedCount`, `newExpiresAt`, `message`.
Key/ticket không ghi log hoặc fixture. Metadata/file local phải scope user+device và dọn theo lifecycle.
Mã hóa, playback offline, hết hạn/thu hồi cần kiểm chứng native; không tự gia hạn license bằng đồng hồ máy.
Không chạy auto-create bảng offline để làm app hoạt động; schema thiếu là blocker cần trình bày.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/OfflineDownloadApi.java`;
`Backend/src/main/java/com/laphuth/moodify/dto/offline/`;
`Backend/src/main/java/com/laphuth/moodify/services/OfflineDownloadService.java`.

## 8. Karaoke solo, phòng, voice, scoring — thuộc parity RN

Solo: GET `/api/karaoke/tracks` (`page`, `size`, `query`), GET `/api/karaoke/tracks/{songId}`;
POST `/api/karaoke/tracks/{songId}/sessions`; GET `/api/karaoke/sessions/{sessionId}`.
POST `/api/karaoke/sessions/{sessionId}/score`: multipart `recording`, `recordingStartOffsetMs`,
`captureLatencyMs`, `allowOctaveShift`; POST `.../score/features` dùng JSON pitch features DTO.
Rooms base `/api/karaoke/rooms`: GET list; POST create `name`, `maxMembers` 1–6, `visibility` PUBLIC/PRIVATE.
GET `/{roomId}`; POST `/{roomId}/join` body tùy chọn `inviteCode`; POST `/leave`, `/close` theo room.
POST `/{roomId}/queue` body `trackId`; DELETE `/{roomId}/queue/{itemId}`.
POST `/{roomId}/playback/{start|pause|resume|skip}` body **`expectedVersion`** để chống cập nhật cũ.
POST `/{roomId}/voice-ticket` trả `ticket`, `websocketUrl`, `expiresAt`.
Room score: POST `/{roomId}/score-sessions/current`, POST `/{roomId}/score-sessions/{sessionId}/participants/me`,
PUT `.../{sessionId}/contribution` body `segments`, POST `.../{sessionId}/finish`, GET `.../{sessionId}`.
WebSocket state: `/api/ws/karaoke` (proxy production) hoặc `/ws/karaoke`; không token trong query.
Frame đầu có `type` subscribeRooms/subscribeRoom, `accessToken`, `deviceUuid`; subscribeRoom thêm `roomId`.
Heartbeat frame type `heartbeat`, ack `heartbeat.ack`; auth/subscription lỗi có thể đóng socket.
Voice media đi Node mediasoup với ticket; socket Spring này không truyền audio voice.
Khi reconnect lấy lại snapshot/phiên bản qua REST trước command; không suy diễn local là trạng thái phòng thật.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/KaraokeController.java`, `KaraokeRoomsApi.java`;
`Backend/src/main/java/com/laphuth/moodify/dto/karaoke/`; `Backend/supporting-services/karaoke-media/`;
`Backend/src/main/java/com/laphuth/moodify/services/KaraokeRoomWebSocketHandler.java`.

## 9. Recommendation mở rộng — backlog sau parity

GET `/api/recommendations/home`, `/playlists`, `/playlist-continuation?playlistId=…`, `/next?seedTrackId=…`;
GET `/api/me/personalized-playlists` và detail/version; POST mix refresh/copies; POST `/api/playback/queues`.
POST `/api/recommendations/events`: batch ≤50, UUID `eventId`, `eventType`, `attributionToken`, `occurredAt`.
PUT `/api/recommendations/feedback`; GET `/api/me/recommendation-preferences`.
Home có sections/items và attribution; queue trả `queueToken` theo track. Giữ token do server cấp, không tự tạo.
Đây là capability backend, chưa là giấy phép mở rộng phạm vi trước nghiệm thu chuyển đổi.
Nguồn: `Backend/src/main/java/com/laphuth/moodify/api/RecommendationApi.java`;
`Backend/src/main/java/com/laphuth/moodify/dto/recommendation/RecommendationTypes.java`.

## 10. Ghi chú tích hợp Flutter ngày 04/11/2026

- Mood recommendation giữ `matchStatus` và emotion label từ DTO; `LIMITED` không được trình bày như đã đạt ngưỡng phù hợp. `empathy` là strategy request, không phải đoạn văn cần tự sinh.
- Checkout trả ngày bắt đầu/kết thúc gói, không phải hạn QR. Status phải khớp orderCode + amount; chỉ SUCCESS mới refresh quyền. Management là nguồn khôi phục đơn pending sau khi rời màn hình; endpoint status không trả lại thông tin QR/bank để dựng checkout đã đóng.
- Notification `linkUrl` hiện hỗ trợ đường dẫn web billing `/dashboard/premium` (kể cả `?tab=manage`); Flutter chỉ map đường dẫn relative trong allowlist sang `/subscriptions`, không mở URL tùy ý.
- Offline client mới mã hóa GCM tại sandbox Flutter; server vẫn nhận hash/size sau mã hóa theo contract cũ. Intent cleanup chỉ chứa track ID và được reconcile qua DELETE `/offline/remove`; không thêm bảng hoặc gọi startup backend.
- Listening telemetry của account online dùng UUID session, event/positionMs thật tại `/analytics/listening-session`; guest/offline không gửi. Tích hợp quảng cáo/quyền phát thuộc nhánh cộng tác viên và vẫn cần kiểm chứng trước release.
