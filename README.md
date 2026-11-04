# Moodify Flutter

Ứng dụng mobile Flutter của Moodify, được tách thành thư mục và repository độc lập để phù hợp đề cương. Backend và web hiện tại tiếp tục là hệ thống đối chiếu.

**Trạng thái 04/11/2026:** đã có password auth/session và phần lõi M2: bốn tab, home/catalog phân trang, tìm kiếm thường/cảm xúc, album/nghệ sĩ, thư viện/playlist cơ sở, một player với mini/fullscreen và OS controls. Khách vào Trang chủ ngay, thao tác cá nhân yêu cầu đăng nhập. 53 test đạt; APK debug đã chạy và phát nhạc trên Samsung. Đây là bản phát triển: entitlement/quảng cáo/telemetry, một số thao tác thư viện và các milestone tiếp theo chưa hoàn tất. Bằng chứng và giới hạn ở [STATE](docs/ai/STATE.md).

## Đọc và làm việc

| Nhu cầu | Tài liệu |
| --- | --- |
| AI bắt đầu công việc | [AGENTS.md](AGENTS.md), [CONTEXT](docs/ai/CONTEXT.md), [STATE](docs/ai/STATE.md) |
| Tổ chức hệ thống và mã nguồn | [ARCHITECTURE](docs/ARCHITECTURE.md) |
| Chuyển tính năng cũ và tiêu chí nghiệm thu | [MIGRATION_PLAN](docs/MIGRATION_PLAN.md) |
| API/auth/player và dữ liệu | [API_CONTRACT](docs/reference/API_CONTRACT.md) |
| Kết quả khảo sát và giới hạn bằng chứng | [LEGACY_AUDIT](docs/reference/LEGACY_AUDIT.md) |
| Thiết kế giao diện | [DESIGN](docs/DESIGN.md) |
| Vị trí source cũ/mới | [SOURCE_MAP](docs/ai/SOURCE_MAP.md) |
| Cách thực hiện và bàn giao mỗi nhiệm vụ | [WORKFLOW](docs/ai/WORKFLOW.md) |
| Quyết định và vấn đề còn mở | [DECISIONS](docs/DECISIONS.md) |

## Chạy và bàn giao repo

Thư mục hiện tại: `D:\Hai\study\DATN\Moodify-Flutter`, nằm cạnh workspace cũ, không nằm bên trong repository cũ. Mở trực tiếp thư mục này bằng IDE/Codex cho các phiên Flutter sau.

Toolchain đã dùng: **Flutter 3.41.6 stable / Dart 3.11.4**. Android yêu cầu SDK và thiết bị/emulator sẵn sàng; minSdk 24. Scaffold iOS có cấu hình Keychain, nhưng chưa build trên macOS/Xcode. Web được tạo để preview, chưa chứng nhận làm bản phát hành web.

```powershell
flutter pub get
flutter devices
flutter run -d <device-id> --dart-define-from-file=config/production.json
```

`config/production.json` chứa URL public `https://api.moodify.click/api`, không có credential. App gọi backend hiện có; không cần khởi động backend cũ. Không tự tạo tài khoản production để kiểm thử.

Cho môi trường local, tạo file JSON trong `config/local/` theo `config/development.example.json` rồi truyền bằng `--dart-define-from-file`. `10.0.2.2` chỉ dành cho Android emulator; máy thật cần địa chỉ LAN/tunnel có thể truy cập từ điện thoại. Không cấu hình URL thì app báo lỗi rõ, không tự fallback. Release bắt buộc HTTPS; HTTP chỉ được Android debug cho phép để phát triển.

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/production.json
```

APK ở `build/app/outputs/flutter-apk/app-debug.apk`. Không đưa build/cache vào repo. Giữ `pubspec.lock` để tái lập dependency. Android ID phát triển `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; app name Moodify. ID phát hành, signing và OAuth chưa được chốt, chưa cấu hình release signing.

Repo đích được người dùng chỉ định: `Kandesfx/moodify-mobile`. Chỉ đưa nội dung dự án Flutter này lên repo, không đưa các checkout web/backend/React Native, media tải xuống hoặc APK/cache. Trạng thái bàn giao thực tế nằm ở `docs/ai/STATE.md`.

Điểm vào cho AI ở phiên sau: **“Đọc AGENTS.md, CONTEXT.md và STATE.md; tiếp tục milestone còn dở trong MIGRATION_PLAN, chuyển chức năng cũ trước khi mở rộng.”** Tài liệu chi tiết được tra theo SOURCE_MAP, không cần nạp toàn bộ workspace cũ mỗi phiên.
