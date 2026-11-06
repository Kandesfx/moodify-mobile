# Thiết kế trải nghiệm Moodify Flutter

Ngày chốt baseline: **04/11/2026**. Phạm vi: app dành cho người nghe trên Android/iOS.
Đã triển khai theme, auth, shell nghe nhạc và các màn M2–M4. Bố cục mobile bám source React Native theo yêu cầu người dùng; bằng chứng thiết bị được ghi riêng tại `ai/STATE.md`.
Thực hiện parity theo `MIGRATION_PLAN.md` trước khi mở rộng chức năng; tài liệu này không tự mở thêm phạm vi.

## 1. Nguồn tham chiếu và quyết định

| Nguồn đã khảo sát | Thực tế trong source | Cách dùng trong Flutter |
| --- | --- | --- |
| `Web/app/globals.css` | Nền `#08090D`, chữ `#F4F2ED`; Sora, Be Vietnam Pro, Space Grotesk | Lấy độ tương phản và khả năng đọc tiếng Việt; giảm còn tối đa hai font |
| `Web/public/Brand/moodify_brand_assets/tokens/colors.json` | Tím `#7A5CFF`, hồng `#F557B6`, nền navy `#0D1224`, Poppins | Giữ nhận diện tím/hồng; không trộn thêm nền/font cũ vào baseline |
| `Mobile/src/constants/theme.ts`, `Mobile/src/app/(tabs)/_layout.tsx` | Có token hệ thống đen/trắng nhưng tab dùng `#0C0C10`, active `#8B5CF6` và nhiều màu inline | Giữ cấu trúc bốn tab, thống nhất lại token thay vì sao chép các màu rời rạc |
| Alias `Taste` trong `ai/SOURCE_MAP.md` | Định hướng console quản trị, mật độ cao và số liệu catalog/user tại thời điểm viết | Chỉ lấy kỷ luật hierarchy/spacing/màu; không chuyển mật độ, module quản trị hoặc con số sang app |

Các nguồn trên chưa thống nhất thành một hệ thống. Quyết định cho Flutter: nền gần đen, tím thương hiệu làm accent chính, hồng dùng tiết chế.
Artwork và nội dung nhạc thật tạo sự đa dạng. Không dùng mỗi màn một palette hoặc gắn giao diện vàng chỉ vì tài khoản Premium.
Asset logo dùng bản chính thức phù hợp nền; chỉ đưa vào repo những biến thể thực sự sử dụng, có ghi nguồn/quyền tái sử dụng.

## 2. Token màu đang dùng

| Token | Giá trị | Vai trò |
| --- | --- | --- |
| `background` | `#0C0C10` | Nền chính theo RN |
| `surface` | `#171720` | Card, sheet |
| `surfaceRaised` | `#1F1F2E` | Mini-player, filter, dialog |
| `border` | `#303043` | Divider/focus boundary khi có ích |
| `text` | `#FAFAFC` | Tiêu đề, tên bài, nội dung chính |
| `secondary` | `#A2A3B2` | Nghệ sĩ, metadata cần đọc |
| `lavender` | `#C4B5FD` | Trạng thái chọn, tiến độ |
| `primary` | `#8B5CF6` | CTA chính, tab được chọn |
| `onPrimary` | `#FFFFFF` | Chữ/icon trên nền primary; kiểm tra contrast khi triển khai |
| `liked` | `#EC4899` | Trạng thái yêu thích |
| `error` | `#FF8796` | Trạng thái có nhãn/icon giải thích, không chỉ dựa vào màu |

Token M1 ở `lib/app/theme/app_theme.dart`; dùng semantic name trong widget, tránh rải mã hex theo màn. Nút có vùng chạm tối thiểu 48 logical pixels; form có semantics/autofill, scroll và trạng thái lỗi thật. Logo co theo bề rộng ở text scale lớn. M1 dùng Be Vietnam Pro TTF kèm OFL trong assets; chưa suy kết quả render iOS từ Android.

## 3. Typography, khoảng cách và hình khối

