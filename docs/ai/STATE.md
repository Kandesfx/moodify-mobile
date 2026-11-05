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
