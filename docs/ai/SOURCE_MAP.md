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

Đã có app/core/auth và các feature home/catalog/search/library/player cho phần lõi M2; Karaoke solo/phòng đang được port và cần kiểm tra runtime. profile/subscriptions/offline vẫn là mục tiêu; không tạo file rỗng chỉ để khớp bảng.

| Mã M1 thực tế | Điểm vào |
| --- | --- |
| Bootstrap, DI, môi trường | `lib/main.dart`, `lib/app/bootstrap.dart`, `lib/core/config/app_config.dart`, `config/` |
| Router, theme | `lib/app/router/app_router.dart`, `lib/app/theme/app_theme.dart` |
| Token refresh, request theo session | `lib/core/network/session_interceptor.dart` |
| Session lifecycle và secure storage | `lib/features/auth/data/session_repository.dart`, `session_storage.dart`, `device_identity.dart` trong cùng thư mục |
| Auth contract | `lib/features/auth/data/auth_remote_service.dart`, `lib/features/auth/domain/` |
| Form, profile, controller | `lib/features/auth/presentation/` |
| Test phiên và UI | `test/core/`, `test/features/auth/`; fixture chỉ ở `test/support/` |
| Shell 5 tab (Karaoke thứ năm theo yêu cầu), route public/return sau auth | `lib/app/main_shell.dart`, `lib/app/router/app_router.dart` |
| Model, catalog API public, stream validation | `lib/features/catalog/domain/catalog_models.dart`, `lib/features/catalog/data/catalog_repository.dart` |
| Home/phân trang, album/artist detail, track actions | `lib/features/home/presentation/home_screen.dart`, `lib/features/catalog/presentation/` |
| Search debounce/cancel/mood, chưa có history | `lib/features/search/presentation/` |
| Thư viện theo user, like, playlist create/add/read | `lib/features/library/data/library_repository.dart`, `lib/features/library/presentation/` |
| Playback coordinator, một native handler, mini/full | `lib/features/player/presentation/player_controller.dart`, `player_screen.dart` cùng thư mục; `lib/features/player/data/playback_engine.dart` |
| Karaoke catalog/solo/pitch capture/fullscreen lyric player | `lib/features/karaoke/data/karaoke_repository.dart`, `pitch_capture.dart`, `lib/features/karaoke/presentation/karaoke_screen.dart` (`KaraokePerformanceScreen`), route `lib/app/router/app_router.dart` |
| Karaoke rooms, synced playback, voice/media, group scoring | `lib/features/karaoke/data/karaoke_repository.dart`, `karaoke_voice_client.dart`, `pitch_capture.dart`, `lib/features/karaoke/presentation/karaoke_screen.dart` |
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
| Account UI và inbox | `lib/features/profile/` (inbox tách feature chỉ khi phạm vi thực tế cần) |
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