- Body ưu tiên **Be Vietnam Pro**; display dùng cùng font để giữ nhất quán, chỉ thêm **Sora** khi có lý do rõ. Tối đa hai family cho body/display; số dùng tabular figures nếu font hỗ trợ.
- Trước khi bundle phải xác minh license/quyền phân phối, glyph tiếng Việt và asset **TTF/OTF** tương thích Flutter. Không copy WOFF2 của Next.js thẳng vào app hoặc suy luận quyền sử dụng từ tên font.
- Khi chưa có font hợp lệ, dùng system fallback và ghi trạng thái; không chặn đọc nội dung bằng asset tải lỗi.

| Token chữ | Size / line-height đề xuất | Weight / cách dùng |
| --- | --- | --- |
| `display` | 28 / 36 | 700; tiêu đề màn, tránh headline quá lớn chiếm màn nhỏ |
| `title` | 22 / 30 | 600; section hoặc tên playlist |
| `subtitle` | 18 / 26 | 600; heading nhỏ |
| `body` | 16 / 24 | 400–500; nội dung chính và tên bài |
| `label` | 14 / 20 | 500–600; button, navigation, metadata |
| `caption` | 12 / 18 | 400–500; thông tin phụ, không dùng cho giá/quyền/lỗi quan trọng |

Spacing theo thang **4, 8, 12, 16, 24, 32** logical pixels; gutter điện thoại 16, section gap 24–32.
Radius đề xuất: control 10–12, artwork 8–12, sheet 20; không bo mọi khối thành pill.
List bài hát dùng hàng phẳng, divider hoặc khoảng trắng. Card chỉ dùng khi nhóm nội dung cần một đơn vị tương tác riêng; tránh nhiều lớp card lồng nhau.
Thời lượng, giá và ngày hết hạn có định dạng thống nhất; không gắn đơn vị/độ chính xác mà API không cung cấp.

## 4. Navigation và player

- Sau merge nhánh karaoke: **Trang chủ · Tìm kiếm · Karaoke · Thư viện · Tài khoản**; giữ thứ tự từ nhánh tích hợp, kiểm tra label trên màn nhỏ/chữ lớn. Các tab nhạc giữ trạng thái; thoát tab karaoke về trang chọn chế độ để dọn mic/voice.
- Detail album/playlist/artist, Premium và offline mở từ vị trí có ngữ cảnh. Karaoke có tab riêng sau merge `Thuan_Branch`, với lối vào solo/phòng.
- Mini-player nằm trên tab bar và safe area, không che item cuối hoặc CTA. Chỉ hiện khi có playback context thật; artwork, tên bài và play/pause phải đồng bộ engine.
- Chạm phần nội dung mini-player mở full-player; nút play/pause có hit area riêng. Full-player có back/close rõ ràng, artwork, title/artist, seek, thời lượng và điều khiển cần thiết.
- Mini-player, full-player và OS controls cùng một coordinator. UI không tạo engine mới hoặc tự cập nhật trạng thái “đang phát” trước kết quả thực tế.
- Full-player/keyboard/sheet tuân thủ Back Android và đóng theo lớp; không làm mất tab hoặc queue khi chỉ đóng màn phát.
- Lyrics đồng bộ chỉ hiện khi có timestamp thật; thiếu synced lyrics thì dùng lời tĩnh có nhãn phù hợp hoặc trạng thái chưa có. Không nội suy thời gian để giả hiệu ứng karaoke.

## 5. Nội dung và phong cách

