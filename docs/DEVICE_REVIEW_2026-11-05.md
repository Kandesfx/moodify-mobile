# Kiểm tra Samsung ngày 05/11/2026

Thiết bị SM-A235F, ADB R58TC0KWATX. Bản debug Android arm64 với config production, package dev.moodify.moodify_flutter. Cài update Success, cold launch Status ok. Package lastUpdateTime 05/11/2026 09:54:08 theo thiết bị. Không đăng nhập hoặc thực hiện mutation tài khoản trong lượt guest smoke này.

| Luồng | Quan sát thực tế |
| --- | --- |
| Home | Catalog/artwork thật hiển thị, 5 tab; chưa đánh giá profile/release frame timing |
| Playback | Chọn10NgànNăm mở mini/full; Android media-session PLAYING với position tăng; không dùng UI timer làm bằng chứng phát |
| Queue | Sheet24 bài; bỏ1000ÁnhMắt khỏi phần sắp phát còn23, bài10NgànNăm vẫn tiếp tục |
| Download guest | Nút tải mở login; bấm Back của form tới continuation vẫn hiển thị đúng10NgànNăm/PC và hành động đăng nhập tiếp |
| Artist | Từ menu mởPC, profile/list thực từ API, play/shuffle/follow/share và mini; follow guest mở login, chưa gửi follow mutation |
| Back regression | Sau loginBack, artist từng là root không có Back. Đã thêm Back fallback Home, build/cài lại; lặp lại artist→login→Back thấy Back còn, bấm về Home5tab được |
| Search | Tìm bằng chuỗi không dấu trả10NgànNăm. Automation nhập ban đầu bị mất ký tự1 do keyboard chưa sẵn sàng; chuỗi thực trong ảnh là0NganNam, không khẳng định toàn query10NganNam đã được nhập ở lượt này |
| Kết thúc | Home, mini paused; media session PAUSED position64766ms. Không tự login, tạo tài khoản, tải file hoặc thay quyền/giao dịch |

Ảnh/XML được lưu chọn lọc tại artifacts/device/20261105/ (Git ignore): home, player, queue, queue-removed, download-guest, continue-action, artist, artist-return, search-result, artist-back-fixed, home-after-back, final-home. Tên file chứa final biểu thị lượt capture, không có nghĩa đã nghiệm thu release.

Test cuối:94tests passed, format90files/0changed, debug APK build thành công (lượt cuối Gradle14,2s). Unit tests bổ sung artist/profile/follow và devices request; test navigation regression trong continuity_test. Logs artifacts/device-audit-*.txt ignored.

## Chưa kiểm chứng

User đã được hỏi có muốn tự đăng nhập để kiểm tra phần protected. Chưa có xác nhận/phiên đăng nhập trong lượt này. Download/Premium/quota/license, history account, favorite/playlist/follow, devices revoke, checkout chưa chạy thật. Sync lyrics entitlement, TalkBack, background interruption/Bluetooth, kill/restart offline, RAM/file lớn và release performance còn cần bằng chứng. Karaoke/ads vẫn theo scope cộng tác viên.

## Scope source vừa bổ sung

Artist profile/follow/followedLibrary, collection lazy/play-shuffle/share, devices list/revoke và account avatar. Search đa loại, recommendation và các mục còn lại chưa được thực hiện trong đợt này. Không đánh dấu toàn bộ khảo sát DONE. Không sửa backend/schema/DB, chưa commit/push.


## Lượt tài khoản thật sau người dùng tự đăng nhập

Người dùng tự đăng nhập và xác nhận. Không đọc credential/token. Màn subscription trả Tài khoản Miễn phí; không đăng ký gói, không thanh toán hoặc tự cấp Premium.

- Account, library4tab, followed empty và devices list tải được qua API thật. Device list đánh dấu Máy này, trạng thái hoạt động/thu hồi và1/1active; không bấm revoke. Không xóa lịch sử/mutation playlist/follow sẵn có.
- Search explicit10NganNam trả10NgànNăm; sau chọn kết quả và clear query, recent history có10NganNam thật. Không xóa mục đó trong thử nghiệm.
- Offline baseline0bài/0MB. Request tải10NgànNăm bị403 theo quyền tài khoản, không có completed file. UI ban đầu chỉ lỗi403chung + Retry không hữu ích; đã sửa mapping theo request context OFFLINE_FORBIDDEN (giữ DEVICE_REVOKED riêng), CTA xem gói/thiết bị thay retry trực tiếp, unit test thêm. Cài update và lặp lại trên máy thấy đúng CTA và0bài.
- Reporter debug chỉ log event/status/accepted, không token/ID/user/payload. PLAY và HEARTBEAT HTTP200 accepted=true, history tăng từ1→2mục. GET history không nhận diện bài. Source PlatformTrafficService.getUserListeningHistory đọc SQL track_id nhưng row mapper không gán `m.put("trackId", ...)`; enrichment sau đó lấy item.trackId=null, trả fallback Bài hát#track/MoodifyArtist và thiếu ID để client play. Đây là blocker backend có evidence, KHÔNG sửa backend/DB trong lượt Flutter. Không phát lại hoặc giả metadata cho hàng thiếu dữ liệu; UI đổi sang chưa nhận diện/thiếu thông tin server và khóa play.
- Giờ history hiển thị theo wall-time response server (03:xx), khác giờ máy10:xx; contract không có timezone, chưa tự dịch+7 hoặc tuyên bố đã chuẩn hóa UTC.

