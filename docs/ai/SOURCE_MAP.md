# Bản đồ source và cách đọc theo nhu cầu

Ngày khảo sát: **04/11/2026**. Các đường dẫn là source tham chiếu, không phải thành phần được copy vào repo Flutter.

## 1. Vị trí và độ tin cậy

| Alias | Đường dẫn tương đối từ root Flutter tại máy khảo sát | Git HEAD khi khảo sát |
| --- | --- | --- |
| `Mobile/` | `../Moodify/Moodify-Mobile/` | `f182ea1` |
| `Web/` | `../Moodify/Moodify/` | `52f2ffa` |
| `Backend/` | `../Moodify/Moodify-Backend/` | `0a1d060` |
| `Proposal` | `../Yêu cầu đề tài.md` | File ngoài các repo con |
| `Taste` | `../Moodify/.agents/skills/taste-skill/SKILL.md` | Quy tắc cũ cho admin console |

Root Flutter tại máy khảo sát: `D:\Hai\study\DATN\Moodify-Flutter`. Ba repo nguồn có thay đổi chưa commit; báo cáo dựa trên **working tree**, không phải chỉ các hash trên. Khi chuyển máy, ánh xạ lại các alias theo checkout thực tế; không tải toàn repo vào Flutter hoặc coi đường dẫn máy này là dependency build.

Khi không có checkout nguồn, đọc API_CONTRACT và LEGACY_AUDIT trước. Nếu contract chưa đủ cho luồng đang làm, yêu cầu đúng controller/DTO/source cần thiết thay vì đoán endpoint hoặc tạo dữ liệu cho UI.

Ưu tiên bằng chứng: controller/DTO/service hiện tại → call site thực tế → test/runtime môi trường xác định → tài liệu cũ. TypeScript client có chỗ lệch HTTP method với controller, không lấy type/client cũ làm chuẩn duy nhất.

## 2. Từ module đến source

Đường dẫn nối với alias ở cột tương ứng. Chỉ đọc hàng liên quan nhiệm vụ.

| Luồng | Mobile | Web | Backend (trong `src/main/java/com/laphuth/moodify/` nếu không nói khác) |
| --- | --- | --- | --- |
| Shell/router | `src/app/_layout.tsx`, `src/app/(tabs)/_layout.tsx` | `app/dashboard/layout.tsx` | Không cần đọc backend để dựng shell |
| Auth/session | `src/app/auth.tsx`, `src/services/api.ts`, `src/services/storage.ts` | `lib/auth/auth-client.ts`, `lib/auth/device-helper.ts` | `api/AuthenticationApi.java`, `dto/auth/`, `security/JwtAuthenticationFilter.java`, `services/AuthenticationService.java` |
| Home/catalog | `src/app/(tabs)/index.tsx` | `features/dashboard/user/components/dashboard-user-page.tsx`, `components/dashboard/lumen-hero.tsx` | `api/TrackApi.java`, `dto/track/TrackResponse.java` |
| Album/artist | `src/components/album/AlbumDetailModal.tsx`, `src/components/artist/ArtistDetailModal.tsx` | `app/dashboard/artists/[id]/page.tsx`, `lib/api-client.ts` | `api/AlbumApi.java`, `api/ArtistApi.java` |
| Search/mood | `src/app/(tabs)/explore.tsx` | `app/dashboard/search/page.tsx`, `components/dashboard/mood-search-bar.tsx` | `api/TrackApi.java`, `api/EmotionApi.java`, `api/SearchHistoryApi.java` |
| Library/playlist | `src/app/(tabs)/library.tsx` | `app/dashboard/library/page.tsx`, `lib/api-client.ts` | `api/UserLibraryApi.java`, `api/PlaylistApi.java`, `dto/library/` |
| Playback | `src/context/PlayerContext.tsx`, `src/components/player/` | `components/dashboard/player-context.tsx`, `docs/PLAYER_PLAYBACK_AUDIT_20261029.md` | `api/TrackApi.java`, `services/AudioUrlResolver.java`, `api/TrafficAnalyticsApi.java` |
| Subscription/payment | `src/components/subscription/PremiumModal.tsx` | `lib/api-client.ts` | `api/SubscriptionApi.java`, `api/SepayPaymentApi.java`, `services/SubscriptionService.java` |
| Notifications | `src/components/notification/NotificationModal.tsx` | `lib/api-client.ts` | `api/NotificationApi.java` |
| Offline | `src/context/OfflineContext.tsx`, `src/services/offline/` | `lib/api-client.ts` | `api/OfflineDownloadApi.java`, `dto/offline/`, `services/OfflineDownloadService.java` |
| Karaoke solo/pitch | `src/app/karaoke/solo.tsx`, `src/services/karaoke-pitch-capture.ts`, `modules/karaoke-pitch/android/src/main/java/expo/modules/karaokepitch/KaraokePitchModule.kt` | `features/dashboard/karaoke/` | `api/KaraokeController.java`, `dto/karaoke/` |
| Karaoke rooms/voice | `src/app/karaoke/room/[roomId].tsx`, `src/hooks/use-karaoke-room-live.ts`, `src/hooks/use-karaoke-voice.ts`, `src/hooks/use-karaoke-room-scoring.ts` | `features/dashboard/karaoke/hooks/` | `api/KaraokeRoomsApi.java`, `services/KaraokeRoomWebSocketHandler.java`; voice ở `Backend/supporting-services/karaoke-media/` |
| Recommendation mở rộng | Không dùng home RN làm chứng cứ personalized | `lib/recommendation-client.ts`, `components/dashboard/recommendation-sections.tsx` | `api/RecommendationApi.java`, `dto/recommendation/RecommendationTypes.java` |
| UI tokens/brand | `src/constants/theme.ts`, các screen có style inline, `assets/images/` | `app/globals.css`, `public/Brand/moodify_brand_assets/tokens/colors.json` | Không cần DB/API mới cho thiết kế |

