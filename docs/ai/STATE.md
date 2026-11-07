# Trạng thái hiện tại

## Offline taste-skill + animation đồng bộ, push nhánh Duy_Branch — 07/11/2026

- Thiết kế lại `/offline` theo kỷ luật taste-skill (D42) và đồng bộ animation load/chuyển trang bằng `_slidePage` + `SectionEntrance` (D43) cho Search/Library/Account/Detail/Karaoke/Notifications/Devices/History/Profile; thêm `run.bat` Flutter (D44).
- Tích hợp trên base remote `85ed191` (Studio Dark + karaoke queue + splash, từ origin/main 07/11): bản cục bộ trước đó là snapshot main 06/11 không có git history. Xử lý bằng reset về remote rồi re-apply delta: 3 file chỉ mình có (offline_screen, notification_screen, run.bat) lấy nguyên; 9 lib + 2 docs trùng thay đổi → lấy bản remote mới rồi chèn lại wrapper/import/routes của mình. Không force-push, không mất commit remote. Số quyết định đổi D38/D39 → D42/D43 vì remote đã dùng D38–D41.
- Kiểm chứng trên Windows (Flutter 3.41.6 local `C:\flutter`, chưa có Android SDK/JDK 21 — gate chạy thiết bị còn dang dở): format + analyze + test được chạy sau khi gộp, kết quả ghi ở phần dưới của mục này. Việc cài Android SDK CLI + JDK 21 để chạy lên điện thoại đã bắt đầu nhưng người dùng tạm dừng chuyển sang push GitHub; cmdline-tools đã tải về `TEMP`, JDK 21 tải lỗi cần tải lại.

## Khởi tạo và kiểm chứng toolchain macOS/iOS Simulator & Fix lỗi biên dịch Cupertino Transitions — 07/11/2026

- **Khởi tạo và kiểm chứng môi trường iOS trên macOS**:
  1. Cấu hình toolchain Flutter 3.47 trên macOS Apple Silicon (M1), Xcode 27.2 và CocoaPods 1.17.
  2. Bổ sung `import 'package:flutter/cupertino.dart';` tại `lib/app/theme/app_theme.dart` khắc phục lỗi thiếu `CupertinoPageTransitionsBuilder` khi build iOS và chạy analyzer.
  3. Cập nhật `IPHONEOS_DEPLOYMENT_TARGET = 15.0` và tích hợp Swift Package Manager trong `ios/Runner.xcodeproj`.
  4. Biên dịch thành công `build/ios/iphonesimulator/Runner.app` và khởi chạy kiểm chứng hiển thị đầy đủ catalog production trên iOS Simulator (iPhone 11 / iPhone 17).
- **Kiểm chứng**:
  - `flutter analyze`: **No issues found**.
  - `flutter build ios --simulator --dart-define-from-file=config/production.json`: **Build succeeded**.

## Sửa hàng chờ và mic phòng karaoke — 06/11/2026

- Người dùng yêu cầu mobile thêm nhiều bài/người, điều chỉnh âm lượng thành viên
  và bật/tắt mic cá nhân. Đã đối chiếu web/backend local: đều còn quy tắc một bài/người.
- Sau khi giải thích tác động schema, người dùng đồng ý sửa và yêu cầu CREATE TABLE
  để tự dán vào MySQL sau này. Chỉ chuẩn bị SQL; chưa chạy DDL, chưa khởi động backend,
  chưa deploy, không sửa/xóa dữ liệu DB.
- Backend bỏ giới hạn một mục/người; vẫn kiểm tra membership, khóa row phòng,
  xác thực track thật và chặn cùng người thêm trùng cùng bài đang chờ. Không đặt
  giới hạn số bài/người. Mobile luôn hiện Thêm bài, chặn thao tác thêm song song,
  xóa từng bài; chủ phòng có thể xóa bài của thành viên theo quyền API hiện có.
- Khởi tạo voice sau create/join qua provider factory; sửa callback mediasoup theo
  Map callback/errback của package đã khóa, trả producer ID dạng string. Có trạng thái
  kết nối/thử lại, nút mic cá nhân, đợi producer sẵn sàng, dừng track thật khi mute/leave.
- Chạm avatar thành viên để chỉnh mức âm lượng nghe trên thiết bị mình; lưu mức
  âm lượng trong RAM ngay cả khi thành viên chưa bật mic và áp dụng cho producer mới.
  Không bật/tắt mic từ xa trên thiết bị người khác.
- Mic voice và pitch không được chiếm phần cứng đồng thời: dừng/chốt capture trước
  khi truyền voice; tắt mic cũng ngăn auto-capture bật lại. UI nêu rõ khi chấm điểm
  mic tạm dừng vì đang truyền voice. Không coi đây là nghiệm thu voice + scoring đồng thời.
- SQL: `E:/moodify-backend/database/allow_multiple_karaoke_queue_items.sql` cho bảng
  hiện có; `create_karaoke_room_queue.sql` chứa đầy đủ CREATE TABLE cho DB mới.
  Database cũ phải đổi index và triển khai backend mới thì tính năng nhiều bài mới hoạt động.
- Kiểm chứng: Flutter analyze sạch; toàn bộ 146 test mobile đạt (có test của thay đổi
  chấm điểm đang có trong working tree); 5 unit test backend queue/catalog đạt, dùng mock,
  không chạy Spring context/DB. 12 test room + voice bao gồm thêm hai bài liên tiếp,
  xóa riêng bài, mic on/off, retry và volume trước khi có producer.
- Thiết bị: ADB chỉ thấy `emulator-5554`, chưa có hai điện thoại để nghiệm thu voice,
  quyền mic, tai nghe/Bluetooth và vòng đời native. APK profile ARM64 production build
  đạt: `flutter build apk --no-pub --profile --target-platform android-arm64
  --dart-define-from-file=config/production.json`, 77.2 MB, Gradle 170.4 giây.
  Kotlin báo cache khác ổ C/E nhưng fallback build hoàn tất exit 0. Chưa cài APK lên máy thật.

## Tối ưu trình phát nhạc: Lược bỏ thanh âm lượng, thêm Nghệ sĩ kèm nút Theo dõi, Chức năng Chia sẻ bài hát & Trích dẫn lời (Lyric Card) theo chuẩn Spotify/Web & Ràng buộc bài hát không có lời — 06/11/2026

