# Kế hoạch chuyển Moodify Mobile sang Flutter

Cập nhật: **04/11/2026**. Nguồn khảo sát là working tree, chưa phải bằng chứng production.
Mục tiêu đầu tiên: chuyển hành vi có thật của React Native sang Flutter dùng backend hiện có.
Sau khi nghiệm thu chuyển đổi mới mở rộng chức năng consumer từ web/backend.

## 1. Trạng thái và cách đọc bằng chứng

**M0 hoàn thành; M1, M2, M5 và M6 đang triển khai; M3, M4, M7 `NOT_STARTED`.** Karaoke solo/phòng đã có implementation Flutter; chưa nghiệm thu tích hợp hoặc thiết bị.
Đã có mã Dart, Android/iOS/web scaffold, dependency lock, analyze/test và APK debug. Bằng chứng thiết bị/API được ghi theo từng luồng trong `ai/STATE.md`.
Đánh dấu từng luồng và từng nền tảng riêng; không suy kết quả iOS từ Android.

| Nhãn | Ý nghĩa và bằng chứng tối thiểu |
| --- | --- |
| `SOURCE_OBSERVED` | Có đường dẫn source cũ và mô tả hành vi; chưa chứng minh API/thiết bị chạy được |
| `NOT_STARTED` | Chưa có implementation Flutter của module/luồng |
| `IMPLEMENTED` | Có mã Flutter và kiểm tra cục bộ tương ứng; chưa tự động đạt tích hợp |
| `API_VERIFIED` | Luồng gọi API thật trong môi trường xác định, ghi request/response đã bỏ secret và kết quả |
| `DEVICE_VERIFIED` | Chạy trên thiết bị/nền tảng cụ thể, có kết quả các tình huống quan trọng |
| `ACCEPTED` | Đạt tiêu chí đã thống nhất, bằng chứng đủ và được người dùng nghiệm thu |

`API_VERIFIED` và `DEVICE_VERIFIED` là chiều bằng chứng riêng, không thay thế nhau.
Không đổi nhãn thành đạt khi mới có screenshot, stub repository, API helper hoặc nút bấm.
Ghi blocker, phần chưa kiểm chứng và bước tiếp theo trong `docs/ai/STATE.md`.
Không hỏi phê duyệt cho thao tác triển khai thông thường đã nằm trong phạm vi được giao.

## 2. Ranh giới bắt buộc cho mọi mốc

- Không thêm/xóa bảng hoặc tự sửa schema, collection, index, constraint, auto-DDL, migration/seed/reset.
- Ưu tiên API đã có, RAM, cache TTL và file tạm theo user; không dùng cache làm nguồn quyền/giao dịch.
- Nếu thật sự cần schema mới: lập đề xuất có phương án không đổi schema, tác động, rollback và chờ người dùng đồng ý rõ ràng.
- Theo `ARCHITECTURE.md`; không tạo backend riêng, framework state song song hoặc cấu trúc khác giữa các feature.
- Production không có mock catalog/user/giá/thanh toán/điểm hát, fake success hoặc fallback sang bài cố định.
- Loading, empty, error, expired, denied và canceled phải thể hiện đúng; response cũ không ghi đè session/query mới.
- Token/key ở secure storage; logout hủy request/socket/capture, dọn state và khóa dữ liệu user cũ.
- Không tự chạy backend trong khảo sát; source cũ có đường auto-DDL cần đọc audit trước.
- Không copy toàn repo, env thật, private key, dump, dependency/build cache hoặc media catalog vào repo mới.

## 3. Ma trận chức năng cần chuyển

Đường dẫn trong cột nguồn tương đối với `Moodify-Mobile/`; xem `docs/ai/SOURCE_MAP.md` để tìm checkout.
Mỗi hàng dưới đây: source đã `SOURCE_OBSERVED`. Login/register và profile/logout cơ sở đã `IMPLEMENTED`; shell năm tab (Karaoke tab thứ năm) và karaoke solo/phòng có implementation nhưng chưa nghiệm thu; profile/subscription đầy đủ và các hàng còn lại **`NOT_STARTED`**.
Các API cụ thể và khác biệt response nằm tại `docs/reference/API_CONTRACT.md`.

