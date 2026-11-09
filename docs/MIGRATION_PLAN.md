# Kế hoạch chuyển Moodify Mobile sang Flutter

Tích hợp06/11/2026: cập nhật main06b3c27 gồm profile/checkout/karaoke/OAuth và audio ads; giữ fullscreen lyrics + splash local. LRC công khai cho mọi người dùng theo upstream, không còn gate Premium phía UI. 134tests/analyze/build đạt; APK đã cài Samsung, smoke chưa thay nghiệm thu M1–M6. Xem ai/STATE và DEVICE_REVIEW_2026-11-06.md; không sửa backend/DB trong lượt này.

Cập nhật: **04/11/2026**. Nguồn khảo sát là working tree, chưa phải bằng chứng production.
Mục tiêu đầu tiên: chuyển hành vi có thật của React Native sang Flutter dùng backend hiện có.
Sau khi nghiệm thu chuyển đổi mới mở rộng chức năng consumer từ web/backend.

## 1. Trạng thái và cách đọc bằng chứng

**M0 hoàn thành; M1–M6 đang triển khai; M7 chưa bắt đầu.** Đã merge karaoke từ `Thuan_Branch` theo yêu cầu; quảng cáo vẫn chờ cộng tác viên. Password auth/session, catalog/search/library/player, subscription/payment/inbox và offline đã có mã. Chưa nghiệm thu toàn milestone; bằng chứng tài khoản/native còn thiếu được ghi riêng trong STATE.
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
Mỗi hàng dưới đây đã `SOURCE_OBSERVED`. Shell, password auth, catalog/search/library/player và các module M3/M4 có implementation Flutter. Social OAuth còn thiếu cấu hình native; karaoke đã merge từ Thuan_Branch; quảng cáo tiếp tục thuộc nhánh cộng tác viên. Không suy trạng thái toàn bộ app từ việc đã port các màn hình.
Các API cụ thể và khác biệt response nằm tại `docs/reference/API_CONTRACT.md`.

| Luồng | Source RN tham chiếu | Cách chuyển và tiêu chí nghiệm thu chính |
| --- | --- | --- |
| Shell, auth-return | `src/app/_layout.tsx`, `src/app/(tabs)/_layout.tsx` | Shell 5 tab sau merge karaoke + detail routes; login trở về nơi yêu cầu, Back đúng, không mất ý định phát |
| Login/register | `src/app/auth.tsx`, `src/services/api.ts` | Form → auth controller/repository; server validation, token restore, lỗi credentials, không giữ password |
| Google | `src/app/auth.tsx`, `src/constants/config.ts` | Adapter native/OAuth theo backend; đúng client/redirect/signing, hủy login an toàn; xác minh từng platform. Facebook đã gỡ khỏi web/mobile/backend theo yêu cầu ngày 09/11/2026 |
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

06/11: bổ sung màn quản lý tài khoản và contract sửa họ tên/số điện thoại; cần cập nhật backend và kiểm tra trên thiết bị/tài khoản thật trước nghiệm thu.

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

Trạng thái Flutter: **IN_PROGRESS**. Đã có shell 5 tab sau merge karaoke, khách duyệt/phát qua API public, catalog/filter/phân trang, album/artist detail, search thường/cảm xúc/history, liked tracks/favorite albums, playlist create/add/remove/delete/visibility. Player có queue/seek/shuffle/repeat, volume, sleep, share metadata qua native sheet và lời đồng bộ với timestamp thật cho mọi người dùng. Một engine/OS coordinator và listening telemetry từ sự kiện native; không gửi doanh thu cho guest/offline. Home, library, account và player đã được tổ chức lại theo UX_REVIEW.

Thiết kế đã điều chỉnh lại theo source RN theo yêu cầu người dùng: quick grid/spotlight/shelves, mini-player nổi, full-player nền artwork mờ và slide-up; motion có reduced-motion và test màn nhỏ. Không thay engine hay kiến trúc.

Đợt lyrics05/11: `/lyrics` toàn màn hình từ header/preview player, backdrop/metadata/transport, highlight và follow timestamp thật, chạm câu tua, manual/recenter, plain/error/no-right/no-lyrics riêng. Giữ engine/queue khi đóng hoặc đổi màn; không bypass quyền synchronized. User yêu cầu code sửa trước, tạm thời không kết nối điện thoại; source/test/build không đồng nghĩa native synced lyrics đã nghiệm thu.

Chưa nghiệm thu M2: mutation bằng tài khoản thật, mood worker, native share/volume/sleep/synced lyrics và listening telemetry trên server thật; iOS, Bluetooth và interruption. Quảng cáo/entitlement policy do cộng tác viên tích hợp từ nhánh riêng, vẫn là gate release. Chia sẻ hiện là tên bài/nghệ sĩ; chưa có public deep link được xác minh. Xem `ai/STATE.md`.