Artifacts local ignore: signed-subscription.xml, offline-baseline.xml, signed-search.xml, search-history-signed.xml, devices-signed.xml, history-after-accepted.xml, download-forbidden-fixed.xml/png. Chưa nghiệm thu tải thành công/bytes/cancel/verify/renew/phát offline vì tài khoản miễn phí. Các gate Premium/native vẫn mở. User session được giữ nguyên qua adb install-r.


Lượt signed-in sau sửa lỗi:95tests passed, analyze sạch, format90files; build/cài cuối xem thời gian package. UI từ chối tải bỏ empty-state hướng dẫn tải chung và Snackbar lỗi lặp khi lỗi cố định đã có trên trang. Đổi wording lịch sử thành chưa nhận diện/thiếu thông tin, không kết luận bài bị gỡ chỉ vì backend bỏ ID.

Đề xuất backend để xử lý blocker (chưa thực hiện): trong row mapper getUserListeningHistory gán `trackId` từ SQL `track_id` trước enrichment; regression test GET trả đúng ID/title cho session được tạo qua listening-session. Không cần schema mới. Cần nhiệm vụ sửa backend riêng trước khi thay source ngoài client.


Bản cuối của lượt signed-in: analyzeNoissues,95tests, format90files/0changed; Gradle38,9sPASS, adb install-rSuccess và cold start. Không tự logout; tài khoản được giữ. Sau cập nhật app vềHome và không tự phát lại nhạc. Không hứa đã sửa API metadata/history; blockerbackend giữ nguyên.
## Bản tải nhạc được thiết kế lại (14:48:59)

Build debug arm64 production-config, install-rSuccess. Samsung package lastUpdateTime2026-11-05 14:48:59, user session được giữ. Đã bỏ dialog phụ kiện USB không liên quan để kiểm tra app; không thay cài đặt thiết bị.

- Offline mở từ Account:0bản/0.0MiB, gói Tài khoản Miễn phí và thông báo không có quyền offline theo API thật. Thống kê gọn, quota0/0 ẩn vì không có quyền; empty state có Tìm nhạc để nghe.
- CTA Xem gói có quyền offline mở đúng Gói dịch vụ và gói hiện tại Miễn phí. Không chọn đăng ký/checkout, không thay quyền.
- Home chọn10NgànNăm, mở full player→Tải để nghe offline: tự mở Nhạc đã tải; task đầu trang giữ ảnh/tên/PC, trạng thái Cần xử lý, nêu gói chưa có quyền tải, có kiểm tra gói/thiết bị và đóng tác vụ.0bản/0.0MiB, không completed giả. Mini cùng coordinator vẫn hiển thị bài.
- Xem screenshot thực tế và chỉnh: thu gọn thống kê, bỏ dòng kỹ thuật file phát tạm, đặt task trước quota, giữ lỗi ở trang và bỏ retry trực tiếp khi thiếu quyền. Ảnh/XML local ignore: download-redesign-final-free.png/xml, download-redesign-final-blocked.png/xml, download-redesign-subscription-link.xml.

Source verification: analyze sạch;100tests passed, nhóm offline20tests cuối sau chỉnh spacing; format92files/0changed. Gradle cuối8,9sPASS. Logic tests xác minh không gọi ticket/media khi preflight thiếu quyền/full quota, hủy lúc chờ quyền, API quota lỗi không giả số0, UI320x640/text1.8 không overflow.

Chưa có bằng chứng tải Premium thành công, progress/cancel transfer thật, license/renew/phát mất mạng/native storage-full. Không sử dụng fixture trong app hay cấp quyền giả để lấp gate này. Không sửa backend/DB, chưa commit/push.

Kết thúc tại Nhạc đã tải với tác vụ thiếu quyền để user xem; bài thử10NgànNăm đã pause, UI hiển thị nút Phát. Giữ phiên đăng nhập. Không thấy dòng fatal/unhandled/overflow trong bộ lọc log AndroidRuntime/flutter của lượt kiểm tra cuối; đây chỉ là smoke, không thay native stress test.
