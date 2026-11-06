# Cập nhật GitHub và Samsung — 06/11/2026

## Nguồn và bảo toàn thay đổi

- Người dùng yêu cầu lấy code mới rồi chạy trên điện thoại. `main` fast-forward từ a456a11 tới origin/main06b3c27f713ab47f483411a321b879d8fe999883, gồm4commit mới. Không push hoặc commit mới trong lượt này.
- Giữ toàn bộ lyrics/splash local và native launch chưa commit bằng stash `pre-update-20261106-preserve-lyrics-splash`, object871813d9421fa2b07954643089016f427c10b735. Đã apply, giải xung đột DECISIONS/player_sheets/continuity_test và trả index về unstaged. Stash vẫn giữ làm bản sao, không drop/reset/clean worktree.
- Hợp nhất profile/checkout/karaoke/ads/OAuth và root-navigator sheet từ remote với fullscreen lyrics/splash local. Theo remote, LRC cho mọi người dùng kể cả guest, không gate Premium. Parse lyricsSynced hoặc lyricsPlain nếu thật sự có timestamp; không sinh mốc lời. Trong ads, màn lyrics không seek/highlight cue bài chờ; transport vẫn dùng một coordinator.

## Kiểm chứng code

| Kiểm tra | Kết quả |
| --- | --- |
| Dependencies | flutter pub get PASS, giữ pubspec.lock của nhánh mới |
| Test | 134tests passed, bao gồm regression guest LRC legacy/plain và khóa seek lyrics trong quảng cáo |
| Analyze cuối | No issues found,14,5s |
| Format |108files; chuẩn hóa8file upstream, lần kiểm tra cuối0changed |
| Whitespace/conflict |diff check sạch, git ls-files-u rỗng |
| APK |debug arm64, config/production.json, PASS117,4s |

Build có cảnh báo Kotlin incremental cache khác ổ C:/D: và compiler fallback, nhưng APK hoàn tất. Không đổi Gradle, xóa cache diện rộng hoặc khởi động backend để né cảnh báo. APK/log/artifact bị ignore; không sửa backend/catalog/DB.

## Cài thiết bị và quan sát ban đầu

- Samsung SM-A235F, ADB R58TC0KWATX; adb install-rSuccess, package lastUpdateTime2026-11-06 09:17:59. Cài cập nhật, không uninstall/clear data hoặc tự logout.
- am start-W báo timeout/LaunchStateUNKNOWN sau11,3s; screenshot và XML sau đó xác nhận app ở foreground, Home/catalog/artwork/tab hiện thật. Không dùng con số này làm benchmark startup hoặc báo launch Statusok.
- Có hoạt động nghe nhạc và chuyển auth trên máy trong lúc kiểm tra, vì vậy không coi mọi thao tác/track tại thời điểm này là do agent hoặc đã được nghiệm thu. UIAutomator từng báo could-not-get-idle khi audio đang chạy; file account.xml kéo sau lỗi đó là bản cũ, không dùng làm bằng chứng account. start.xml/png và account-2.xml/auth-current.png là các capture được ghi riêng; không đưa profile/credential vào báo cáo.
- API public đọc lại sample Như Phút Ban Đầu, Noo Phước Thịnh, ID88f8fc3c3ae7e27d02b6f18a: duration256001ms,40cue LRC và plain hiện có. Đây là chuẩn bị bài thử, chưa chứng minh native lyrics đã chạy đúng. Không khẳng định toàn catalog đã được căn đúng.
- Đã hỏi phối hợp thao tác để tránh chồng nhau. Người dùng chọn tự đăng nhập. Agent tạm ngừng thao tác điện thoại trong lúc nhập thông tin; chờ xác nhận đã đăng nhập để chạy tiếp.

## Còn phải thử sau khi người dùng giao lại máy

Phát sample có LRC, mở fullscreen lyrics, chạm cue/seek, active line và vị trí engine, manual/recenter/Back; profile chỉ đọc, library/history/offline đúng trạng thái thật; sheet không bị mini/tab đè. Không checkout/đổi password/profile/revoke/xóa dữ liệu tài khoản để smoke. Tải thành công vẫn cần offline entitlement thật. OAuth, karaoke mic/room nhiều máy/voice/scoring, ad-policy các gói, iOS và performance profile chưa nghiệm thu bởi lượt cài này.
