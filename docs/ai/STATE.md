# Trạng thái hiện tại

Cập nhật: **04/11/2026**. Snapshot hiện tại, không phải lịch sử hội thoại.

## Mã đã có

- Root riêng `D:\Hai\study\DATN\Moodify-Flutter`. Repo đích người dùng chỉ định: `Kandesfx/moodify-mobile`, nhánh `main`; đã kiểm tra remote rỗng trước bàn giao. Không sửa các repo cũ, không khởi động backend/DDL/seed/truy cập DB. Không chép secret/cache/APK lên Git.
- **M0 DONE**; **M1 và M2 IN_PROGRESS**; **M3–M7 NOT_STARTED**. Chưa nghiệm thu toàn migration hoặc phát hành production.
- M1: password login/register/profile/logout, device UUID, secure session theo API base, refresh single-flight/retry 401 một lần, terminal DEVICE_REVOKED, generation/cancel và serialize secure cleanup. Restore lỗi tạm thời giữ credential nhưng ẩn profile chưa xác minh; có retry/clear.
- M2: home mặc định cho guest như RN, shell 4 tab giữ trạng thái, return path nội bộ sau auth. Catalog/filter/phân trang/dedupe, album/artist detail, search thường debounce/cancel/stale guard và mood submit thật. Không random/mock catalog.
- M2 library: guest prompt; dữ liệu theo user; đọc liked/playlist, lưu/bỏ lưu bài, tạo playlist riêng tư/thêm bài. Chỉ xác nhận sau server, refresh sau mutation; không hiện user cũ sau session change. Chưa có toàn bộ CRUD.
- M2 player: một coordinator/engine lazy, stream chuẩn sau detail/localPath validation, redirect public không bearer. Mini/full/OS controls, play/pause/seek/next/previous, repeat, shuffle hữu hạn và history tối đa 100 mục, queue/plain lyrics. Native load serialize/generation; pause trong load không autoplay; logout/account change clear queue/stop.
- Main UI giữ cấu trúc RN (filter, quick access 2 cột, album/bài/nghệ sĩ, mini player trên tabbar). Không thêm CTA karaoke/thông báo/settings chưa port. Artwork thiếu trung tính; loại cover stock cứng; metadata tên hash hiển thị chưa có tên, không bịa tên.
- Android AudioServiceActivity/media service/permissions; iOS background audio + Keychain. Be Vietnam Pro TTF/OFL và logo thật, nguồn ở assets/README.md. App ID phát triển, chưa ký release.

## Bằng chứng kiểm chứng

| Kiểm tra | Kết quả 04/11/2026 |
| --- | --- |
| Toolchain | Flutter 3.41.6 / Dart 3.11.4, Java 21, Android minSdk 24 |
| Test | `flutter test --reporter expanded`: **53 tests passed** |
| Phạm vi test | 31 auth/config/session ban đầu; catalog envelopes/IDs/source/redirect; pagination dedupe/reset/error; search debounce/stale/mood empty; mutation chờ server/failure/dispose; player one-engine/OS callbacks/load races/pause/logout/completion/repeat/shuffle/seek/init retry; main + player/auth 320×640 text scale 1.8 không overflow |
| Analyze/format | `dart format --output=none --set-exit-if-changed lib test`: 49 files, 0 changed; `flutter analyze`: **No issues found** |
| APK | Build debug Android arm64 với config/production.json **PASS**, gồm audio packages/native service. Không phải bản release |
| Samsung | SM-A235F, Android 14/API 34, arm64, adb R58TC0KWATX. Cài/launch bản cuối **PASS**; guest home/catalog/artwork render; search `Hoaprox` trả `Vô Tình — Xesi, Hoaprox`; không cần debug account |
| Audio trên máy | `10 Ngàn Năm`: PLAYING, position/buffer tiến thật; pause PAUSED; seek tới khoảng 144264 ms; HOME đưa app nền; OS media play trở lại PLAYING tới khoảng 160220 ms. Đã pause sau smoke test. Chưa chứng nhận nghe bằng tai/codec toàn catalog |
| API chỉ đọc | Catalog total 538; albums total 0; artists query list; stream 302 HTTPS; file hợp lệ Range 206 audio/mpeg. Không lưu payload user/token/URL signed |
| Media lỗi | `03 Hay Là`, `1-800-LOVE` có catalog nhưng media 404; `10 Ngàn Năm`, `1000 Ánh Mắt`, `2 4` Range 206. Player báo lỗi, không thay bằng bài khác |
| Auth/library thật | **Chưa xác minh login/register và mutation thư viện thành công trên server thật**; không tự tạo user production. Fixture chỉ trong test |
| Mood/album detail | Có implementation theo controller; mood worker và album detail chưa xác minh tích hợp (album list hiện rỗng) |
| iOS/web/audio mở rộng | Chưa build/runtime iOS/web; Bluetooth, lock screen, interruption, mất mạng/phục hồi và release performance chưa nghiệm thu |

