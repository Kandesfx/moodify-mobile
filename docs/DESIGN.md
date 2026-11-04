# Thiết kế trải nghiệm Moodify Flutter

Ngày chốt baseline: **04/11/2026**. Phạm vi: app dành cho người nghe trên Android/iOS.
Đã triển khai theme, login/register, khôi phục phiên và tài khoản cho M1. Các màn nghe nhạc vẫn là đặc tả; bằng chứng thiết bị được ghi riêng tại `ai/STATE.md`.
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

## 2. Token màu đề xuất

| Token | Giá trị | Vai trò |
| --- | --- | --- |
| `background` | `#08090D` | Nền chính, không phủ gradient toàn màn |
| `surface` | `#121319` | Mini-player, navigation, sheet |
| `surfaceRaised` | `#1B1C25` | Dialog, vùng cần phân cấp rõ |
| `border` | `#2B2D39` | Divider/focus boundary khi có ích |
| `textPrimary` | `#F4F2ED` | Tiêu đề, tên bài, nội dung chính |
| `textSecondary` | `#B7B5C0` | Nghệ sĩ, metadata cần đọc |
| `textMuted` | `#93919E` | Nội dung phụ; không dùng cho thông tin thiết yếu |
| `primary` | `#7A5CFF` | CTA chính, tab được chọn, vị trí phát |
| `onPrimary` | `#FFFFFF` | Chữ/icon trên nền primary; kiểm tra contrast khi triển khai |
| `accent` | `#F557B6` | Điểm nhấn ít xuất hiện, không cạnh tranh CTA |
| `error` / `success` | `#FF8796` / `#73D6AF` | Trạng thái có nhãn/icon giải thích, không chỉ dựa vào màu |

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

- Bốn tab gốc: **Trang chủ · Tìm kiếm · Thư viện · Tài khoản**; giữ trạng thái tab hợp lý và label luôn đọc được.
- Detail album/playlist/artist, Premium, offline, karaoke mở từ vị trí có ngữ cảnh; không tạo tab thứ năm chỉ để khoe tính năng.
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
- Motion khoảng 150–250 ms cho phản hồi/chuyển lớp; giảm hoặc bỏ animation khi người dùng bật reduced motion. Không dùng chuyển động trang trí liên tục hay visualizer giả làm phân tích audio thật.
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

Giữ cấu trúc quen thuộc RN: Trang chủ → Tìm kiếm → Thư viện → Tài khoản, nền tối/tím Moodify, quick access 2 cột, album, bài hát và nghệ sĩ. Filter chỉ đổi kết quả qua API. Mini player nằm trên navigation, full player là route phủ lên tab. Không đưa banner karaoke/thông báo/settings khi luồng chưa port. Đây là chuyển bố cục và tương tác, chưa phải chứng nhận giống từng pixel hoặc hoàn tất thiết kế.

Artwork thiếu dùng music-note trung tính; cover Unsplash fallback cứng của backend bị loại. Tên chỉ có hash được hiển thị là chưa có tên và không chọn làm quick access; dữ liệu backend giữ nguyên. Plain lyrics được hiển thị tĩnh, không giả highlight đồng bộ. Widget test 320×640/text scale 1.8 kiểm tra main/search/guest library/player/auth không overflow.
