# Trạng thái hiện tại

Cập nhật: **04/11/2026**. Snapshot hiện tại, không phải lịch sử hội thoại.

## Mã đã có

- Root riêng `D:\Hai\study\DATN\Moodify-Flutter`. Repo đích người dùng chỉ định: `Kandesfx/moodify-mobile`, nhánh `main`; đã kiểm tra remote rỗng trước bàn giao. Không sửa các repo cũ, không khởi động backend/DDL/seed/truy cập DB. Không chép secret/cache/APK lên Git.
- **M0 DONE**; **M1, M2, M5 và M6 IN_PROGRESS**; **M3, M4 và M7 NOT_STARTED**. Chưa nghiệm thu toàn migration hoặc phát hành production.
- M1: password login/register/profile/logout, device UUID, secure session theo API base, refresh single-flight/retry 401 một lần, terminal DEVICE_REVOKED, generation/cancel và serialize secure cleanup. Restore lỗi tạm thời giữ credential nhưng ẩn profile chưa xác minh; có retry/clear.
- M2: home mặc định cho guest như RN, shell 5 tab giữ trạng thái (Karaoke là tab thứ năm theo yêu cầu người dùng), return path nội bộ sau auth. Catalog/filter/phân trang/dedupe, album/artist detail, search thường debounce/cancel/stale guard và mood submit thật. Không random/mock catalog.
- M2 library: guest prompt; dữ liệu theo user; đọc liked/playlist, lưu/bỏ lưu bài, tạo playlist riêng tư/thêm bài. Chỉ xác nhận sau server, refresh sau mutation; không hiện user cũ sau session change. Chưa có toàn bộ CRUD.
- M2 player: một coordinator/engine lazy, stream chuẩn sau detail/localPath validation, redirect public không bearer. Mini/full/OS controls, play/pause/seek/next/previous, repeat, shuffle hữu hạn và history tối đa 100 mục, queue/plain lyrics. Native load serialize/generation; pause trong load không autoplay; logout/account change clear queue/stop.
- Main UI giữ cấu trúc RN (filter, quick access 2 cột, album/bài/nghệ sĩ, mini player trên tabbar); tab Karaoke riêng mở solo/phòng. Artwork thiếu trung tính; loại cover stock cứng; metadata tên hash hiển thị chưa có tên, không bịa tên.
- Karaoke solo: port theo web `KaraokeSoloPage`: chọn bài scorable thì xin quyền, tạo session, capture PCM16/YIN và phát; bài kết thúc tự gửi pitch features và hiện điểm. Nút chính trong lúc capture hủy bản thu như web; bài thiếu scoring reference chỉ phát. Mic-check riêng, không lưu raw audio. Lời highlight theo timeline/LRC có sẵn; plain lyrics thiếu timestamp hiện rõ là chưa đồng bộ. Chấm điểm nhóm giữ nguyên.
- Karaoke phòng: tạo/tham gia public/private, queue/host controls, nhạc đồng bộ qua snapshot API, lyrics, voice ticket + mediasoup/WebRTC signaling và mic, đóng góp pitch theo đoạn/chấm điểm nhóm. Tắt mic Voice khi ghi điểm để tránh hai luồng cùng chiếm microphone. Phòng cập nhật bằng REST polling mỗi 4 giây; chưa có Spring WebSocket state/reconnect parity.
- Android AudioServiceActivity/media service/permissions; iOS background audio + Keychain. Be Vietnam Pro TTF/OFL và logo thật, nguồn ở assets/README.md. App ID phát triển, chưa ký release.

## Bằng chứng kiểm chứng