- Theo yêu cầu mới nhất từ người dùng:
  1. **Lược bỏ thanh tăng giảm âm lượng trên Player (`lib/features/player/presentation/player_screen.dart`)**:
     - Loại bỏ toàn bộ hàng thanh trượt âm lượng và nút mute/unmute trên `PlayerScreen`. Nhường quyền điều khiển âm lượng cho phím cứng vật lý và thanh âm lượng chuẩn của hệ điều hành Android/iOS, giúp giao diện thoáng đãng, tập trung vào điều khiển phát nhạc và hiển thị hình ảnh/lời bài hát.
  2. **Thêm phần Nghệ sĩ kèm nút Theo dõi trực tiếp (`_PlayerArtistSection` trong `lib/features/player/presentation/player_screen.dart`)**:
     - Tích hợp thẻ nghệ sĩ studio dark trong khu vực đồng hành bên dưới trình phát: hiển thị ảnh đại diện nghệ sĩ tròn (`MusicArtwork`), tên nghệ sĩ, số lượng người theo dõi kết nối qua `artistProfileProvider`.
     - Tích hợp nút **`Theo dõi`** / **`Đang theo dõi`** thời gian thực (`artistFollowActionProvider`): nút tự động cập nhật trạng thái với hiệu ứng viên thuốc studio tương phản cao, hỗ trợ kiểm tra đăng nhập (chuyển hướng đăng nhập nếu là khách) và chạm vào nghệ sĩ để chuyển thẳng sang `/artist/{id}`.
  3. **Chức năng Chia sẻ toàn diện như Web & Spotify (`lib/features/player/presentation/track_share_sheet.dart`)**:
     - Xây dựng modal chia sẻ chuyên nghiệp `showShareTrackSheet` hỗ trợ 2 chế độ:
       - **Thẻ bài hát**: Thẻ preview Studio Dark đồng bộ bảng màu ảnh bìa bài hát (`ArtworkPaletteBuilder`), mã âm số Moodify, tên bài, nghệ sĩ và liên kết web. Cung cấp 2 hành động: **Sao chép link** và **Chia sẻ bài hát** qua hệ thống `SharePlus`.
       - **Trích dẫn lời (Lyric Card)**: Thẻ preview trích dẫn lời chuẩn Spotify/Web với dấu ngoặc kép nghệ thuật `“`, chữ in đậm sắc nét, kèm danh sách câu lời để người dùng chạm chọn 1–3 câu lời tâm đắc muốn trích dẫn. Cung cấp 2 hành động: **Sao chép lời** (kèm trích nguồn bài hát & link) và **Chia sẻ trích dẫn**.
  4. **Ràng buộc chặt chẽ cho các bài hát không có lời (Bản hòa tấu / Chưa có lyric)**:
     - Trên `_PlayerHeroPager`: Nếu bài hát không có lời (`lines.isEmpty && plain.isEmpty`), khóa vuốt ngang sang trang lời (`NeverScrollableScrollPhysics`), ẩn hoàn toàn chú thích nảy `_BouncingLyricsHint` (không gây hiểu nhầm cho người dùng), và thanh chế độ bên dưới hiển thị nhãn thanh lịch: **`Bản hòa tấu · Không có lời`**.
     - Trên `_TrackShareSheet`: Tab "Trích dẫn lời" tự động đổi thành `Không có lời` và bị vô hiệu hóa kèm thông báo giải thích rõ ràng nếu người dùng chạm vào.
  5. **Tuân thủ triệt để `taste-skill` (Anti-Slop / Studio Dark)**:
     - Giữ vững bảng màu Studio Dark (`#090A0D`, `#10131B`), chuyển động mượt mà với `AppMotion` / `Curves.easeOutCubic`, loại bỏ hoàn toàn các chip/badge ngẫu nhiên thừa thãi, tối ưu tỷ lệ và độ tương phản.
- **Kiểm chứng**:
  - `dart format --output=none --set-exit-if-changed lib test`: **109 files, 0 changed**.
  - `flutter analyze --no-pub`: **No issues found**.
  - `flutter test --no-pub`: **134/134 tests passed**.
  - `flutter build apk --no-pub --profile --target-platform android-arm64 --dart-define-from-file=config/production.json` (`88.0MB`), cài đặt (`adb -s R58TC0KWATX install -r`) và khởi chạy trên Samsung SM-A235F (`dev.moodify.moodify_flutter/.MainActivity`): **Thành công**.

