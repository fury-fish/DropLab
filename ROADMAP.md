# 🗺️ DropLab — Roadmap (Locked) / Lộ trình đã chốt

> **Trạng thái:** ✅ Đã chốt plan — 2026-10-21. Chưa bắt đầu code; bước tiếp theo là **Phase 0**.
> Bản này thay cho roadmap 4 milestone ban đầu trong `README.md`.
> Mục tiêu: **ra được MVP macOS dùng thật sớm nhất**, xử lý các rủi ro kỹ thuật lớn trước khi làm UI đẹp.

## 0. Quyết định đã chốt / Decisions

| # | Hạng mục | Quyết định |
|---|---|---|
| D1 | Tên sản phẩm | **DropLab** (Swift package `DropLabCore`, CLI `droplab`) |
| D2 | Phân phối | **Developer ID + Notarization**, không sandbox (Mac App Store để sau) |
| D3 | Codec bên thứ ba | **Đồng ý** đóng gói LAME, libwebp, libopus/libvorbis, ffmpeg (bản LGPL, link động), kèm license trong About |
| D4 | Nền tảng ưu tiên | **macOS là chính**, iPhone/iPad là phụ. Mọi milestone đến 1.0 chỉ phục vụ macOS; iOS là companion sau 1.0 và có thể bị cắt/hoãn nếu ảnh hưởng chất lượng bản Mac |
| D5 | Ưu tiên giao diện | Làm **Vòng Xoay Trọng Lực (Radial Orbit — Concept 1) trước** ở M2 (MVP UI), sau đó mới làm **Notch Tray (Concept 2)** ở M3 |

---

## 1. Review kết quả — Các vấn đề của plan cũ

| # | Vấn đề trong plan cũ | Mức độ | Lý do | Cách sửa |
|---|---|---|---|---|
| 1 | **iOS: kéo file thả vào Dynamic Island** | 🔴 Không khả thi | Live Activity / Dynamic Island chỉ hiển thị, **không nhận drop**. App iOS cũng không được vẽ đè lên app khác (Files, Photos). | iOS dùng **Share/Action Extension** + **App Intents (Shortcuts)** + drop zone *bên trong app*. Dynamic Island chỉ dùng để **hiện tiến trình** convert. |
| 2 | **iOS: Radial Orbit "kéo & giữ" khi đang ở app khác** | 🔴 Không khả thi | Không có global gesture/overlay trên iOS. | Radial Orbit trên iOS chỉ hoạt động **trong app** (iPad: drag từ Files ở Split View vào app). |
| 3 | **"100% native"** cho MP3/OGG/WebP/WebM/MKV/AVIF/EPS | 🔴 Sai | AVFoundation/AudioToolbox **không encode MP3**, không hỗ trợ OGG/Vorbis, WebM, MKV. ImageIO **đọc** được WebP nhưng **không ghi**. macOS mới đã bỏ render EPS/PostScript. | Chia 2 tầng: **Native core** (mặc định) + **Extended codecs** (`libwebp`, `LAME`, `libvorbis/opus`, hoặc `ffmpeg` LGPL, link động). Ghi rõ trong ma trận định dạng. |
| 4 | **Thả vào Notch rồi cuộn Trackpad 2 ngón để chọn định dạng** | 🟠 Khó dùng | Đang giữ click để kéo + cuộn 2 ngón cùng lúc gần như không làm được trên trackpad. | **Thả trước → tray giữ file → chọn bằng scroll / click / phím mũi tên → Enter**. |
| 5 | **Xuất file "ngay cạnh file gốc"** | 🟠 Rủi ro phân phối | App Sandbox (Mac App Store) chỉ cấp quyền cho file được thả, **không cấp quyền ghi vào thư mục cha**. | Giai đoạn đầu phân phối **Developer ID + Notarization** (không sandbox). Nếu lên App Store sau: xin quyền thư mục 1 lần + security-scoped bookmark, fallback `~/Downloads/DropLab`. |
| 6 | **Làm cả 2 concept song song ngay từ M1–M2** | 🟠 Scope quá lớn | Hai cơ chế overlay khác nhau, nhân đôi chi phí UI/QA trước khi có converter chạy được. | MVP làm **Radial Orbit (Vòng xoay)** trước ở M2; **Notch Tray** làm ở M3. |
| 7 | **Notch chỉ có trên MacBook có tai thỏ** | 🟡 Thiếu | Mac mini/Studio, màn hình ngoài, MacBook Air Intel không có notch. | Fallback: **viên thuốc ẩn ở top-center** của màn hình đang chứa con trỏ. |
| 8 | **Phát hiện "global drag + hold 0.4s"** chưa được kiểm chứng | 🟡 Rủi ro | Cần theo dõi `NSPasteboard(name: .drag)` + global mouse monitor, phải không cản trở drag gốc và không gây giật. | Đưa vào **Phase 0 spike** trước khi cam kết UX Radial. |
| 9 | **Converter đặt ở M3, sau UI** | 🟡 Thứ tự sai | UI không có engine phía sau thì không demo/test được. | Làm **Conversion Engine + CLI** trước, UI gọi vào engine. |
| 10 | **Ma trận định dạng quá rộng** (EPUB, DOCX↔PDF, SVG→SwiftUI Shape, Whisper) | 🟡 Scope creep | Mỗi mục là một dự án con. | Chuyển sang **Backlog / Later**. |
| 11 | Thiếu phần **kiểm thử, hiệu năng, phân phối** | 🟡 Thiếu | Không có tiêu chí "Done". | Thêm Definition of Done cho mỗi milestone. |
| 12 | Tên không thống nhất: repo `DropLab` vs README `OrbitDrop (NotchAlchemy)` | 🟡 | Gây nhầm khi tạo bundle id, landing page. | ✅ Đã chốt tên **DropLab**. |