Ảnh local ở `artifacts/device/` có overlay điện thoại, bị ignore. APK `build/app/outputs/flutter-apk/app-debug.apk` cũng bị ignore. Không coi ảnh là thiết kế đã nghiệm thu.

## Giới hạn và phần tiếp theo

1. Hoàn tất M2: search history, favorite album, xóa bài/playlist/visibility, volume/sleep/share/synced lyrics. Chưa port entitlement/ad policy/listening telemetry: **blocker release**, không coi playback debug là quyền Premium hoặc bỏ quảng cáo đã được duyệt. Không gọi SANDBOX subscribe/dev-toggle.
2. Người dùng tự nhập tài khoản trên máy để xác minh auth, restore/logout, liked và playlist thật. Không yêu cầu gửi mật khẩu trong chat, không đánh dấu ACCEPTED từ fixture.
3. Kiểm tra native tiếp: skip/shuffle/repeat/completion trên máy (đã có unit), mất mạng, focus/interruption, lock screen, Bluetooth; iOS kiểm tra riêng khi có macOS/Xcode.
4. Media catalog có file thiếu và metadata hash: không sửa DB để che lỗi; đọc API/detail để xác định source, ghi blocker theo bài. Resolver thiếu localPath có fallback sai vẫn còn ở backend; Flutter chặn trước stream.
5. M3–M7 tiếp tục theo MIGRATION_PLAN sau parity cũ. Chưa thêm payment/offline/karaoke hoặc chức năng mở rộng web vào UI chính.

## Môi trường và bàn giao

- Chạy tại root Flutter: `flutter run -d <device-id> --dart-define-from-file=config/production.json`. File này chỉ chứa APP_ENV/API URL public. Local config ở config/local theo example; emulator IP không dùng cho máy thật. Không bật backend cũ.
- Dependency khóa bằng pubspec.lock: Riverpod 2.6.1, go_router 17.5.0, Dio 5.11.1, secure storage 11.2.0, uuid 4.6.0, just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4. Không thêm app DB/schema; sqflite là package cache gián tiếp.
- Android ID `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; chưa chốt ID/OAuth/signing release. Social cần config app mới; backend bỏ qua genre đăng ký USER.
- Gradle 8.14.3-bin đã đối chiếu checksum official; AGP 8.11.1/Kotlin 2.2.20. Lần build audio đầu có Kotlin incremental cache lỗi khác ổ C:/D:, compiler fallback và APK vẫn PASS; lần sau PASS khoảng 35 giây. Doctor thiếu cmdline-tools/license status unknown; không tự chấp nhận license.
- Bàn giao Git theo yêu cầu người dùng; xem commit/remote thực tế bằng Git và thông báo kết quả, không ghi lịch sử chat vào đây. Giữ AGENTS/CONTEXT/STATE ngắn; đọc source qua SOURCE_MAP; mở root Flutter riêng để tránh index workspace cũ.
