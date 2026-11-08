# Assets được sử dụng

- `brand/moodify-mark.png`: sao chép nguyên file `Moodify-Mobile/assets/images/moodify-logo.png` của dự án Moodify, 04/11/2026. Chưa xác minh chuỗi quyền sở hữu bên ngoài; cần rà trước phát hành công khai. Không mang logo/ảnh template Expo hoặc catalog vào app.
- `fonts/BeVietnamPro-*.ttf` và `fonts/OFL.txt`: lấy từ Google Fonts, thư mục `ofl/bevietnampro` tại `https://github.com/google/fonts/tree/main/ofl/bevietnampro`, 04/11/2026. Giữ nguyên font và SIL Open Font License kèm theo. Body/display dùng cùng một font, các weight 400/500/600/700.
- Icon launcher Android, AppIcon iOS và icon web được render từ mark có sẵn: crop viền trong suốt, giữ tỷ lệ, đặt giữa nền `#08090D`, chiều lớn nhất bằng 68% cạnh icon. Không tạo logo mới bằng AI. Bản iOS opaque RGB; kiểm tra trên Xcode vẫn chưa thực hiện.
- `banners/` và `covers/`: sao chép nguyên bản từ `Moodify/public/banners/`, `Moodify/public/Brand/moodify_brand_assets/banners_and_backgrounds/` và `Moodify/public/covers/` của dự án web Moodify theo yêu cầu người dùng ngày 08/11/2026 để làm giàu bố cục hình ảnh, banner và quảng cáo trên các màn hình ngoài trang chủ.
- `audio/moodify_notification_chime.mp3` (và `android/app/src/main/res/raw/moodify_notification_chime.mp3`): trích xuất đoạn âm thanh nhận diện thương hiệu `"Moodify"` ở đầu file `Moodify/public/audio/moodify_platform_ident.mp3` (loại bỏ câu thoại phía sau `"Âm nhạc theo cách của bạn"`) để làm chuông thông báo hệ thống của ứng dụng.

Không có dữ liệu catalog giả, tài khoản hoặc thanh toán mẫu trong assets.