Các API mobile còn tập trung trong `Mobile/src/services/api.ts`, web trong `Web/lib/api-client.ts`; tìm symbol/endpoint và đọc đoạn cần thiết thay vì nạp cả hai file vào mỗi phiên.

## 3. Bản đồ Flutter mục tiêu

Đã có app/core/auth, home/catalog/search/library/player, subscriptions, notifications, offline và karaoke sau merge `Thuan_Branch`. Quảng cáo chưa có trong nhánh được merge; không tạo file rỗng chỉ để khớp bảng.

| Mã M1 thực tế | Điểm vào |
| --- | --- |
| Bootstrap, DI, môi trường | `lib/main.dart`, `lib/app/bootstrap.dart`, `lib/core/config/app_config.dart`, `config/` |
| Router, theme | `lib/app/router/app_router.dart`, `lib/app/theme/app_theme.dart` |
| Motion/reduced motion, nền artwork thật | `lib/core/widgets/app_motion.dart`, `lib/features/catalog/presentation/artwork_backdrop.dart`; route slide trong router |
| Token refresh, request theo session | `lib/core/network/session_interceptor.dart` |
| Session lifecycle và secure storage | `lib/features/auth/data/session_repository.dart`, `session_storage.dart`, `device_identity.dart` trong cùng thư mục |
| Auth contract | `lib/features/auth/data/auth_remote_service.dart`, `lib/features/auth/domain/` |
| Form, profile, controller | `lib/features/auth/presentation/` |
| Test phiên và UI | `test/core/`, `test/features/auth/`; fixture chỉ ở `test/support/` |
| Shell 5 tab, route public/return sau auth và karaoke session scope | `lib/app/main_shell.dart`, `lib/app/router/app_router.dart` |
| Model, catalog API public, stream validation | `lib/features/catalog/domain/catalog_models.dart`, `lib/features/catalog/data/catalog_repository.dart` |
| Home/phân trang, album/artist detail, track actions | `lib/features/home/presentation/home_screen.dart`, `lib/features/catalog/presentation/` |
| Search debounce/cancel/mood, server history theo user | `lib/features/search/presentation/`, `lib/features/search/data/search_history_repository.dart` |
| Thư viện theo user, favorite album, playlist create/add/remove/delete/visibility | `lib/features/library/data/library_repository.dart`, `lib/features/library/presentation/collection_actions.dart`, `playlist_dialog.dart` cùng thư mục |
| Playback coordinator, một native handler, mini/full | `lib/features/player/presentation/player_controller.dart`, `player_screen.dart` cùng thư mục; `lib/features/player/data/playback_engine.dart` |
| Lyrics/queue sheet, LRC, telemetry | `lib/features/player/presentation/player_sheets.dart`, `lib/features/player/domain/lyric_line.dart`, `lib/features/player/data/listening_reporter.dart` |
| Gói dịch vụ/checkout/polling | `lib/features/subscriptions/domain/subscription_models.dart`, `data/subscription_repository.dart`, `presentation/` trong feature |
| Inbox/read/read-all và billing link | `lib/features/notifications/data/notification_repository.dart`, `presentation/notification_screen.dart` trong feature |
| Download/encryption/license/cache cleanup | `lib/features/offline/data/offline_repository.dart`, `lib/features/offline/presentation/` |
| Player-offline interface và wiring | `lib/features/player/domain/offline_playback.dart`, `lib/app/bootstrap.dart`, `lib/main.dart` |
| Karaoke solo/phòng, API, voice, pitch/reference | `lib/features/karaoke/presentation/karaoke_screen.dart`, `lib/features/karaoke/data/` |
| Nhạc nền karaoke dùng chung engine, ownership token qua OS retry/restart | `lib/features/karaoke/data/karaoke_playback.dart`, `PlayerController.loadKaraoke` trong player controller |
| Test chuyển nguồn music/karaoke và guest 5 tab | `test/features/player/karaoke_playback_test.dart`, `test/features/catalog/main_shell_test.dart` |
| UX audit và native/account acceptance | `docs/UX_REVIEW.md`, `docs/ai/STATE.md` |
| Native background audio Android/iOS | `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/dev/moodify/moodify_flutter/MainActivity.kt`, `ios/Runner/Info.plist` |
| Test M2 | `test/features/catalog/`, `search/`, `library/`, `player/`; engine/repository fake chỉ ở `test/support/music_harness.dart` |