- Tên bài, nghệ sĩ, artwork và thao tác nghe là trọng tâm. Mỗi khối phải giúp chọn, phát, tìm hoặc quản lý nhạc.
- Bỏ chip/badge trang trí, khẩu hiệu lặp, đoạn mô tả vô nghĩa, marquee, RGB border, glow dày và icon sparkle gắn mọi nơi.
- Filter chỉ xuất hiện khi thay đổi kết quả thật, thể hiện lựa chọn và có cách bỏ lọc. Không thêm chip “AI”, “hot”, “live”, “dành riêng cho bạn” nếu không có nguồn xác minh.
- Không sinh số người nghe, phần trăm mood, rating, điểm hát hoặc số bài. Chỉ hiển thị metadata được API/engine cung cấp và giải thích khi thực sự hữu ích.
- Không tuyên bố Lossless/Hi-Res/320 kbps/DRM hoặc khả năng offline chỉ dựa trên tên gói/nút chọn. Hiện đúng capability và entitlement đã xác minh.
- Artwork thiếu/lỗi dùng placeholder trung tính của Moodify; không thay bằng ảnh stock/album khác. Không tải ảnh remote chỉ để làm màn hình có vẻ đầy.
- Một CTA chính cho một quyết định; mọi CTA phải thực hiện luồng thật. Tính năng chưa có thì bỏ khỏi release hoặc khóa kèm lý do rõ, không nút bấm im lặng hay success giả.
- Premium hiển thị giá, thời hạn, quyền và trạng thái từ server. Callback thanh toán chỉ mở bước kiểm tra, không phải bằng chứng giao dịch thành công.

## 6. Accessibility, chuyển động và trạng thái

- Dùng SafeArea/insets thực tế cho status bar, camera cutout, gesture bar và bàn phím; không hardcode chiều cao inset theo máy mẫu.
- Touch target tối thiểu **44×44 iOS / 48×48 Android** logical pixels; icon có thể nhỏ hơn nhưng vùng chạm đủ rộng, không chồng nhau.
- Hỗ trợ text scaling/Dynamic Type, tên tiếng Việt dài và màn nhỏ; nội dung quan trọng không bị cắt mất chỉ để giữ card cố định chiều cao.
- Có semantics label/state cho icon, tab, slider, like/download; thứ tự đọc hợp lý, không đọc artwork trang trí lặp lại tên bài.
- Focus phải nhìn thấy khi dùng keyboard/switch; sau mở dialog focus vào nội dung, khi đóng trả về trigger hợp lý. Không biểu đạt selection/error chỉ bằng màu.
- Motion: nhấn 120 ms (scale .975), tab fade 180 ms, mini-player 220 ms, section vào 280 ms với stagger có giới hạn; route phủ trượt lên 320 ms/đóng 240 ms, sheet 280/220 ms. Tắt các hiệu ứng này khi bật reduced motion; mini-player bỏ AnimatedSize ở chế độ đó. Không visualizer giả hoặc chuyển động trang trí liên tục.
- Loading dùng skeleton cấu trúc hoặc indicator vừa đủ; empty nêu điều kiện thật và hành động phù hợp; error có retry khi an toàn. Không `catch → demoData`.
- Refresh có thể giữ cache thật còn hợp lệ, báo stale khi cần; không dùng cache làm trạng thái thanh toán/Premium hiện tại. Phân biệt mất mạng, không có kết quả và thiếu quyền.
- Mutation chỉ xác nhận thành công sau kết quả có thể tin cậy; thao tác optimistic phải rollback và báo lỗi. Mic permission bị từ chối cần cách khôi phục phù hợp hệ điều hành.

## 7. Tiêu chí nghiệm thu màn hình

| Màn/luồng | Điều kiện nghiệm thu giao diện và dữ liệu |
| --- | --- |
| Auth | Form đọc được khi bàn phím mở; validation/lỗi từ API rõ; không mất input hợp lệ hoặc lặp submit |
| Trang chủ/catalog | Nội dung thật, list phân trang, artwork fallback trung tính; không tải toàn catalog để trang trí |
| Tìm kiếm/cảm xúc | Có loading/empty/error riêng; bỏ response query cũ; không hiển thị match/điểm cảm xúc tự tạo |
| Thư viện/playlist | ID và số lượng từ API; thêm/xóa cập nhật đúng hoặc rollback; empty có hành động khả dụng |
| Mini/full-player | Cùng trạng thái engine; seek/time đúng; buffering/error phân biệt pause; không che navigation |
| Tài khoản/Premium | Edit có API thật mới báo lưu; giá/quyền/giao dịch theo server; không toggle trả phí cục bộ |
| Offline | Progress từ bytes/state thật; phân biệt đang tải/tải dở/hết quyền; user khác không thấy file như nhạc của mình |
| Karaoke | Mic/voice/clock/score từ pipeline thật; không room giả, điểm ngẫu nhiên hoặc highlight lời nội suy |
| Toàn app | Kiểm tra safe areas, text scale, screen reader, focus, target chạm và reduced motion trên thiết bị phù hợp |