- Theo phản hồi kèm 3 ảnh chụp màn hình từ thiết bị Samsung SM-A235F của người dùng:
  1. **Giãn khoảng cách các mục chọn trong Bottom Sheet (`lib/features/catalog/presentation/catalog_widgets.dart`)**:
     - Thay thế các dòng `ListTile(dense: true)` sát nhau bằng các thẻ nút độc lập (`Material` màu `#141720`, bo góc `14px`, viền mảnh `#1AFFFFFF`, khoảng cách dọc `8px` giữa mỗi mục và `10px` giữa hai nhóm hành động, hộp icon `38×38` kèm mũi tên phụ), giúp từng mục chọn tách bạch, thoáng và dễ chạm.
  2. **Truyền đầy đủ ảnh bìa, màu sắc và icon chuẩn lên Thanh phát ngầm hệ thống Android (`lib/features/player/data/playback_engine.dart`, `lib/features/player/presentation/player_controller.dart`, `android/app/src/main/res/drawable/ic_stat_moodify.xml`)**:
     - Truyền `artUri` đã phân giải đầy đủ (`https://...`) vào `MediaItem` trong `_NativePlaybackEngine.load` và bật `preloadArtwork: true` trong `AudioServiceConfig`. Nhờ đó Android 11–14 / Samsung One UI hiển thị đúng ảnh bìa bài hát trên thanh phát ngầm và tự động trích xuất bảng màu chủ đạo từ ảnh bìa cho nền thông báo cũng như thanh sóng tiến trình.
     - Tạo vector drawable đơn sắc `@drawable/ic_stat_moodify` (sóng chữ `M` + cột nhạc trắng trên nền trong suốt) làm `androidNotificationIcon`, khắc phục triệt để lỗi ô vuông trắng đặc cạnh dòng `"Điện thoại này"`.
     - Loại bỏ `MediaControl.stop` (vốn hiển thị thành một khối vuông trắng lớn bên trái nút Previous trên thông báo mở rộng), giữ bộ 3 nút điều khiển chuẩn (`Previous`, `Play/Pause`, `Next`) cùng `MediaAction.seek`.
  3. **Nền biến thiên động theo màu chủ đạo của ảnh bài hát (`ArtworkPaletteBuilder` & `ArtworkBackdrop` trong `lib/features/catalog/presentation/artwork_backdrop.dart`)**:
     - Xây dựng bộ trích xuất màu chủ đạo trực tiếp từ ảnh bìa (`36×36` RGBA qua `ImageStreamListener`, phân nhóm 12 dải sắc độ Hue trọng số theo độ bão hòa & độ sáng, có bộ nhớ đệm LRU 64 ảnh) tạo ra 4 sắc độ đồng bộ: `dominant`, `deep`, `accent`, `miniPlayer`.
     - Áp dụng chuyển màu mượt (`AnimatedContainer` / `LinearGradient`) cho nền `PlayerScreen`, `LyricsScreen`, `CollectionScreen`, `ArtistScreen`, thanh `MiniPlayer` và quầng sáng đỉnh trang `HomeScreen`.
  4. **Tăng độ rõ nét của toàn bộ nút điều khiển (`lib/features/player/presentation/player_screen.dart`, `lib/features/player/presentation/lyrics_screen.dart`)**:
     - Các nút trên thanh tiêu đề (`Thu nhỏ`, `Mở lời bài hát`, `Hẹn giờ ngủ`, `Tùy chọn`) và hàng điều khiển phát nhạc (`Trộn bài`, `Bài trước`, `Phát/Tạm dừng`, `Bài tiếp theo`, `Lặp lại`, `Tải xuống`, `Yêu thích`, `Chia sẻ`, `Hàng đợi`, `Dừng phát`) đều có khung kính mờ tương phản cao (`#1FFFFFFF`–`#24FFFFFF`) kèm viền sáng `#28FFFFFF`–`#33FFFFFF` và icon trắng sắc nét, nổi bật rõ trên mọi tông nền ảnh bìa.
  5. **Màn hình xem lời tự động thu gọn khi vuốt ngang trên Player + Chú thích nảy định kỳ & Thẻ Tiếp theo / Nghệ sĩ ở cuối trang (`_PlayerHeroPager`, `_BouncingLyricsHint`, `_CompactSwipeLyricsCard`, `_PlayerCompanionCard` trong `lib/features/player/presentation/player_screen.dart`)**:
     - Khu vực chính trên `PlayerScreen` tích hợp `PageView` 2 trang kèm thanh chuyển đổi nhanh (`Đĩa nhạc` | `Lời tự động`, đổi nhãn từ `Ảnh bìa` sang `Đĩa nhạc`):
       - **Trang 0 (Đĩa nhạc)**: Hiển thị đĩa/ảnh bài hát kèm chú thích nhỏ `"Vuốt sang để xem lời"` có hiệu ứng nảy đàn hồi (`Curves.elasticOut`) xuất hiện định kỳ để hướng dẫn người dùng vuốt sang trái (hoặc chạm trực tiếp vào chú thích) để mở khung lời.
       - **Trang 1 (Lời tự động thu gọn)**: Khắc phục triệt để lỗi tự cuộn về giữa bằng cách đo chính xác chiều cao từng câu lời (`TextPainter` + `itemExtentBuilder` + `AutomaticKeepAliveClientMixin`) và căn tâm câu đang phát vào đúng chính giữa khung nhìn (`verticalPad + _offsets[active] + _heights[active] / 2 - box.maxHeight / 2`), kèm nút `"Về câu đang phát"` khi người dùng cuộn tay và nút `"Phóng to"` mở toàn màn hình `/lyrics`.
     - Thay thế thẻ `_LyricsPreview` bị trùng lặp ở phần dưới `PlayerScreen` bằng thẻ **`_PlayerCompanionCard`** đồng bộ màu ảnh bài hát: hiển thị danh sách **Tiếp theo trong danh sách** (`Bài x/y`, tối đa 2 bài sắp phát có thể chạm để phát ngay) cùng thông tin **Nghệ sĩ trình bày** và các nút thao tác nhanh (`Thêm vào playlist`, `Xem nghệ sĩ`, `Mở hàng đợi`).
- **Kiểm chứng**:
  - `dart format --output=none --set-exit-if-changed lib test`: **108 files, 0 changed**.
  - `flutter analyze --no-pub`: **No issues found**.
  - `flutter test --no-pub`: **134/134 tests passed**.
  - `flutter build apk --no-pub --profile --target-platform android-arm64 --dart-define-from-file=config/production.json` (`87.8MB`), cài đặt (`adb -s R58TC0KWATX install -r`) và khởi chạy trên Samsung SM-A235F (`dev.moodify.moodify_flutter/.MainActivity`): **Thành công**.

## Hoàn thiện 5 giai đoạn nâng cấp giao diện Studio Dark trên toàn bộ màn hình chi tiết & thư viện — 06/11/2026

- Triển khai đầy đủ 5 giai đoạn trong kế hoạch nâng cấp giao diện (`ui_improvement_plan.md`) theo chuẩn `taste-skill` (Studio Dark / Anti-Slop), đồng thời giữ nguyên 100% logo mark, launcher icon và hiệu ứng splash:
  - **Giai đoạn 1 — Màn hình Chi tiết Album / Playlist & Nghệ sĩ (`lib/features/catalog/presentation/detail_screen.dart`)**:
    - Tích hợp `ArtworkBackdrop` ở phần đầu màn hình và bóng đổ sâu quanh ảnh bìa.
    - Thay thế 3 nút xếp chồng dọc (`Phát`, `Trộn bài`, `Chia sẻ`) bằng thanh Studio Action Bar ngang cân đối (`Wrap`): nút `Phát` dạng viên thuốc trắng chữ đen tương phản cao, đi cùng nút `Trộn bài` và `Chia sẻ` dạng viên thuốc studio glass có viền mảnh.
    - Bọc phần tiểu sử nghệ sĩ vào thẻ studio `AppColors.surfaceRaised` và bọc từng album của nghệ sĩ vào thẻ studio `#12141A` bo góc `16px` kèm viền hairline.
  - **Giai đoạn 2 — Màn hình Thư viện & Đang theo dõi (`lib/features/library/presentation/library_screen.dart`)**:
    - Bọc các mục Playlist, Album đã lưu và Nghệ sĩ đang theo dõi (`FollowedArtistsView`) vào thẻ studio `#12141A` bo góc `16px` kèm viền mảnh `#10FFFFFF`, thay thế cho `ListTile` thô.
    - Nâng cấp thanh hành động ở tab Yêu thích (`Phát danh sách` + `Trộn bài`) sang cặp nút viên thuốc studio tương phản cao.
    - Đóng khung các trạng thái trống (`_Empty`) trong khung studio `AppColors.surfaceRaised` bo góc `24px` kèm hộp icon `64×64`.
  - **Giai đoạn 3 — Modal Bottom Sheet (`_TrackOptionsSheet`, `_QueueSheet`, `showSleepTimer`) & `TrackTile` (`lib/features/catalog/presentation/catalog_widgets.dart`, `lib/features/player/presentation/player_sheets.dart`)**:
    - Gom các mục tuỳ chọn bài hát trong `_TrackOptionsSheet` vào 2 khối thẻ studio `#111318` bo góc `18px` với hộp icon `34×34` bo góc `10px` (`isScrollControlled: true`), loại bỏ màu tím `AppColors.lavender` còn sót ở `TrackTile`.
    - Bọc từng bài trong hàng đợi (`_QueueSheet`) và từng mốc hẹn giờ tắt nhạc (`showSleepTimer`) thành thẻ studio độc lập (`#12141A`, đang phát/chọn `#1C2029` kèm viền sáng).
  - **Giai đoạn 4 — Lịch sử nghe nhạc & Quản lý thiết bị (`lib/features/player/presentation/listening_history_screen.dart`, `lib/features/auth/presentation/device_screen.dart`)**:
    - Bọc mỗi mục lịch sử nghe nhạc vào thẻ studio `#12141A` bo góc `16px` và thiết kế lại thanh phân trang dạng viên nang studio.
    - Thêm thẻ tóm tắt hạn mức thiết bị kèm thanh tiến trình trực quan (`LinearProgressIndicator`) ở đầu màn `DeviceScreen` và bọc mỗi thiết bị vào thẻ studio (`#1A1E27` cho thiết bị hiện tại, `#12141A` cho thiết bị khác).
  - **Giai đoạn 5 — Màn hình Đăng nhập / Đăng ký (`lib/features/auth/presentation/auth_screen.dart`)**:
    - Thay thanh nhấn gradient tím–hồng bằng thanh chỉ báo trắng tối giản, đổi toàn bộ màu nhãn/hint/icon/nền ô nhập từ tông tím cũ (`#DDDCE6`, `#85838F`, `#AAA3C0`, `#15141E`) sang hệ màu Studio Dark (`AppColors.text`, `AppColors.secondary`, `AppColors.surfaceRaised`), và nâng cấp nút chính sang nền trắng chữ đen tương phản cao.