---

## 2. Lộ trình mới

```mermaid
flowchart LR
    P0["Phase 0 - Spikes"] --> M1["M1 - Engine + CLI"]
    M1 --> M2["M2 - Radial Orbit MVP"]
    M2 --> M3["M3 - Notch Tray"]
    M3 --> M4["M4 - Extended codecs + Trim"]
    M4 --> M5["M5 - Release 1.0 macOS"]
    M5 --> M6["M6 - iOS Companion"]
```

### Phase 0 — Technical Spikes (≈ 1 tuần)
Mục tiêu: trả lời "làm được không" trước khi viết code thật.
- [ ] Spike A: Phát hiện drag toàn cục (`NSPasteboard(name: .drag)` changeCount + `NSEvent.addGlobalMonitorForEvents(.leftMouseDragged)`), đo độ trễ và xác định hold 0.4s.
- [ ] Spike B: `NSPanel` non-activating ở vị trí notch (`NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`), nhận drop, không cướp focus app đang dùng.
- [ ] Spike C: Convert `mp3 → wav LEI16` và trim bằng `AVAssetReader/Writer`; `heic → png/jpg` bằng `ImageIO`.
- [ ] Spike D: Ghi file ra thư mục gốc khi chạy **không sandbox** + notarize thử.

**Done khi:** có báo cáo ngắn từng spike (OK / không OK / workaround).

### M1 — Conversion Engine + CLI (≈ 2 tuần)
- [ ] Swift Package `DropLabCore`: `Converter` protocol, registry theo `UTType` → danh sách đích hợp lệ.
- [ ] Converter native:
  - Audio: `wav`, `aiff`, `caf`, `m4a (AAC/ALAC)` + preset `LEI16`, `24-bit`, `Mono`, `Trim`.
  - Image: `heic`, `png`, `jpg`, `tiff`, `gif` + `Scale`, `Quality`, `Remove Alpha`; `png → icns`.
  - Data: `json ⟷ plist`, `minify/prettify`.
- [ ] CLI `droplab convert in.mp3 --to wav --preset lei16` (thay thế trực tiếp `afconvert`/`ffmpeg` trong workflow hiện tại).
- [ ] Đặt tên file đầu ra an toàn (không ghi đè: `match_LEI16.wav`, `match_LEI16 2.wav`).

**Done khi:** unit test cho mỗi cặp định dạng với file mẫu; convert ảnh 12MP < 300 ms, audio 3 phút < 1 s trên M1.