Khi triển khai, lưu ảnh kiểm tra có chọn lọc ngoài source hoặc artifact review; ghi thiết bị/kích thước và phần chưa kiểm chứng trong STATE.
Không đánh dấu thiết kế hoàn thiện chỉ vì đã có tài liệu hoặc screenshot: mỗi màn phải đạt trạng thái dữ liệu, hành vi và accessibility tương ứng.

## 8. Baseline M2 ngày 04/11/2026

Giữ bố cục RN cho các màn nhạc, thêm tab Karaoke giữa Tìm kiếm và Thư viện sau merge, nền tối/tím Moodify và Be Vietnam Pro. Theo yêu cầu sửa thiết kế, Home bám `Mobile/src/app/(tabs)/index.tsx`: header logo gọn, filter thật, lưới quick tracks 2 cột tối đa 6 bài, spotlight dùng artwork thật làm nền mờ, kệ nhạc ngang, nghệ sĩ tròn, album và danh sách bài. Ẩn shelf album khi API rỗng. Quick/spotlight lấy từ catalog hiện tại; không gọi là lịch sử, trending hay cá nhân hóa khi API không chứng minh.

Mini-player nổi có lề 8, cover 44, yêu thích/play/progress; tab bar cao 64 không có pill Material lớn. Full player có nền cover mờ, cover bo góc, play tròn trắng, seek/volume mảnh, lyrics preview thật và queue/share/sleep; trượt từ dưới lên và vuốt header xuống để đóng. Search có hai segment nền đặc theo RN. Library vẫn là danh sách trong Playlist/Yêu thích/Album, guest có card nhận diện; Account gom avatar/tên vào card gọn. Queue ở sheet riêng; lyrics chuyển sang màn riêng theo đợt 05/11 bên dưới. Karaoke đã merge; quảng cáo tiếp tục thuộc nhánh cộng tác viên. Đây chưa phải chứng nhận nghiệm thu toàn bộ UI/native.

Nền artwork chỉ blur lớp ảnh riêng, giới hạn decode 360 px và RepaintBoundary; không blur cả subtree tương tác. LRC parse theo thay đổi track thay vì mỗi tick tiến độ. Trạng thái tab và engine được giữ khi chuyển cảnh. Không thêm dependency animation.

Artwork thiếu dùng music-note trung tính; cover Unsplash fallback cứng của backend bị loại. Tên chỉ có hash được hiển thị là chưa có tên, dữ liệu backend giữ nguyên. Plain lyrics hiển thị tĩnh; synchronized lyrics chỉ dùng timestamp thật và entitlement server. Search cuộn cả header khi bàn phím mở. Tiêu chí/test màn nhỏ, chữ lớn và phần chưa có bằng chứng nằm trong STATE và UX_REVIEW.

## 9. Lyrics toàn màn hình — 05/11/2026

Điều chỉnh06/11 sau cập nhật GitHub: lời đồng bộ được mở cho mọi người dùng theo upstream, bỏ gate gói/retry entitlement của thiết kế05/11 phía dưới. LRC thật có thể nằm trong lyricsSynced hoặc lyricsPlain; plain untimed vẫn không nội suy. Khi quảng cáo đang phát, màn lời ẩn cue bài đang chờ và khóa seek/previous/next để không vượt policy quảng cáo.

`/lyrics` mở từ icon rõ ở header full-player hoặc preview có nhãn Mở toàn màn hình. Giữ artwork backdrop hiện có (decode có giới hạn, blur lớp ảnh), safe area, metadata bản đang phát và thanh điều khiển nhạc ở dưới; không tạo engine. Back/đóng chỉ rời màn lời.