- **Kiểm chứng**:
  - `dart format --output=none --set-exit-if-changed lib test`: **108 files, 0 changed**.
  - `flutter analyze --no-pub`: **No issues found**.
  - `flutter test --no-pub`: **134/134 tests passed**.
  - `flutter build apk --no-pub --profile --target-platform android-arm64 --dart-define-from-file=config/production.json` (`87.8MB`), cài đặt (`adb -s R58TC0KWATX install -r`) và khởi chạy trên Samsung SM-A235F (`dev.moodify.moodify_flutter/.MainActivity`): **Thành công**.
  - `flutter build apk --no-pub --profile --target-platform android-arm64 --dart-define-from-file=config/production.json`: **Built `build\app\outputs\flutter-apk\app-profile.apk` (87.8MB, Gradle 178.4s)**.
  - Cài đặt và khởi chạy trên Samsung SM-A235F (`R58TC0KWATX`): `adb install -r` **Success**, `am start -n dev.moodify.moodify_flutter/.MainActivity` **Success**.

## Thiết kế lại giao diện chuyên nghiệp theo taste-skill (loại bỏ màu tím, chuyển Studio Dark) — 06/11/2026

- Theo yêu cầu của người dùng về việc giao diện trước đó mang phong cách generic AI, quá nhiều nền tím và gradient tím:
  - **Áp dụng bộ tiêu chuẩn taste-skill (Anti-Slop / Dark Studio)**:
    - **Bảng màu trung tính Obsidian / Studio Dark (`lib/app/theme/app_theme.dart`)**:
      - `AppColors.background`: `0xFF090A0D` (đen studio sâu, trung tính, không ánh tím, tối ưu màn hình OLED).
      - `AppColors.surface`: `0xFF111318` (bề mặt tối trung tính).
      - `AppColors.surfaceRaised`: `0xFF171A21` (thẻ module nổi bật, sạch sẽ).
      - `AppColors.surfaceGlass`: `0xFF1E222B` (bề mặt tương tác / modal sheet).
      - `AppColors.border`: `0x1FFFFFFF` (viền hairline mảnh 12% trắng), `AppColors.borderSoft`: `0x12FFFFFF` (viền mảnh 7% trắng).
      - `android/app/src/main/res/values/colors.xml`: `launch_background` đổi sang `#090A0D` đồng bộ hoàn toàn với nền khởi động Flutter.
  - **Giữ nguyên Logo & Animation theo đúng yêu cầu**:
    - Giữ nguyên toàn bộ logo mark chính thức (`assets/brand/moodify-mark.png`), icon ứng dụng chuẩn launcher bo tròn squircle, hiệu ứng vẽ sóng chữ `M` động pre-splash và vòng lặp `BrandSplashHero`.
  - **Loại bỏ toàn bộ gradient tím và viền tím AI trên toàn bộ màn hình**:
    - `BrandLockup` (`lib/core/widgets/brand_lockup.dart`): Bỏ gradient tím và viền tím lòe loẹt, chuyển sang capsule studio đen graphite sang trọng `0xFF14161D` với viền hairline trắng tinh xảo; bỏ ShaderMask tím trên chữ `Moodify`, dùng chữ trắng sắc nét.
    - `HomeScreen` (`lib/features/home/presentation/home_screen.dart`): Chip thể loại bỏ gradient tím, chuyển sang pill studio tương phản cao (chọn: `0xFF242833` viền trắng mảnh `0x3DFFFFFF`, chữ trắng đậm; chưa chọn: `0xFF13151B` chữ `AppColors.secondary`); thẻ `_QuickTrack` dùng nền studio sạch `0xFF13151B` / active `0xFF1E222C`; `_Spotlight` dùng viền hairline mờ và badge `TÂM ĐIỂM` tối giản; `SectionHeading` dùng thanh chỉ báo trắng tối giản thay cho gradient cầu vồng tím-hồng.
    - `TrackTile` (`lib/features/catalog/presentation/catalog_widgets.dart`): Bỏ màu nền tím đậm `0xFF231C38` và viền tím sáng `0xFF5A3FD6`. Đổi sang thẻ studio `0xFF12141A` (active: `0xFF1C2029` kèm viền hairline `0x38FFFFFF` và badge sóng nhạc).
    - `NavigationBar` & `MainShell` (`lib/app/main_shell.dart`): Nền thanh điều hướng đổi sang `0xFF0C0D11`, chỉ báo chọn dạng viên thuốc `0xFF222631` với icon trắng nổi bật, nhãn tinh gọn.
    - `MiniPlayer` (`lib/features/player/presentation/player_screen.dart`): Bỏ gradient tím, chuyển thành viên nang studio nổi `0xFF151821` với viền hairline `0x28FFFFFF` và bóng đổ sâu `0x60000000`.
    - `LibraryScreen` & `SearchScreen`: Bỏ gradient tím ở TabBar indicator và công tắc chế độ tìm kiếm, chuyển sang viên thuốc studio `0xFF222631` kèm viền hairline.
    - `AccountScreen`, `KaraokeScreen`, `SubscriptionScreen`, `LyricsScreen`: Toàn bộ các hộp icon tím `0xFF251E3B`, `0xFF35264E`, backdrop tím `0xCC21163B` đã được thay thế bằng bề mặt studio dark trung tính.
- **Kiểm chứng**:
  - `dart format lib test`: **108 files, 0 changed**.
  - `flutter analyze --no-pub`: **No issues found**.
  - `flutter test --no-pub`: **134/134 unit & continuity tests passed**.
  - `flutter build apk --no-pub --profile --target-platform android-arm64 --dart-define-from-file=config/production.json`: **Built `build\app\outputs\flutter-apk\app-profile.apk` (87.8MB, Gradle 74.4s)**.
  - Cài đặt lên Samsung SM-A235F (`R58TC0KWATX`): `adb install -r` **Success**.