| Luồng | Source RN tham chiếu | Cách chuyển và tiêu chí nghiệm thu chính |
| --- | --- | --- |
| Shell, auth-return | `src/app/_layout.tsx`, `src/app/(tabs)/_layout.tsx` | Shell 5 tab (Karaoke được người dùng yêu cầu) + detail routes; login trở về nơi yêu cầu, Back đúng, không mất ý định phát |
| Login/register | `src/app/auth.tsx`, `src/services/api.ts` | Form → auth controller/repository; server validation, token restore, lỗi credentials, không giữ password |
| Google/Facebook | `src/app/auth.tsx`, `src/constants/config.ts` | Adapter native/OAuth theo backend; đúng client/redirect/signing, hủy login an toàn; xác minh từng platform |
| Catalog/home | `src/app/(tabs)/index.tsx` | Data thật, ảnh lazy/cache, phân trang có giới hạn; refresh/error/empty rõ; không gọi dữ liệu random là cá nhân hóa |
| Album | `src/components/album/AlbumDetailModal.tsx` | Detail/favorite/play qua ID thật; lỗi favorite rollback, empty khác lỗi; queue đúng thứ tự |
| Artist đang có | `src/components/artist/ArtistDetailModal.tsx` | Hiển thị danh sách bài tìm theo artist và chia sẻ; không giả artist profile hoặc trạng thái follow |
| Search thường | `src/app/(tabs)/explore.tsx` | Debounce/cancel, phân trang, lịch sử backend; query nhanh không làm kết quả đảo thứ tự |
| Emotion recommendation | `src/app/(tabs)/explore.tsx`, `src/types/index.ts` | Giữ `empathy`, emotion/tracks/match status từ API; không dựng confidence, emotion hay bài thay thế |
| Playlist | `src/app/(tabs)/library.tsx`, `src/services/api.ts` | Xem/tạo/xóa/thêm/gỡ bài, phân biệt ID playlist và track; duplicate/permission/network có phản hồi đúng |
| Liked tracks, favorite albums | `src/app/(tabs)/library.tsx`, `src/context/PlayerContext.tsx` | Đồng bộ thật, optimistic update có rollback, list phân trang; đổi user không thấy thư viện cũ |
| Player/queue | `src/context/PlayerContext.tsx`, `src/components/player/*` | Một coordinator; stream chuẩn, play/pause/seek/next/previous/shuffle/repeat; không phát nhầm callback cũ |
| Lyrics/sleep/volume/share | `src/components/player/FullscreenPlayer.tsx` | Timed lyrics chỉ khi timestamp thật; plain lyrics hiển thị plain; timer dừng đúng; share link public hợp lệ |
| Entitlement/ad | `src/context/PlayerContext.tsx`, `src/constants/ad-audio-assets.ts` | Quyền từ backend, hành vi ad/skip theo contract; lỗi load không tự cấp Premium; asset có nguồn/quyền |
| Profile/logout | `src/app/(tabs)/profile.tsx`, `src/services/storage.ts` | Profile/subscription thật; logout dù mạng lỗi vẫn kết thúc session local, dừng media và tách cache |
| Gói/gia hạn/thanh toán | `src/components/subscription/PremiumModal.tsx` | Package/checkout/QR/status thật; Pending/Success/Expired/Failed rõ, chỉ server xác nhận hiệu lực |
| Notification | `src/components/notification/NotificationModal.tsx` | List/unread/read/all-read; rollback lỗi, không biến lỗi tải thành “không có thông báo” |
| Offline | `src/services/offline/*`, `src/context/OfflineContext.tsx` | License → tải → mã hóa → confirm → verify/play/revoke/remove; account scope, expiry, recovery và RAM được đo |
| Karaoke catalog/solo | `src/app/karaoke/index.tsx`, `src/app/karaoke/solo.tsx` | Nhạc nền/lời/session/pitch/score thật; thiếu native hoặc scoring asset thì trạng thái unsupported rõ |
| Pitch native | `modules/karaoke-pitch/android/src/main/java/expo/modules/karaokepitch/KaraokePitchModule.kt`, `src/services/karaoke-pitch-capture.ts` | Port thuật toán/bridge đã kiểm chứng; giữ grid 22050 Hz, frame 2048, hop 512 và payload server |
| Rooms/signaling | `src/app/karaoke/rooms.tsx`, `src/app/karaoke/room/[roomId].tsx`, `src/hooks/use-karaoke-room-live.ts` | Create/join/invite/queue/host controls, WS heartbeat/reconnect, expectedVersion, clock và resync thật |
| Voice/group score | `src/hooks/use-karaoke-voice.ts`, `src/hooks/use-karaoke-room-scoring.ts` | Voice-ticket, native media adapter, participant/contribution/finish; nhiều máy, mic/audio focus và cleanup đúng |