Lời đồng bộ dùng chữ 27–32sp đậm, căn trái, khoảng cách theo dòng đã đo; câu hiện tại sáng, câu khác giảm độ nổi. Chuyển màu/scale 260ms và scroll 420ms easeOutCubic; reduced motion bỏ animation. Không tô theo từng từ khi chỉ có timestamp dòng. Đo chiều cao theo width/font/locale/text scale và cache prefix offsets; lazy list với item extent thật, không tính y bằng chỉ số nhân chiều cao cố định. Kéo tay tạm ngừng follow, Về câu đang phát khôi phục; chạm câu tua timestamp thật. Trước cue đầu hiển thị Nhạc dạo và mốc bắt đầu thật.

Thiếu LRC → lời tĩnh có nhãn; thiếu entitlement/lỗi kiểm tra → đọc lời tĩnh và CTA gói/retry. Có thể lấy chữ từ LRC nếu API không có plain lyrics, nhưng không dùng timestamp để highlight/tua khi chưa có quyền. Không nội suy plain lyrics hoặc cấp quyền cục bộ. Thiếu mọi lời có trạng thái riêng cuộn được trên màn nhỏ/chữ lớn. Tên bài đổi reset nội dung/follow, scrub dang dở không seek bài mới. Kiểm chứng thiết bị và hiệu năng profile còn chờ; ảnh render từ widget test không thay bằng chứng điện thoại.

## 10. Splash chuyển động từ logo nền tảng & Pre-Splash Native — 05–06/11/2026

Khi mở app, giai đoạn **trước màn hình splash Flutter** (gồm System SplashScreen của Android 12+ và cửa sổ native trong lúc `AudioServiceActivity` khởi tạo engine) được thiết kế đồng bộ, có chiều sâu và chuyển động:

- **Android 12+ System Splash (`values-v31/styles.xml`, `values-night-v31/styles.xml`)**: Dùng `windowSplashScreenAnimatedIcon="@drawable/avd_launch_logo"` (`animated-vector` vẽ dần đúng 2 nét rời của chữ `M` bằng `trimPathEnd`, khung tròn tím đậm phát sáng `r = 28.5`, vòng sóng âm lan tỏa và 5 cột equalizer dao động) kết hợp `windowSplashScreenBrandingImage="@drawable/launch_branding"` và chuyển giao ngay trong `MainActivity.onCreate` (`splashScreen.setOnExitAnimationListener`).
- **Cửa sổ Native Pre-Splash & `MainActivity.kt`**:
  - `MainActivity` gắn lớp phủ native chạy vòng lặp liên tục (`Animatable2.AnimationCallback`) của `@drawable/avd_launch_logo` kèm chữ `moodify` và viên thuốc `"Âm nhạc theo từng cảm xúc"` từ `onCreate` cho tới khi `onFlutterUiDisplayed()` mờ dần (`180 ms`).
- **Adaptive Launcher Icon & `BrandLockup`**: Bộ icon ứng dụng ngoài màn hình chính (`mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml`, `drawable/ic_launcher_background.xml`, `drawable/ic_launcher_foreground.xml` và `mipmap-*/ic_launcher.png`) dùng khung vuông bo góc nền tím đậm (`#2D224C` → `#0E0C18`), viền tím sáng và logo chữ `M` chính giữa; `BrandLockup` (`lib/core/widgets/brand_lockup.dart`) đồng bộ huy hiệu bo góc chuyển sắc tím.
- **Lớp `SplashLaunchGate` & `BrandSplashHero` trong Flutter**: Giữ hiệu ứng sóng nhạc đặc trưng từ biểu tượng chữ `M` (`_WaveRevealMark`), 2 dải sóng hình sin uốn lượn + 3 vòng sóng âm elip (`_SplashAuraPainter`), 7 chữ cái `moodify` bật lên lệch nhịp và 9 cột `_SoundwaveEqualizer`, đồng thời bổ sung `_loopController` chạy lặp liên tục trong lúc chờ khôi phục phiên (`SessionPhase.restoring`) cho tới khi vào ứng dụng. Dùng `FadeTransition` / `ScaleTransition` có `RepaintBoundary` và bỏ `ShaderMask` lồng nhau để không tạo `saveLayer` mỗi frame. Khi bật reduced motion (`MediaQuery.disableAnimationsOf`), bỏ qua hiệu ứng và độ trễ chuyển cảnh.