| Phần | Đường dẫn mục tiêu |
| --- | --- |
| Bootstrap/router/theme/shell | `lib/app/` |
| Config/network/error/storage trung lập | `lib/core/` |
| Session/login/register/social auth | `lib/features/auth/` |
| Catalog models/detail/albums/artists | `lib/features/catalog/` |
| Home, search, library | `lib/features/home/`, `search/`, `library/` |
| Audio coordinator/queue/telemetry | `lib/features/player/` |
| Account UI và inbox | `lib/features/auth/presentation/account_screen.dart`, `lib/features/notifications/` |
| Packages/checkout/entitlement | `lib/features/subscriptions/` |
| Download/license/files | `lib/features/offline/` |
| Solo/room/pitch/voice/scoring | `lib/features/karaoke/` |

## 4. Tìm nhanh và giữ workspace gọn

Mở riêng root Flutter. Ví dụ PowerShell, chạy từ root này:

```powershell
rg --files docs
rg -n 'refresh|DEVICE_REVOKED' docs/reference/API_CONTRACT.md
rg -n 'Mapping|Request' '../Moodify/Moodify-Backend/src/main/java/com/laphuth/moodify/api/AuthenticationApi.java'
# Chỉ dùng khi module Flutter đã tồn tại:
rg --files lib/features/auth
```

Không search ổ đĩa hoặc parent workspace bằng `--hidden --no-ignore` nếu không có lý do cụ thể. Không đọc `.env`, key, database dump hoặc export catalog để hiểu API. File generated bị loại khỏi search mặc định vẫn có thể đọc đúng đường dẫn khi chẩn đoán cần thiết; không sửa trực tiếp generated code.

`.gitignore` phục vụ Git; `.ignore` phục vụ công cụ tìm kiếm có hỗ trợ; VS Code settings phục vụ search/watcher/editor. Không giả định ba file đó cấu hình được mọi agent indexer. Source map và chọn đúng workspace là cơ chế giới hạn ngữ cảnh chính.

- Quảng cáo Flutter: `lib/features/player/data/ad_policy.dart`, `lib/features/player/data/playback_engine.dart`, `lib/features/player/presentation/player_controller.dart`, `lib/features/player/presentation/player_screen.dart`; MP3/artwork ở `assets/ads/`. Đối chiếu web `components/dashboard/player-context.tsx` và `components/dashboard/ad-interstitial-banner.tsx`.
## Bổ sung ưu tiên 05/11/2026

- Lịch sử nghe `/history`, GET/DELETE analytics và phát lại: `lib/features/player/presentation/listening_history_screen.dart`; entry Account/router. Provider theo user; dữ liệu từ server.
- Tải: `DownloadUpdate/DownloadPhase` trong offline repository, state/controller và offline screen. Transfer không chiếm serial playback; manifest writes được serialize. Xóa local + cleanup quota theo verify/download.
- Quyền/quota tải: `offline/data/offline_access_repository.dart`, GET subscriptions/me + offline/my-downloads theo deviceUuid; preflight trong OfflineController, phân biệt quota server với dung lượng bản tải local. Test `test/features/offline/offline_access_test.dart` và offline_repository_test/offline_screen_test.
- Search history/selection: `features/search/data/search_history_repository.dart`, `search_history_controller.dart`, hook explicit-submit trong search controller và `TrackTile.onSelected`.
- Kiểm thử mới: `test/features/search/search_history_test.dart`, `test/features/offline/offline_screen_test.dart` và mở rộng offline_repository_test. Bằng chứng/giới hạn tại `docs/UX_PRIORITY_IMPLEMENTATION.md`.

- Đợt continuity: `library/presentation/pending_track_action.dart` (RAM TTL/user cleanup), `continue_track_action_screen.dart` và route `/continue-action`; `PlayerController.enqueue/removeUpcoming`, `player_sheets.dart` cho queue/LRC follow; mini gắn vào detail/inbox/subscriptions. Test `test/features/player/continuity_test.dart`.

- Artist/profile/follow: `catalog/data/artist_repository.dart`, `detail_screen.dart`; followed tab ở Library. Device API/schema client: `auth/data/device_repository.dart`, `auth/presentation/device_screen.dart`, route `/devices` và entry Account. Tests `test/features/catalog/artist_device_test.dart`.