## Cập nhật GitHub và tích hợp local — 06/11/2026

- Theo yêu cầu lấy code mới và chạy trên máy, đã fetch và fast-forward `main` từ a456a11 tới `origin/main` **06b3c27** (4 commit mới). Không push/commit mới. Stash `pre-update-20261106-preserve-lyrics-splash` giữ bản gốc thay đổi chưa commit, đã apply và xử lý xung đột; không drop bản sao này.
- Giữ splash/native launch + lyrics toàn màn hình local, kết hợp thay đổi upstream profile/checkout/karaoke/ads/OAuth/root modal sheets. Lyrics theo quyết định mới của upstream: LRC cho mọi người dùng, kể cả khách, không gọi subscriptions để mở lời. Parse cả lyricsSynced hoặc lyricsPlain nếu thực sự có timestamp; lời thường vẫn tĩnh. Không khôi phục gate Premium cũ của màn local. Các mục gate lyrics cũ bên dưới là snapshot trước đợt này.
- Màn lyrics không highlight/seek cue nhạc đang chờ trong thời gian quảng cáo; seek/previous/next bị khóa, play/pause vẫn đi qua coordinator. Giữ `showAppModalSheet` root navigator cho queue/sleep và các sheet mới. Không đổi backend/catalog/DB.
- Dependencies `flutter pub get` đạt; **134tests passed**, analyze cuối **No issues found**, APK debug arm64 production-config **PASS** (Gradle117,4s). Build có Kotlin incremental cache fallback khác ổ C:/D: nhưng hoàn tất; không đổi Gradle để né cảnh báo. Format108files (chuẩn hóa8file upstream), kiểm tra format cuối0changed và diff check sạch.
- Samsung SM-A235F/R58TC0KWATX nhận ADB; install-rSuccess, package lastUpdateTime **06/11/2026 09:17:59**, mở Home/catalog thật. `am start -W` báo timeout/LaunchState UNKNOWN, nhưng đã thấy UI app qua screenshot/XML; chưa dùng lần mở này làm số đo startup performance. Kiểm tra tương tác đang tiếp tục; báo cáo tại `../DEVICE_REVIEW_2026-11-06.md`.

## Phân lớp hiển thị: bottom sheet đè lên chrome — 06/11/2026

- Theo yêu cầu sửa sheet bị mini player/thanh điều hướng chồng lên: tạo `showAppModalSheet` tại `lib/core/widgets/app_sheets.dart` khoá `useRootNavigator: true` kèm bảng phân lớp trong doc comment, và chuyển toàn bộ 8 call site `showModalBottomSheet` (catalog: tuỳ chọn bài hát + chọn playlist; player: queue/lyrics/sleep timer; karaoke: chọn bài + volume thành viên; thông báo). Sheet giờ luôn trượt trên chrome kèm scrim toàn màn hình; quyết định ghi ở D33.
- Kiểm chứng: Flutter analyze sạch toàn `lib`; chưa build/chạy trên thiết bị để nghiệm thu tương tác sheet với mini player.

## Lời đồng bộ cho mọi người dùng — 06/11/2026

- Theo yêu cầu, player và lời xem trước không còn kiểm tra gói dịch vụ để hiển thị lời đồng bộ; kể cả khách có thể xem khi bài có LRC thật. Đã bỏ lời đồng bộ khỏi danh sách quyền lợi VIP. Bài thiếu timestamp vẫn chỉ hiện lời tĩnh, không suy đoán thời gian.
- Kiểm chứng: Flutter analyze sạch, 4 test continuity đạt, gồm tô dòng theo vị trí mà không cần provider kiểm tra gói; chưa kiểm tra trên thiết bị thật.

## Quản lý tài khoản và trang chủ — 06/11/2026

- Tách `/profile` khỏi màn tổng quan Tài khoản; chỉnh họ tên/số điện thoại qua `PATCH /api/auth/me`, email/tên đăng nhập chỉ xem. API mới dùng các cột sẵn có, chưa triển khai backend hay nghiệm thu tài khoản thật.
- Làm mới tổng quan tài khoản và thẻ chọn bài trang chủ bằng gradient tĩnh/viền, không thêm animation chạy liên tục. Chưa đo hiệu năng trên thiết bị.
- Kiểm thử: 13 test AuthenticationService và 5 test hồ sơ/đăng nhập đạt. Flutter analyze còn một cảnh báo import không dùng trong test catalog được chỉnh sửa đồng thời; chưa build/cài hoặc kiểm tra giao diện và hiệu năng thực tế.

## Lịch sử nghe và lời bài hát — 06/11/2026

- Sửa backend `PlatformTrafficService` ánh xạ `track_id` vào `trackId` trước khi lấy metadata lịch sử; test service đạt. Backend đang chạy phải được cập nhật/khởi động lại theo quy trình môi trường trước khi thay đổi có hiệu lực; chưa nghiệm thu với tài khoản thực.
- Player đọc timestamp LRC thật từ `lyricsSynced`, hoặc từ `lyricsPlain` nếu trường này thực sự chứa LRC; test continuity 4/4 đạt. API local xác nhận bài 10 Ngàn Năm có plain lyrics nhưng không có timestamp trong cả hai trường, vì vậy chưa thể tô chính xác bài này nếu chưa có dữ liệu đồng bộ. Không ước lượng mốc lời.
- Flutter analyze còn một cảnh báo import không dùng trong test catalog đang chỉnh sửa đồng thời; chưa kiểm tra thiết bị.

## Điều chỉnh tài khoản và tìm kiếm karaoke — 06/11/2026

- Đăng xuất chủ động không còn đưa thông báo “Bạn đã đăng xuất” vào form đăng nhập/đăng ký; thông báo hết hạn và lỗi xóa thông tin đăng nhập vẫn được giữ. Đã bỏ lối vào Thông báo ở tab Tài khoản.
- Tìm karaoke theo tên bài/nghệ sĩ có hoặc không dấu, duyệt các trang catalog thật trước khi lọc; ô tìm giới hạn 100 ký tự. Phương án này phát sinh nhiều request khi catalog lớn và chưa được nghiệm thu với API/thiết bị thật.
- Kiểm thử riêng repository karaoke và phiên đăng nhập: 24 test đạt. Analyze và test giao diện bị chặn bởi lỗi biên dịch trong các thay đổi catalog/subscription khác đang có trong workspace; chưa kiểm tra trên thiết bị.

Cập nhật: **05/11/2026**. Snapshot bàn giao; implementation không đồng nghĩa đã nghiệm thu production.

## Nâng cấp Logo Pre-Splash Native, Vòng lặp Splash, Khôi phục Icon Gốc & AOT Profile — 06/11/2026