## 4. M0 — tài liệu, khảo sát và baseline

Trạng thái: **DONE cho tài liệu/source audit**, không phải app migration hoàn thành.

- Đã đặt quy tắc AI, kiến trúc, source map, audit, API reference và kế hoạch này trong repo độc lập.
- Các phát hiện source chưa được dùng để tuyên bố endpoint đang deploy hay chức năng chạy ổn.
- Đọc `AGENTS.md`, `docs/ai/CONTEXT.md`, `STATE.md` rồi chọn đúng module trước mỗi phiên.
- Duy trì context ngắn; cập nhật trạng thái hiện tại, không nối transcript vào tài liệu nền.

## 5. M1 — scaffold, môi trường, session và auth

Trạng thái Flutter: **IN_PROGRESS**. Password auth/session/profile/logout cơ sở `IMPLEMENTED`; social auth chưa bắt đầu do chưa có native OAuth config. Router hiện chỉ có auth/restore/account; shell nhạc chuyển tại M2.

- Đã có 31 test đạt, `flutter analyze` sạch; debug APK arm64 build thành công với cấu hình public production.
- Thiết bị Android đã kết nối: Samsung SM-A235F, Android 14/API 34. Kết quả kiểm tra thiết bị chi tiết và phần chưa xác minh nằm ở `ai/STATE.md`.
- Chỉ probe đọc API: catalog 200 đúng envelope, `/auth/me` không token 401. Chưa gọi đăng ký/checkout hoặc tự tạo user thật.
- iOS có scaffold/Keychain entitlements; chưa build/runtime trên macOS. Không đánh dấu toàn M1 `ACCEPTED`.

- Xác minh Flutter/Dart tại máy; tạo scaffold bằng CLI, Android trước, ghi target iOS riêng.
- Tạo app bootstrap/router/theme/config + HTTP/error/secure storage dùng chung đúng baseline.
- Base API bao gồm `/api` đúng một lần; môi trường explicit, không hardcode localhost/IP thiết bị.
- Auth flat response, metadata thiết bị/UUID thống nhất, token restore và login/register/social adapters.
- Refresh single-flight, retry 401 một lần; không refresh 403, login/refresh hoặc request thuộc session cũ.
- Nghiệm thu: khởi động chưa login, restore hợp lệ/hết hạn, nhiều 401 đồng thời, refresh lỗi, logout giữa request.
- OAuth kiểm tra cancel/redirect và signing trên thiết bị; chưa đủ config ghi blocker riêng, không giả login.
- Kết quả cần có: format/analyze, test session có ý nghĩa và API thật; ghi rõ thiết bị nào đã chạy.

## 6. M2 — core parity nghe nhạc và thư viện