- Chuyển shell/home/catalog/album/artist-list, search thường/cảm xúc và search history.
- Chuyển playlist/liked/favorite album với server validation, rollback và phân trang.
- Chuyển player/queue/mini/fullscreen, controls, volume, sleep timer, lyrics và share.
- Dùng `/tracks/{id}/stream`; kiểm tra redirect/range/seek, codec và lỗi media thật, không dùng preview làm full track.
- Dùng một coordinator để screen/OS controls không tạo player song song; stale callback không đổi bài mới.
- Xác minh bài cuối + repeat off dừng, pause không bị retry tự phát, seek/retry không nhân bản session.
- Kiểm tra mất mạng/khôi phục, audio interruption, background/lock screen/Bluetooth trên target device.
- Emotion trả ít/không có candidate phải giữ kết quả thật; không lấp bằng random catalog.
- Nghiệm thu luồng: tìm → phát → thêm playlist → like → quay lại → logout/đổi user không lẫn dữ liệu.

## 7. M3 — gói, gia hạn, thanh toán và thông báo

Trạng thái Flutter: **IN_PROGRESS**. Có typed current/quotes/management, xác nhận checkout, VietQR/sao chép, kiểm tra status tối đa 180 lần tự động, dừng khi nền/lỗi/thoát, chặn đơn lặp khi kết quả chưa rõ và kiểm tra đơn pending từ lịch sử. Chỉ server SUCCESS mới cập nhật quyền. Có hủy lịch/đơn và inbox read/read-all; notification billing mở route gói qua allowlist. Chưa thực hiện giao dịch thật hoặc xác minh protected API trên thiết bị.

- Chuyển package list, subscription hiện tại, checkout/QR và payment status polling có giới hạn.
- Gia hạn/nâng gói dùng checkout và trạng thái hiệu lực từ server; không tự cộng ngày hoặc ghi Premium local.
- Production tuyệt đối không đi qua `/subscribe` trực tiếp hoặc `/dev-toggle` để cấp quyền/thanh toán.
- Hủy/thoát app/quay lại: giữ order identity cần thiết theo user, hỏi server; không tự tạo thêm order do retry.
- Pending không đồng nghĩa failed; Success thanh toán và thời điểm gói hiệu lực là hai dữ kiện cần đọc đúng.
- Entitlement và ad behavior theo server; xác minh quyền trước/sau thanh toán, hết hạn và đổi user.
- Notification list/read/unread đồng bộ thật; không tự dựng badge count khi lỗi.
- Nghiệm thu bằng môi trường thanh toán phù hợp: thành công, pending, hết hạn, lỗi, resume và callback lặp.

## 8. M4 — tải và nghe offline

Trạng thái Flutter: **IN_PROGRESS**. Đợt 05/11 đã thêm phase/bytes/hủy/retry/lỗi theo bài, nút/menu tải có trạng thái và xóa local offline với cleanup quota; transfer không khóa playback, confirm mơ hồ đọc verify thật. Có tải HTTPS giới hạn 40 MiB/1 lượt, file AES-256-GCM riêng sandbox Flutter, manifest/key trong secure storage theo API+user+device, `.part`/rename, confirm/verify, expiry/revocation/renew/remove. Cleanup intent giới hạn phục hồi reservation qua DELETE hiện có; không lưu ticket hoặc tạo outbox nghiệp vụ. Có cổng phát offline dùng chung engine và mở thư viện khi restore lỗi mạng. Test filesystem/crypto đạt theo STATE; native, RAM bài lớn và tài khoản Premium chưa nghiệm thu.

- Đọc contract backend và MFY1 (format file local do client mã hóa); đánh giá tương thích và không quảng bá CTR hiện tại như DRM hoàn chỉnh. Không mặc định app Flutter mới truy cập được file/token trong sandbox Expo cũ.
- Manifest versioned theo user, key secure storage, file private, `.part` và rename atomically.
- Giới hạn download concurrency/size/RAM; progress từ bytes thật, không sao chép các mốc 30/60/80 giả.
- Hết hạn/thu hồi/quá quota/thiết bị bị thu hồi dùng API và trạng thái thật; không tự gia hạn theo clock client.
- Confirm thất bại và app bị kill cần reconcile có giới hạn theo contract; không tự tạo outbox nghiệp vụ mới.
- Nghiệm thu: offline hợp lệ, thiếu file/key, file hỏng, expired/revoked, storage full, kill/restart, đổi tài khoản.
- Đo bộ nhớ với bài lớn và cleanup decrypted cache đúng lifecycle; user B không phát file/secret user A.
- Chưa giải được kiểm quyền hoặc native playback thì ghi blocker release cụ thể, không âm thầm bỏ offline.