- Theo yêu cầu của người dùng:
  - **Màn hình Splash Flutter (`lib/core/widgets/brand_splash.dart`)**: Giữ nguyên hiệu ứng sóng nhạc đặc trưng từ biểu tượng chữ `M` (`_WaveRevealMark`), 2 dải sóng sin uốn lượn + 3 vòng sóng âm elip (`_SplashAuraPainter`), 7 chữ cái `moodify` bật lên lệch nhịp và 9 cột `_SoundwaveEqualizer`, đồng thời bổ sung `_loopController` chạy lặp liên tục trong lúc chờ khôi phục phiên (`SessionPhase.restoring`) cho tới khi mở hẳn màn hình chính.
  - **Logo trước màn hình Splash Flutter (`values-v31/styles.xml`, `drawable/avd_launch_logo.xml`, `MainActivity.kt`)**: Giữ hiệu ứng vẽ đúng 2 nét chữ `M` + 5 cột sóng nhạc trong khung tròn tím phát sáng (`@drawable/avd_launch_logo`) và chạy vòng lặp liên tục (`Animatable2.AnimationCallback` trong `MainActivity.kt`) cho đến khi `onFlutterUiDisplayed()` mờ dần (`180 ms`).
  - **Icon ứng dụng ngoài màn hình chính (`mipmap-*/ic_launcher.png`)**: Khôi phục hoàn toàn bản icon ban đầu của dự án (nền `#0C0C10`, logo chữ `M` chính giữa có tỉ lệ căn lề chuẩn mực, gọn gàng, không bị tràn viền); xóa bỏ `mipmap-anydpi-v26` và các drawable thừa để launcher Samsung One UI tự động bo góc squircle chuẩn xác theo thiết kế gốc (như icon ở hàng 4 trong ảnh chụp).
  - **Tối ưu độ mượt & bản cài AOT `--profile`**: Đổi `InkSparkle.splashFactory` sang `InkRipple.splashFactory` trong `lib/app/theme/app_theme.dart`; bọc `TrackTile` trong `RepaintBoundary` và bỏ `ListTile(shape: ...)` clip mỗi dòng; bỏ `ShaderMask` lồng nhau trong splash; đóng gói và cài bản **AOT `--profile` arm64** lên thiết bị.
- Kiểm chứng: **134 tests passed**, `flutter analyze --no-pub` **No issues found**, `dart format --output=none --set-exit-if-changed lib test` **108 files, 0 changed**.

## Nâng cấp nhận diện bo góc đặc trưng & tối ưu độ mượt — 06/11/2026

- Thiết kế lại bề mặt và thang bo góc `AppRadii` (`lib/app/theme/app_theme.dart`) để bỏ cảm giác Flutter mặc định: `TrackTile` (`lib/features/catalog/presentation/catalog_widgets.dart`) chuyển thành thẻ bo `16px` có nền/viền riêng và huy hiệu sóng nhạc khi đang phát; `MusicArtwork` bo `12px` mặc định có viền mảnh `#16FFFFFF`; `HomeScreen` (`lib/features/home/presentation/home_screen.dart`) dùng chip lọc dạng viên thuốc (`pill: 999`) chuyển sắc tím, `_QuickTrack` bo `16px`, `_Spotlight` bo `24px` kèm nhãn `"Tâm điểm"` và nút `"Nghe ngay"` bo tròn, `SectionHeading` có thanh nhấn dọc chuyển sắc tím–hồng, `_TrackCard` có nút play nổi góc dưới; `MiniPlayer` (`lib/features/player/presentation/player_screen.dart`) dạng viên nang nổi bo `18px` kèm bóng đổ và `NavigationBar` (`lib/app/main_shell.dart`) có chỉ báo chọn bo `14px`; `SearchScreen`, `LibraryScreen` và `AccountScreen` đồng bộ công tắc viên thuốc và nhóm thẻ cài đặt bo `22px` kèm hộp icon bo `12px`.
- Tối ưu độ mượt (xử lý hiện tượng lag khi vừa phát nhạc vừa cuộn): tách `_MiniPlayerProgress` và `_PlayerSeekSection` lắng nghe riêng `position` qua `select` để `MiniPlayer` và `PlayerScreen` không rebuild toàn bộ cây widget mỗi nhịp thời gian; tiết lưu `positionStream` (`>= 200 ms`) trong `_MoodifyAudioHandler` (`lib/features/player/data/playback_engine.dart`) và chỉ gọi `playbackState.add` qua platform channel Android khi trạng thái phát/loading/seek thực sự đổi; bỏ `ImageFilter.blur` trực tiếp bên trong thẻ cuộn (`ArtworkBackdrop` khi `hero: true`), bọc `MusicArtwork` trong `RepaintBoundary` (`gaplessPlayback: true`, `FilterQuality.low`), chuyển `Pressable` sang `ValueNotifier` và bỏ `FadeTransition` bọc toàn bộ `MainShell`.
- Kiểm chứng: **134 tests passed**, `flutter analyze --no-pub` **No issues found**, `dart format --output=none --set-exit-if-changed lib test` **108 files, 0 changed**, APK debug arm64 production-config **PASS** (Gradle 46,0s), cài lên Samsung SM-A235F (`R58TC0KWATX`) qua `adb install -r` **Success** (`lastUpdateTime=2026-11-06 10:08:06`).

## Splash chuyển động từ logo Moodify — 05–06/11/2026

- Chẩn đoán nguyên nhân chưa thấy hiệu ứng trên Samsung SM-A235F: `MainActivity` kế thừa `AudioServiceActivity` nên pre-warm `FlutterEngine` lúc `FlutterRenderer` còn `0×0` khoảng 7,7 giây trước khi Android gắn `SurfaceView` và gửi viewport `1080×2366`; bản đầu chạy hết `680 ms` trong nền trước khi cửa sổ kịp hiển thị, đồng thời native `launch_background.xml` chỉ có nền trơn không có logo.
- Sửa native + Flutter: thêm `@drawable/launch_mark` (`android/app/src/main/res/drawable-xxxhdpi/launch_mark.png`) căn giữa trên nền `#0C0C10` trong `drawable/launch_background.xml` & `drawable-v21/launch_background.xml` (cùng iOS `LaunchScreen.storyboard`); `SplashLaunchGate` (`lib/core/widgets/brand_splash.dart`) lắng nghe `WidgetsBindingObserver.didChangeMetrics` và chỉ bắt đầu `_entranceController` qua `addPostFrameCallback` khi viewport thật khác 0 (`size.width > 0 && size.height > 0`).
- Nâng cấp chuyển động `BrandSplashHero` (1850 ms vào + 380 ms phóng mở cổng thoát): mark sóng chữ `M` vẽ dần từ trái sang phải kèm đầu bút sáng tím lavender, nảy đàn hồi (`easeOutBack`) và vệt ánh kim chéo; 2 dải sóng sin uốn lượn liên tục + 3 vòng sóng âm elip lan tỏa phía sau; chữ `moodify` bật lên từng ký tự lệch nhịp; bộ sóng nhạc 9 cột neon (`_SoundwaveEqualizer`) dao động theo pha và câu `"Âm nhạc theo từng cảm xúc"`. Khi `restoreFailed`, nhường ngay cho `_RestoringScreen`; khi bật reduced motion (`MediaQuery.disableAnimationsOf`), bỏ qua hiệu ứng và độ trễ chuyển cảnh.
- Kiểm chứng: **134 tests passed** (`test/core/brand_splash_test.dart` kiểm tra cả giữ tiến độ = 0 khi viewport `0×0`, chạy sau khi gắn kích thước thật, đợi `SessionPhase.restoring`, reduced motion và màn nhỏ `320×640` chữ `1.8x`), `flutter analyze --no-pub` **No issues found**, `dart format --output=none --set-exit-if-changed lib test` **108 files, 0 changed**, APK debug arm64 production-config **PASS** (Gradle 46,1s). Đã cài lên Samsung SM-A235F (`R58TC0KWATX`) qua `adb install -r` Success (`lastUpdateTime=2026-11-06 09:35:48`); màn hình máy lúc chụp đang khóa/tắt (`mScreenState=OFF`), cần người dùng mở khóa máy và chạm mở app để quan sát trực tiếp hiệu ứng.