Trạng thái Flutter: **IN_PROGRESS**. Đã triển khai shell 4 tab giữ trạng thái; khách duyệt/phát qua API public; catalog/filter/phân trang, album/artist detail, search thường/cảm xúc, liked tracks, tạo playlist riêng tư/thêm bài/đọc playlist, mini/full player với queue/seek/shuffle/repeat/plain lyrics. Một engine native và OS controls dùng cùng coordinator. 53 test cục bộ đạt; Android phát/pause/seek/background/OS play đã kiểm tra với nguồn thật.

Chưa hoàn tất M2: search history, favorite album, xóa bài/playlist/visibility, volume/sleep/share/synced lyrics, entitlement/ad policy và listening telemetry. Không coi player debug hiện tại là bản production đạt chính sách quảng cáo/quyền. Auth/library mutation và mood worker chưa được xác minh end-to-end bằng tài khoản thật; iOS, Bluetooth và lock-screen/interruption chưa nghiệm thu. Xem `ai/STATE.md`.

- Chuyển shell/home/catalog/album/artist-list, search thường/cảm xúc và search history.
- Chuyển playlist/liked/favorite album với server validation, rollback và phân trang.
- Chuyển player/queue/mini/fullscreen, controls, volume, sleep timer, lyrics và share.
- Dùng `/tracks/{id}/stream`; kiểm tra redirect/range/seek, codec và lỗi media thật, không dùng preview làm full track. Local backend đã ưu tiên phục vụ file local tồn tại trước khi redirect; chưa nghiệm thu runtime trên local API/thiết bị.
- Dùng một coordinator để screen/OS controls không tạo player song song; stale callback không đổi bài mới.
- Xác minh bài cuối + repeat off dừng, pause không bị retry tự phát, seek/retry không nhân bản session.
- Kiểm tra mất mạng/khôi phục, audio interruption, background/lock screen/Bluetooth trên target device.
- Emotion trả ít/không có candidate phải giữ kết quả thật; không lấp bằng random catalog.
- Nghiệm thu luồng: tìm → phát → thêm playlist → like → quay lại → logout/đổi user không lẫn dữ liệu.

## 7. M3 — gói, gia hạn, thanh toán và thông báo

Trạng thái Flutter: **NOT_STARTED**. Phụ thuộc session và playback coordinator.

- Chuyển package list, subscription hiện tại, checkout/QR và payment status polling có giới hạn.
- Gia hạn/nâng gói dùng checkout và trạng thái hiệu lực từ server; không tự cộng ngày hoặc ghi Premium local.
- Production tuyệt đối không đi qua `/subscribe` trực tiếp hoặc `/dev-toggle` để cấp quyền/thanh toán.
- Hủy/thoát app/quay lại: giữ order identity cần thiết theo user, hỏi server; không tự tạo thêm order do retry.
- Pending không đồng nghĩa failed; Success thanh toán và thời điểm gói hiệu lực là hai dữ kiện cần đọc đúng.
- Entitlement và ad behavior theo server; xác minh quyền trước/sau thanh toán, hết hạn và đổi user.
- Notification list/read/unread đồng bộ thật; không tự dựng badge count khi lỗi.
- Nghiệm thu bằng môi trường thanh toán phù hợp: thành công, pending, hết hạn, lỗi, resume và callback lặp.

## 8. M4 — tải và nghe offline

Trạng thái Flutter: **NOT_STARTED**. Spike native/file I/O có thể làm sớm.