| Kiểm tra | Kết quả 04/11/2026 |
| --- | --- |
| Toolchain | Flutter 3.41.6 / Dart 3.11.4, Java 21, Android minSdk 24 |
| Test | `flutter test --reporter expanded`: **53 tests passed** |
| Phạm vi test | 31 auth/config/session ban đầu; catalog envelopes/IDs/source/redirect; pagination dedupe/reset/error; search debounce/stale/mood empty; mutation chờ server/failure/dispose; player one-engine/OS callbacks/load races/pause/logout/completion/repeat/shuffle/seek/init retry; main + player/auth 320×640 text scale 1.8 không overflow |
| Analyze/format | `dart format --output=none --set-exit-if-changed lib test`: 49 files, 0 changed; `flutter analyze`: **No issues found** |
| APK | Build debug Android arm64 với config/production.json **PASS**, gồm audio packages/native service. Không phải bản release |
| Karaoke local | `dart format` các file Karaoke/shell/player; `flutter analyze` trên shell/router/Karaoke/player: **No issues found**. `flutter build apk --debug --no-pub --dart-define-from-file=config/development.example.json`: **PASS**, 57.1 giây, gồm màn hình lời Karaoke toàn trang. Tắt Kotlin incremental tạm thời trong Gradle rồi khôi phục file cấu hình. Chưa chạy Karaoke trên emulator hoặc API thật; voice/mic/scoring chưa có bằng chứng thiết bị. |
| Solo mic permission 04/11/2026 | `flutter analyze`: **No issues found**; APK debug development build **PASS**. Bấm Phát gọi quyền micro nhưng không khởi động recorder/session/score; từ chối quyền vẫn cho phát. Chưa chạy lại luồng trên emulator thật. |
| Karaoke solo redesign 04/11/2026 | `flutter analyze`: **No issues found**; APK debug development build **PASS**. Lyrics dùng `lyricTimeline`/LRC, highlight và scroll tới câu đang hát; `play()` không bị await tới hết bài, source-load timeout 25 giây; Next tự phát; mic stream có nút riêng và bỏ mẫu, không lưu/score. Chưa có runtime proof trên emulator sau lần sửa này. |
| Karaoke web-flow port 04/11/2026 | `flutter analyze`: **No issues found**; `flutter build apk --debug --no-pub --dart-define-from-file=config/development.example.json`: **PASS**. Đã nối solo session → pitch capture → submit features khi hết bài, stop hủy bản thu, track thiếu reference chỉ phát. Chưa chạy trên emulator/API thật sau thay đổi. |
| Samsung | SM-A235F, Android 14/API 34, arm64, adb R58TC0KWATX. Cài/launch bản cuối **PASS**; guest home/catalog/artwork render; search `Hoaprox` trả `Vô Tình — Xesi, Hoaprox`; không cần debug account |
| Audio trên máy | `10 Ngàn Năm`: PLAYING, position/buffer tiến thật; pause PAUSED; seek tới khoảng 144264 ms; HOME đưa app nền; OS media play trở lại PLAYING tới khoảng 160220 ms. Đã pause sau smoke test. Chưa chứng nhận nghe bằng tai/codec toàn catalog |
| API chỉ đọc | Catalog total 538; albums total 0; artists query list; stream 302 HTTPS; file hợp lệ Range 206 audio/mpeg. Không lưu payload user/token/URL signed |
| Media lỗi | `03 Hay Là`, `1-800-LOVE` có catalog nhưng media 404; `10 Ngàn Năm`, `1000 Ánh Mắt`, `2 4` Range 206. Player báo lỗi, không thay bằng bài khác |
| Playback diagnosis/fix 04/11/2026 | App local profile dùng `10.0.2.2:8088`; lỗi màn hình là backend chưa chạy. Backend local đã chạy trong phiên này với DDL/maintenance/seed/scheduler/Compose tắt; GET tracks/albums/artists đều 200. Backend source ưu tiên file local có thật; `03 Hay Là` vẫn không tìm thấy file trong root backend và redirect tới media production 404. 2 unit tests pass; emulator chưa được retry sau khi API lên. Production chưa deploy |
| Auth/library thật | **Chưa xác minh login/register và mutation thư viện thành công trên server thật**; không tự tạo user production. Fixture chỉ trong test |
| Mood/album detail | Có implementation theo controller; mood worker và album detail chưa xác minh tích hợp (album list hiện rỗng) |
| iOS/web/audio mở rộng | Chưa build/runtime iOS/web; Bluetooth, lock screen, interruption, mất mạng/phục hồi và release performance chưa nghiệm thu |

Ảnh local ở `artifacts/device/` có overlay điện thoại, bị ignore. APK `build/app/outputs/flutter-apk/app-debug.apk` cũng bị ignore. Không coi ảnh là thiết kế đã nghiệm thu.

## Giới hạn và phần tiếp theo

1. Hoàn tất M2: search history, favorite album, xóa bài/playlist/visibility, volume/sleep/share/synced lyrics. Chưa port entitlement/ad policy/listening telemetry: **blocker release**, không coi playback debug là quyền Premium hoặc bỏ quảng cáo đã được duyệt. Không gọi SANDBOX subscribe/dev-toggle.
2. Người dùng tự nhập tài khoản trên máy để xác minh auth, restore/logout, liked và playlist thật. Không yêu cầu gửi mật khẩu trong chat, không đánh dấu ACCEPTED từ fixture.
3. Kiểm tra native tiếp: skip/shuffle/repeat/completion trên máy (đã có unit), mất mạng, focus/interruption, lock screen, Bluetooth; iOS kiểm tra riêng khi có macOS/Xcode.
4. Production/local media có `03 Hay Là` trỏ tới đường dẫn HIEUTHUHAI và media 404; file chưa thấy trong root backend local. Chưa sửa dữ liệu production. Cần kiểm tra đường dẫn media đúng và xác nhận phát trên emulator. Resolver thiếu localPath vẫn còn fallback sai ở backend; Flutter chặn trước stream.
5. Hoàn thiện M5/M6: chạy karaoke trên Android với API đã cấu hình, kiểm tra quyền/mất mic/audio interruption, hai thiết bị voice/room, score thật và rời phòng; bổ sung room WebSocket state/reconnect trước nghiệm thu. iOS chỉ có quyền micro khai báo, chưa build/runtime.

## Môi trường và bàn giao

- Chạy tại root Flutter: `flutter run -d <device-id> --dart-define-from-file=config/production.json`. File này chỉ chứa APP_ENV/API URL public. Local config ở config/local theo example; emulator IP không dùng cho máy thật. Không bật backend cũ.
- Dependency khóa bằng pubspec.lock: Riverpod 2.6.1, go_router 17.5.0, Dio 5.11.1, secure storage 11.2.0, uuid 4.6.0, just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, record 6.2.1, mediasfu_mediasoup_client 0.1.4. Không thêm app DB/schema; sqflite là package cache gián tiếp.
- Android ID `dev.moodify.moodify_flutter`, iOS `dev.moodify.moodifyFlutter`; chưa chốt ID/OAuth/signing release. Social cần config app mới; backend bỏ qua genre đăng ký USER.
- Gradle 8.14.3-bin đã đối chiếu checksum official; AGP 8.11.1/Kotlin 2.2.20. Lần build audio đầu có Kotlin incremental cache lỗi khác ổ C:/D:, compiler fallback và APK vẫn PASS; lần sau PASS khoảng 35 giây. Doctor thiếu cmdline-tools/license status unknown; không tự chấp nhận license.
- Bàn giao Git theo yêu cầu người dùng; xem commit/remote thực tế bằng Git và thông báo kết quả, không ghi lịch sử chat vào đây. Giữ AGENTS/CONTEXT/STATE ngắn; đọc source qua SOURCE_MAP; mở root Flutter riêng để tránh index workspace cũ.