## Lyrics toàn màn hình — 05/11/2026

- Thay lyrics sheet bằng `/lyrics`, có icon mở ở header player và nhãn mở toàn màn hình trong preview; metadata/artwork backdrop/seek/play-pause/previous-next dùng player hiện tại. Đóng/Back không load lại audio hoặc mất queue/position.
- LRC theo position engine thật: chữ lớn, câu đang hát sáng, màu/scale260ms và scroll420ms, reduced motion không animate. Cache đo TextPainter/prefix offsets theo font/width/height/text scale/locale, lazy item extent thật; kéo tay dừng follow, recenter, chạm câu tua timestamp. Intro trước cue đầu có nhãn/mốc thật. Đổi bài reset view; scrub cũ không seek bài mới.
- Quyền syncedLyrics server vẫn bắt buộc. Thiếu quyền/lỗi mạng/timing → plain text + gói/retry/nhãn phù hợp; thiếu plain có thể đọc chữ LRC tĩnh. Không nội suy timeline, không sửa nguồn lời/catalog/backend/DB, không ảnh hưởng module karaoke. Empty state cuộn được trên320×640/text1.8.
- Kiểm chứng: **106tests passed**, nhóm lyrics/continuity/router cuối **12tests passed** sau chỉnh thông báo chữ lớn; analyze **No issues found**, format **94files/0changed**, diff check sạch. APK debug arm64 production-config **PASS**, Gradle88,9s. Kết quả tại `../LYRICS_UX_2026-11-05.md`. Đã xem PNG render từ widget tests dùng fixture có nhãn rõ, chỉ ở artifacts/lyrics-review (ignore), không phải ảnh thiết bị hoặc production data.
- User yêu cầu tạm thời không cắm điện thoại, code sửa trước. Chưa cài/kiểm chứng lượt này trên Samsung, chưa nghiệm thu entitlement thật/LRC-native/performance/TalkBack. Đợt lyrics chưa commit/push; GitHub hiện lưu đợt trước tại a456a11.

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

- 06/11/2026: Thiết kế lại 3 giao diện theo mẫu app nhạc thị trường: (1) menu 3-chấm bài hát đổi thành bottom sheet có header artwork + tile icon, cuộn được khi màn thấp, hành động vẫn đi qua performTrackAction; (2) trang Gói dịch vụ: hero card gói hiện tại có chip trạng thái, dải lợi ích, card gói có giá/ngày + chip "Phổ biến nhất" cho gói 90 ngày, lịch sử dạng card với chip trạng thái tint nhẹ; (3) màn thanh toán SePay: pill "Đang chờ thanh toán" + đếm ngược 15 phút từ expiresAt, card thông tin chuyển khoản với copy có icon check đổi 2 giây, nội dung CK được nhấn mạnh "Bắt buộc chính xác", trạng thái thành công có badge check scale-in và phân biệt lịch áp dụng qua isEffectiveNow, hết hạn có nút "Tạo lại mã thanh toán" (controller thêm recreateOrder/lastPackageId). Sửa bug "Kiểm tra thanh toán" không phản hồi: khi manual check trả PENDING giờ hiện snackbar (pendingNotice) + lastCheckedAt; lý do gốc đơn vẫn PENDING là webhook SePay chưa tới backend local — cần ngrok chạy và SePay webhook trỏ đúng. dart format, flutter analyze 0 lỗi, 127/127 test đạt (thêm test pendingNotice/recreateOrder + widget test sheet). Chưa kiểm tra UI trên emulator; chưa commit.

- 06/11/2026: Chẩn đoán màn Lịch sử nghe hiện "Chưa nhận diện được bài hát": truy vấn trực tiếp MySQL/Mongo local cho thấy listening_history lưu đúng ObjectId (24 hex) và track tồn tại trong Mongo music_streaming_1; gọi thử /api/analytics/my-history bằng token chẩn đoán tái hiện được payload "Bài hát #track" + audioUrl rỗng. Nguyên nhân: tiến trình backend khởi động 00:05 build PlatformTrafficService thiếu dòng m.put("trackId", ...) trong row mapper nên vòng enrich theo trackId bị bỏ qua toàn bộ; bản trên đĩa (02:14, chưa commit, 1 dòng) đã có fix. Đã restart backend bằng start-local-api.ps1 và xác minh endpoint trả title/artist/audioUrl đầy đủ (audioUrl là URL moodify.click). Việc còn lại: commit 1 dòng fix PlatformTrafficService này lên backend main (chưa commit, chờ người dùng duyệt).

- 06/11/2026: Đồng bộ mobile với bản cập nhật karaoke trên web cùng ngày: (1) dialog điểm (solo lẫn phòng) thêm breakdown Cao độ 30%/Nhịp 20%/Độ phủ 50% và với solo thêm dòng độ phủ thời gian bài, qua parser mới KaraokeScoreResult đọc payload {score:{overall,pitch,rhythm,coverage}, quality, diagnostics} mà backend publicScoreResult vừa mở rộng (Kh Controller 20:18); (2) solo luôn mở dialog kết quả kể cả khi không đủ dữ liệu, hiện lý do insufficient_audio/reference_unreliable thay cho snackbar; (3) phiên điểm phòng nhận kết quả cả khi completed mà overall rỗng (khớp điều kiện use-karaoke-room-scoring của web); (4) thêm KaraokeRoomLiveClient — WS /api/ws/karaoke frame subscribe đầu tiên (token trong frame, không trên URL), heartbeat 20s, nối lại backoff min(10s, 700ms*2^n), ngắt hẳn khi server trả error — qua karaokeRoomLiveFactoryProvider: score.updated hiện dialog điểm tức thì (frame đủ score thì không gọi REST thêm), room.closed tự dọn và rời phòng kèm thông báo, playback/queue/member.* gọi _syncRoom liền thay vì chờ poll 4s; poll REST 3-4s giữ làm dự phòng. dart format, flutter analyze 0 lỗi, 151/151 test toàn repo đạt (thêm 5 test live client, test phòng stub live client như voice). Chưa kiểm chứng luồng WS thật trên emulator; chưa commit.