## 11. Hệ thống bo góc đặc trưng & tối ưu độ mượt 60fps — 06/11/2026

Để khắc phục cảm giác mặc định của Flutter và hiện tượng khựng/lag khi cuộn vừa phát nhạc:

- **Hệ thống hình học `AppRadii` & bề mặt có chiều sâu (`lib/app/theme/app_theme.dart`)**: Chuẩn hóa thang bo góc (`xs: 10`, `sm: 14`, `md: 18`, `lg: 22`, `xl: 26`, `pill: 999`), viền mảnh ánh sáng (`#2E2B42` / `#16FFFFFF`) trên nền tối `#161520`–`#1F1D2E`.
- **Thành phần đặc trưng Moodify**:
  - `TrackTile` (`lib/features/catalog/presentation/catalog_widgets.dart`): Chuyển từ `ListTile` phẳng sát cạnh sang thẻ bo góc `16px` có nền riêng (`#14131D`, khi đang phát chuyển `#231C38` kèm viền `#5A3FD6` và huy hiệu sóng nhạc `graphic_eq_rounded` ở góc bìa `52×52` bo `12px`).
  - `HomeScreen` (`lib/features/home/presentation/home_screen.dart`): Chip lọc thể loại dạng viên thuốc (`pill: 999`) có chuyển sắc tím khi chọn; thẻ `_QuickTrack` bo `16px` có gradient nhẹ; thẻ `_Spotlight` bo `24px` kèm nhãn `"Tâm điểm"` và nút `"Nghe ngay"` bo tròn; tiêu đề mục `SectionHeading` có thanh nhấn dọc chuyển sắc tím–hồng (`#8B5CF6` → `#EC4899`); thẻ bài hát ngang có nút play nổi góc dưới.
  - `MiniPlayer` & thanh điều hướng (`lib/app/main_shell.dart`, `lib/features/player/presentation/player_screen.dart`): `MiniPlayer` dạng viên nang nổi bo `18px` có viền sáng và bóng đổ; thanh điều hướng có đường phân tách mảnh phía trên và chỉ báo chọn bo `14px`.
  - `SearchScreen`, `LibraryScreen`, `AccountScreen`: Chuyển công tắc chế độ tìm kiếm sang pill bo `16px`/`12px`, `TabBar` thư viện dạng viên thuốc, và gom nhóm mục cài đặt Tài khoản vào thẻ bo `22px` kèm icon đặt trong hộp bo `12px`.
- **Tối ưu hiệu năng & độ mượt**:
  - Cô lập cập nhật `position` trong `MiniPlayer` (`_MiniPlayerProgress`) và `PlayerScreen` (`_PlayerSeekSection`) qua `ref.watch(playerControllerProvider.select(...))` để không dựng lại toàn bộ cây widget player/shell mỗi nhịp thời gian phát.
  - Trong `_MoodifyAudioHandler` (`lib/features/player/data/playback_engine.dart`), tiết lưu `positionStream` (`>= 200 ms`) và chỉ gọi `playbackState.add` qua platform channel Android khi trạng thái phát/loading/seek thực sự đổi.
  - Trong `ArtworkBackdrop` (`lib/features/catalog/presentation/artwork_backdrop.dart`), bỏ shader `ImageFilter.blur` trực tiếp bên trong thẻ cuộn (`hero: true`) và giảm kích thước mẫu blur nền tĩnh xuống `cacheWidth: 180`; bọc `MusicArtwork` trong `RepaintBoundary` với `gaplessPlayback: true`; dùng `ValueNotifier` trong `Pressable` và bỏ `FadeTransition` toàn màn hình ở `MainShell`.