### M2 — Radial Orbit MVP (macOS) (≈ 2–3 tuần)
- [ ] App menu bar (`LSUIElement`), không có Dock icon.
- [ ] Phát hiện drag + hold 0.4s (từ Spike A), hiện pie menu `Radial Orbit` (`NSPanel` non-activating) ngay dưới con trỏ.
- [ ] Vòng trong: định dạng đích theo `UTType`; vòng ngoài (Sub-Orbit): preset (`LEI16`, `24-bit`, `Mono`, `Trim`...).
- [ ] Thả lên lát → convert và xuất ngay cạnh file gốc; thả ra ngoài / nhấn `Esc` → huỷ, drag gốc vẫn hoạt động bình thường.
- [ ] Phím tắt thay thế: chọn file trong Finder + hotkey → mở Radial Orbit ngay tại con trỏ.
- [ ] Hỗ trợ kéo **nhiều file** cùng lúc (batch), hiển thị tiến trình + Undo (xoá file vừa tạo).
- [ ] Settings cơ bản: thư mục xuất, preset mặc định, thời gian hold (`0.4s`), launch at login (`SMAppService`).

**Done khi:** dùng hằng ngày được cho workflow `mp3 → wav LEI16` và `heic → png` bằng vòng xoay tại con trỏ mà không mở cửa sổ nào, không làm hỏng drag & drop thông thường giữa các app (Finder, Safari, Xcode, Slack).

### M3 — Notch Tray (macOS) (≈ 2 tuần)
- [ ] Vùng drop ở notch; fallback viên thuốc top-center cho máy không notch / màn hình ngoài.
- [ ] Luồng: **thả file → tray mở → chọn định dạng (scroll / click / ← → / Enter) → xuất cạnh file gốc**.
- [ ] Tích hợp vào Settings để người dùng bật/tắt độc lập Radial Orbit, Notch Tray hoặc dùng cả hai cùng lúc.

**Done khi:** kéo thả vào Notch mượt mà trên cả màn hình MacBook có tai thỏ và màn hình rời.

### M4 — Extended Codecs + Waveform Trim (≈ 2–3 tuần)
- [ ] Gói codec mở rộng (tách module, link động, ghi license): `mp3` encode (LAME), `webp` encode (libwebp), `ogg/opus`, `webm`.
- [ ] Waveform trimmer trong tray (tay cầm vàng, preview audio, `00:00 - 00:08`).
- [ ] Video: `mov ⟷ mp4`, `H.264/HEVC/ProRes`, trích audio, `→ gif`.

**Done khi:** tất cả định dạng trong ma trận "Phase M4" chạy được, license bên thứ ba có trong About.

### M5 — Release 1.0 macOS (≈ 1–2 tuần)
- [ ] Notarization, DMG, auto-update (Sparkle), crash report.
- [ ] Onboarding xin quyền (nếu cần), landing page + GIF demo.

### M6 — iOS / iPadOS Companion (phụ, sau 1.0 — tuỳ chọn)
> Chỉ bắt đầu khi bản macOS 1.0 đã ổn định. Tái sử dụng `DropLabCore`; phạm vi tối thiểu.
- [ ] **Share/Action Extension**: "Convert with DropLab" từ Files/Photos.
- [ ] **App Intents** để dùng trong Shortcuts.
- [ ] Drop zone + Radial Orbit **trong app** (đặc biệt hữu ích trên iPad Split View).
- [ ] Live Activity / Dynamic Island hiển thị **tiến trình** convert (không nhận drop).

---

## 3. Backlog / Later
- Speech-to-text `audio → txt/srt` (Speech framework hoặc whisper.cpp).
- OCR `image → txt` (Vision).
- `md ⟷ html ⟷ pdf`, DOCX, EPUB, compress PDF.
- SVG → raster / SVG → SwiftUI `Shape`.
- Sprite sheet, `.appiconset` generator.
- Finder Quick Action / Services menu.
- Mac App Store build (sandbox + security-scoped bookmarks, fallback `~/Downloads/DropLab`).

## 4. Bước tiếp theo
- Bắt đầu **Phase 0 — Technical Spikes** khi có lệnh code. Mọi quyết định ở mục 0 đã chốt, không còn câu hỏi mở.