- Đọc contract backend và MFY1 (format file local do client mã hóa); đánh giá tương thích và không quảng bá CTR hiện tại như DRM hoàn chỉnh. Không mặc định app Flutter mới truy cập được file/token trong sandbox Expo cũ.
- Manifest versioned theo user, key secure storage, file private, `.part` và rename atomically.
- Giới hạn download concurrency/size/RAM; progress từ bytes thật, không sao chép các mốc 30/60/80 giả.
- Hết hạn/thu hồi/quá quota/thiết bị bị thu hồi dùng API và trạng thái thật; không tự gia hạn theo clock client.
- Confirm thất bại và app bị kill cần reconcile có giới hạn theo contract; không tự tạo outbox nghiệp vụ mới.
- Nghiệm thu: offline hợp lệ, thiếu file/key, file hỏng, expired/revoked, storage full, kill/restart, đổi tài khoản.
- Đo bộ nhớ với bài lớn và cleanup decrypted cache đúng lifecycle; user B không phát file/secret user A.
- Chưa giải được kiểm quyền hoặc native playback thì ghi blocker release cụ thể, không âm thầm bỏ offline.

## 9. M5 — karaoke solo và pitch

Trạng thái Flutter: **IN_PROGRESS**. Port luồng `KaraokeSoloPage` trên web: khi chọn bài có `scoringAvailable`, xin quyền micro, tạo session, thu pitch features và phát nhạc; khi nhạc kết thúc, tự submit features rồi hiện điểm. Nút chính trong lúc thu dừng và hủy bản thu như web; bài thiếu scoring reference chỉ phát nhạc. Mic-check là thao tác riêng. Lời hát giữ highlight theo mốc đồng bộ có sẵn.

- Chọn bài scorable: microphone permission → session API → PCM16/YIN capture → nhạc nền → submit features khi `ProcessingState.completed` → kết quả tổng. Không upload raw audio.
- Toggle playback trong khi thu hủy session capture và dừng nhạc; seek bị khóa trong lúc thu. Mic-check dừng trước khi bắt đầu chấm.
- Bài không có scoring reference phát nhạc bình thường, không tạo session; lỗi permission/session/capture/API hiển thị trên màn hình.
- Nghiệm thu: luồng scorable/unsupported, mic denied, score thật khi bài kết thúc, hủy khi dừng/chuyển bài/rời màn, đường dẫn audio lỗi/timeout và seek state.
- iOS chưa có native đối ứng trong source cũ: ghi nhánh trạng thái riêng và kế hoạch thực hiện, không tuyên bố parity đủ.

## 10. M6 — karaoke rooms, voice và điểm nhóm

Trạng thái Flutter: **IN_PROGRESS**. Room REST, playback/lyrics sync, voice ticket + mediasoup/WebRTC signaling và contribution API đã có; cần kiểm tra nhiều thiết bị.

- Dùng room API hiện có: public/private, invite, membership, queue, host close/playback và expectedVersion.
- Room state hiện refresh bằng REST polling 4 giây; Spring WebSocket auth/device UUID, heartbeat/reconnect và stale-event handling còn thiếu.
- Voice ticket và client mediasoup/WebRTC đã được port theo backend signaling; chưa kết nối được với server thật trên thiết bị để nghiệm thu.
- Snapshot playback có resync vị trí; cần xác minh lệch đồng hồ/position, reconnect không tự bật mic hoặc phát ngoài ý định.
- Participant/contribution/finish group score đã nối endpoint; khi thu pitch, UI yêu cầu tắt mic Voice để không mở hai capturer đồng thời. Cần nghiệm thu trên thiết bị.
- Nghiệm thu trên ít nhất hai thiết bị: join/leave, host pause/resume/skip/close, private code sai, reconnect và scoring.
- Thử mic denied, Bluetooth/loa, background và rời phòng; socket/transport/capture phải được giải phóng.
- Dependency native chưa tương thích là blocker có bằng chứng và phương án, không lý do chuyển tính năng ra khỏi parity.

## 11. M7 — gate parity và chuẩn bị release

Trạng thái Flutter: **NOT_STARTED**. Chỉ xét khi M1–M6 có bằng chứng phù hợp.