- 06/11/2026: Thiết kế lại mic phòng karaoke theo yêu cầu "chỉ cần 1 icon micro nhỏ": bỏ hẳn panel lớn (nút Bật mic của tôi + dòng trạng thái + chip Kết nối lại âm thanh) khỏi _RoomDetailView, thay bằng 1 IconButton nhỏ trên AppBar phòng — mic_off xám khi chưa nối (chạm = kết nối lại), mic_off thường khi đã nối tắt (chạm = bật), mic tím #B9A1FF khi đang bật/đang thu chấm điểm (chạm = tắt), spinner khi đang kết nối; lỗi kết nối giờ báo bằng snackbar (_connectVoice snackbar voice.error / karaokeError). Cập nhật 2 test voice sang find.byTooltip. Chẩn đoán 2 vấn đề người dùng báo trên emulator local API: (1) "Không kết nối được âm thanh phòng" KHÔNG phải do chạy production — app gọi 10.0.2.2:8088 đúng local; nguyên nhân là backend local thiếu env karaoke media (KARAOKE_MEDIA_TICKET_SECRET/KARAOKE_MEDIA_SERVICE_SECRET ≥32 byte, KARAOKE_MEDIA_WS_URL) nên voice-ticket trả 503 KARAOKE_MEDIA_NOT_CONFIGURED, và service mediasoup supporting-services/karaoke-media chưa chạy (cần KARAOKE_BACKEND_INTERNAL_URL=http://127.0.0.1:8088 vì backend local dùng 8088, MEDIASOUP_ANNOUNCED_IP=10.0.2.2 cho emulator, WS path /ws port 3001); (2) banner "Cần cập nhật backend và index hàng đợi" = server trả QUEUE_ALREADY_REQUESTED, mã lỗi chỉ còn tồn tại ở build HEAD — process Spring đang chạy build cũ, cần rebuild (mvnw) + chạy database/allow_multiple_karaoke_queue_items.sql (drop unique uk_karaoke_room_queue_requester) theo đúng thứ tự tạm dừng ghi hàng đợi. dart format, flutter analyze 0 lỗi, 151/151 test đạt; chưa kiểm chứng voice thật trên emulator vì thiếu media service. dart format, flutter analyze 0 lỗi, 151/151 test toàn repo đạt; chưa commit.

- 07/11/2026: Khắc phục 2 lỗi người dùng vẫn gặp trên emulator local: (1) mic phòng "Không kết nối được âm thanh phòng" — nguyên nhân chuỗi: .env KARAOKE_MEDIA_WS_URL=ws://localhost:3001/ws (emulator không tới được localhost, phải 10.0.2.2), container moodify-karaoke-media thiếu MEDIASOUP_ANNOUNCED_IP (mặc định 127.0.0.1 — ICE trỏ vào máy ảo) và KARAOKE_BACKEND_INTERNAL_URL=8080 (backend local 8088); đã sửa .env (WS=ws://10.0.2.2:3001/ws, ANNOUNCED_IP=10.0.2.2, INTERNAL_URL=host.docker.internal:8088), docker compose force-recreate media, health 200. (2) thêm bài thứ 2 báo "Không thể hoàn tất thao tác" — DB đã đúng (unique index uk_karaoke_room_queue_requester đã drop trước đó), nhưng process backend 8088 cũ đã bị thay bằng instance IDE chạy 8080 (do .env SERVER_PORT=8080); đã kill instance 8088 cũ, chạy lại mvnw spring-boot:run với SERVER_PORT=8088 (đè .env), API /api/karaoke/tracks trả 401 đúng auth gate. Lưu ý: instance java PID 9848 đang giữ 8080 (không app nào dùng); khi chạy backend từ IDE cần SERVER_PORT=8088. Chưa test lại trên emulator — chờ người dùng thử bật mic và thêm bài thứ 2.

- 07/11/2026: Xử lý nốt "mic xoay mãi" trong phòng karaoke mobile (hàng đợi đã thêm được 2 bài sau bản rebuild trước): nguyên nhân gốc — server mediasoup (supporting-services/karaoke-media/server.js) đóng mọi WS handshake không có header Origin hợp lệ (1008 "origin not allowed") theo allowlist MEDIASOUP_ALLOWED_ORIGINS của web (localhost:3000), mà Flutter dart:io WebSocket.connect KHÔNG GỬI Origin (đã probe thực tế: undefined) → mobile bị chặn trước bước auth, client chờ 'authenticated' hết timeout 10s → snackbar lỗi lặp vô hạn. Fix: server.js cho phép request không có Origin (native client); browser vẫn bắt khớp allowlist — ticket one-use 60s + lease 15s + X-Karaoke-Media-Key vẫn là chốt bảo vệ chính. Đã docker compose build + force-recreate media, xác minh chuỗi: TCP 10.0.2.2:3001 từ emulator OPEN, WS auth không-Origin qua được origin gate, JWT verify OK, gọi backend /api/internal/karaoke/media-sessions/consume thành công (ticket diag giả sid bị từ chối VOICE_SESSION_NOT_ACTIVE là hành vi đúng). Cảnh báo còn treo: clock skew container ~101s so với host (ngưỡng fail ticket = skew > 180s vì TTL 60s + tolerance 120s) — nếu mic hỏng lại sau khi máy sleep, restart Docker Desktop để đồng hồ WSL2 resync; cân nhắc chrony/w32tm. Chờ người dùng hot-restart app test lại; server.js backend chưa commit.

- 07/11/2026: Sửa "start bài hát trong phòng báo Dữ liệu từ máy chủ chưa đúng định dạng": KaraokePlayback.loadTrack đòi key "songId" (requiredText → FormatException → AppFailure CONTRACT) trong khi hợp đồng thật KaraokeRoomPlaybackTrackResponse của backend (cả HEAD lẫn working tree) trả "trackId" — flow _syncRoomAudio load nhạc nền phòng vì thế luôn văng lỗi, UI vẫn hiển thị PAUSE/lyrics theo status máy chủ nên tưởng là đang phát. Fixture karaoke_playback_test trước nay dùng songId nên che mất sai khác. Fix: loadTrack nhận songId (solo/catalog) hoặc trackId (phòng); fixture đổi sang trackId + thêm test phủ cả 2 key. dart format, flutter analyze 0 lỗi, 31 test player/karaoke đạt; chưa chạy full suite trong note này. Chờ người dùng hot-restart app test start bài trong phòng.