## 9. M5 — karaoke solo và pitch

Trạng thái: **IN_PROGRESS** sau merge `origin/Thuan_Branch` (`9b070ec`). Solo catalog/detail/lyrics, session, PCM16/YIN, realtime pitch/reference và submit kết quả đã có mã. Nhạc nền dùng adapter vào coordinator/engine chung thay cho AudioPlayer riêng của nhánh nguồn. Chưa nghiệm thu micro/chấm điểm/API thật sau merge.

- Chuyển catalog/detail/instrumental/lyrics, session và gửi pitch features để backend chấm điểm.
- Native Android cũ dùng AudioRecord + YIN; port bridge qua adapter/platform channel, kiểm tra thuật toán và thread.
- Giữ sample grid/đơn vị/offset/voiced probability đúng contract; không tự chấm điểm hay tạo score khi server lỗi.
- Điều phối audio focus với music player; capture/cancel/finalize có timeout và cleanup khi rời màn hình.
- Nghiệm thu: mic denied, capture interruption, file thiếu, session expired, hủy bài, kết thúc bài và server score thật.
- iOS chưa có native đối ứng trong source cũ: ghi nhánh trạng thái riêng và kế hoạch thực hiện, không tuyên bố parity đủ.

## 10. M6 — karaoke rooms, voice và điểm nhóm

Cập nhật 06/11: đã sửa UI hàng chờ luôn thêm bài, voice connect/retry, callback
mediasoup, mic cá nhân và volume theo thành viên. Backend/SQL bỏ unique một bài/người
được người dùng duyệt; mới chuẩn bị script, chưa áp dụng DB hoặc deploy. 146 mobile
test và 5 backend test đạt; chưa nghiệm thu native trên hai máy. Xem `ai/STATE.md`.

Trạng thái: **IN_PROGRESS** sau merge. Đã có room REST/queue/playback, voice ticket + mediasoup/WebRTC và contribution/finish score. State phòng hiện poll 4 giây; chưa có Spring WebSocket state/reconnect parity. Cần hai thiết bị để nghiệm thu; không suy kết quả runtime từ build.

- Dùng room API hiện có: public/private, invite, membership, queue, host close/playback và expectedVersion.
- WS state giữ auth frame đầu/device UUID, heartbeat/reconnect; event stale không đè snapshot version mới.
- Voice ticket và signaling/media adapter phải tương thích backend; không đoán package từ tên hoặc thay SFU.
- Đồng bộ clock/serverTime/position và resync có kiểm soát; reconnect không tự bật mic hoặc phát ngoài ý định.
- Giữ participant/contribution/finish group score; xử lý mic voice cạnh tranh mic pitch qua coordinator.
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
## Ưu tiên bổ sung 05/11/2026

Lịch sử nghe GET/phân trang/phát lại/xóa và search history cảm xúc/selection đã có source Flutter. Đây là IN_PROGRESS, cần account/API/device evidence. Giữ các module còn lại theo bảng kế hoạch, đặc biệt recommendation/attribution, social OAuth, karaoke/ads và nghiệm thu release. Chi tiết đợt tại `UX_PRIORITY_IMPLEMENTATION.md`.

Đợt continuity 05/11: đã thêm source mini-player trên detail, pending guest action xác nhận sau auth, LRC follow/recenter với trạng thái quyền rõ và enqueue/play-next/remove-upcoming. M2 vẫn IN_PROGRESS; 91tests/analyze không thay thế bằng chứng thiết bị/account. Phần còn lại xem UX_PRIORITY_IMPLEMENTATION.

Đợt artist/device và Samsung05/11: artist public profile/follow và followed-library; collection lazy/play-shuffle-share; account avatar/devices list-revoke đã có source. Guest smoke playback/queue/download auth boundary/artist/search và fix rootBack có bằng chứng máy tại DEVICE_REVIEW_2026-11-05.md. Protected API/device mutation/download thật chưa nghiệm thu; M1–M6 vẫn IN_PROGRESS.

Đợt thiết kế tải05/11: màn `/offline` mới có tác vụ ưu tiên, dung lượng local, entitlement/quota theo thiết bị và thư viện tìm/lọc/phát/xác minh/gia hạn/xóa. Preflight quyền/quota thật trước request-download, hủy trong lúc kiểm tra quyền; không coi lỗi quyền là quota0. 100tests/analyze/build đạt, đã cài và kiểm tra gói Miễn phí + gate tải đúng bài trên Samsung. M4 vẫn IN_PROGRESS: cần account có offline entitlement để nghiệm thu transfer/license/phát mất mạng/native failure, không có background durable/byte resume/multi-job queue.