- Rà từng hàng ma trận với source/audit; gán ACCEPTED theo target platform sau nghiệm thu.
- Đề cương phải được đối chiếu đủ: catalog, gói/gia hạn, thanh toán online, phát/chuyển/tua, search/cảm xúc, karaoke, offline.
- Không để một chức năng chặn bị “ẩn UI” rồi ghi migration hoàn tất; ghi blocker hoặc xin người dùng đổi phạm vi rõ ràng.
- Kiểm tra release config, không mock/dev purchase path, không secret/log nhạy cảm, asset rights và deep link thật.
- Chạy format/analyze, test nghiệp vụ rủi ro, integration phù hợp; native/audio/payment/offline có bằng chứng thiết bị.
- Rà hiệu năng list lớn, cache/quota/RAM, cold start và app lifecycle; không chỉ nghiệm thu trên catalog nhỏ trang đầu.
- Build release theo target được cấu hình; không tự push/publish/store submission ngoài yêu cầu.
- Ghi giới hạn thật và phần chưa kiểm chứng; thiết kế sạch, dễ đọc, không chip/badge/claim vô nghĩa.

## 12. E — backlog mở rộng sau chuyển đổi

Trạng thái: **DEFERRED**, chưa triển khai; chỉ mở sau parity ACCEPTED hoặc người dùng chốt đổi phạm vi rõ ràng.

- Artist profile/follow thật qua API: RN hiện chỉ toggle local; không tính follow thật là điều kiện parity RN.
- Profile edit/avatar/security/device sessions nếu consumer API đã xác minh hỗ trợ.
- Recommendation cá nhân hóa/recent listening, khám phá sâu và bộ lọc dùng taxonomy thật.
- Quality/data saver thực sự tác động media khi backend có capability; không chuyển switch local thành lời hứa lossless.
- Recording/history và phần karaoke consumer khác chỉ triển khai sau đối chiếu endpoint, quyền và yêu cầu đề cương.
- Cải tiến UX theo `DESIGN.md` có thể đi cùng migration nếu giữ hành vi/phạm vi; không thêm nút giả để lấp khoảng trống.
- Không mở rộng sang dashboard admin/moderator/artist, ingestion, billing admin hoặc database tooling.
- Mỗi mục mở rộng cần user story, API hiện có, acceptance và tác động lưu trữ; schema mới phải theo gate xin ý kiến riêng.

## 13. Cách thực hiện một lát chuyển đổi

1. Chọn một luồng nhỏ trong milestone, đọc source map/audit/contract tương ứng và kiểm tra thay đổi sẵn có.
2. Đối chiếu source/backend, ghi mismatch cụ thể; không mặc định TypeScript type là hợp đồng server cuối cùng.
3. Triển khai xuyên suốt View → controller → repository → service bằng dữ liệu thật, giữ boundary/cancel/session.
4. Kiểm tra đúng rủi ro đã thay đổi; không viết test chỉ để lặp lại implementation hoặc tạo data giả trong release.
5. Cập nhật trạng thái/bằng chứng/blocker; tiếp tục module độc lập nếu blocker không ảnh hưởng nó.
6. Chỉ mở phạm vi mới sau gate; không biến việc cần hỏi schema/kiến trúc thành approval cho mọi tác vụ thường ngày.

### M2 — quảng cáo audio Flutter (05/11/2026)

Đã tích hợp 9 file audio cục bộ người dùng cung cấp và giao diện có sử dụng artwork web; player kiểm tra subscription trước khi áp dụng NO_ADS, DAILY_QUOTA hoặc FULL_ADS, hỗ trợ bỏ qua sau 5 giây cho tier BASIC. Counter hằng ngày lưu theo thiết bị/API/user. Chưa chuyển campaign ACTIVE/impression, skip quota, trang Premium; chưa xác minh API tài khoản thật hoặc native playback. Không đánh dấu parity/release hoàn tất.

Nút nâng cấp ở quảng cáo hiện mở trang Premium web theo môi trường và cho qua quảng cáo hiện tại khi trình duyệt nhận URL. Chưa thay thế M3: web có phiên riêng; cần kiểm chứng checkout và quyền thật, đặc biệt local web/backend phải cùng môi trường.
