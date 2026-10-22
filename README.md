<div align="center">

# 🧪 DropLab
**Next-Gen Context-Aware File Converter & Quick Processor for macOS** *(iPhone/iPad companion later)*  
*Công cụ chuyển đổi và xử lý file siêu tốc cho macOS — bản iPhone/iPad là phụ, làm sau*

[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-000000?style=flat-square&logo=apple)](https://apple.com)
[![Companion](https://img.shields.io/badge/Companion-iOS%2017%2B%20%28later%29-8E8E93?style=flat-square&logo=apple)](ROADMAP.md)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI%20%26%20AppKit-007AFF?style=flat-square&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

<br/>
<br/>

<img src="assets/concept-preview.png" alt="DropLab Core Concepts" width="100%" />

</div>

---

## 💡 The Problem / Bài toán thực tế

Developers, designers, and indie makers constantly convert and tweak files every day—whether converting `.mp3` game audio into `LEI16 .wav`, trimming the first 8 seconds of a sound effect, or batch-converting `.heic` photos into `.webp`.

Traditional file converters force you through tedious steps (**Open App ➔ Browse ➔ Select Dropdown ➔ Choose Output Folder ➔ Export**), while CLI commands (`afconvert`, `ffmpeg`) require memorizing complex flags:

```bash
# Traditional CLI workflow we want to replace:
afconvert -f WAVE -d LEI16 input.mp3 match.wav
ffmpeg -i magic-potion.wav -ss 00:00:00 -to 00:00:08 -c copy magic-potion-1.wav
```

**DropLab** reimagines file conversion as an effortless, zero-window spatial gesture on **macOS** — with a lightweight iPhone/iPad companion planned after 1.0.

---

## ✨ Core Interaction Concepts / 2 Concept Tương Tác Cốt Lõi

Users can freely choose to enable **Concept 1**, **Concept 2**, or **both simultaneously** depending on their workflow.

*(Người dùng có thể tuỳ ý bật 1 trong 2 hoặc kết hợp cả 2 chế độ thao tác dưới đây)*

### 1. 🪐 Concept 1: Radial Orbit — Vòng Xoay Trọng Lực (macOS; in-app on iPad)

Convert files right where your cursor or finger is, without moving across the screen.  
*(Kéo và giữ nhẹ để chuyển đổi ngay tại chỗ)*

1. **Drag & Hold (Kéo & Giữ File):** Grab any file (e.g., `match.mp3`) and hold still for `0.4s`. Alternative: select files in Finder and press a global hotkey.
2. **Context-Aware Pie Menu (Rê vào định dạng mong muốn):** A smart radial menu blooms right under your pointer, dynamically filtering only compatible target formats (`WAV`, `CAF`, `M4A`, `OGG`, `TXT`).
3. **Sub-Orbit Modifiers (Tuỳ chọn chuyên sâu):** Hovering over a primary slice like `WAV ->` expands an outer ring for instant technical presets: `LEI16`, `24-bit`, or `Cắt (Trim)`.
4. **Release to Convert (Thả tay để chuyển đổi):** Let go of the mouse/finger on your chosen slice, and `match_LEI16.wav` is generated instantly right next to the original file.

---

### 2. 🖤 Concept 2: Notch Alchemy — Lò Luyện Tai Thỏ (macOS) + iOS Companion

Turn your device's hardware cutout into a tactile, fluid processing dock.  
*(Thả vào phần cứng để kích hoạt xử lý nhanh)*

* **On macOS (Notch Tray):**
  * **Drop into the Notch:** Drag `zapsplat_music.mp3` straight up into the MacBook Notch. The Notch morphs smoothly like liquid into a dark control tray that holds the file.
  * **Pick a Format:** After dropping, scroll with two fingers on your Trackpad (or use `←` `→` / click) to cycle through target formats (`MP4 ➔ WAV ➔ M4A`), then press `Enter`.
  * **Inline Waveform Trimmer:** Need a quick cut? Adjust the yellow handles right inside the expanded Notch to trim the exact segment (e.g., `00:00 - 00:08`) with live audio preview before exporting.
  * **No notch?** On Macs without a notch or on external displays, a hidden pill at the top-center of the screen acts as the drop zone.

* **On iOS / iPadOS (Secondary companion, after macOS 1.0):**
  * iOS does not allow third-party apps to accept drops on the Dynamic Island or to draw over other apps. *(iOS không cho phép thả file vào Dynamic Island hay vẽ đè lên app khác.)*
  * **Share / Action Extension:** Select `image.heic` in Files or Photos ➔ Share ➔ **Convert with DropLab** ➔ swipe through a format carousel (`PNG`, `WEBP`, `JPG`).
  * **In-app Drop Zone & Shortcuts:** Drop files into the app (great with iPad Split View) or automate with App Intents.
  * **Dynamic Island:** Shows live conversion progress via a Live Activity.

---

## 🗂️ Supported Conversion Matrix / Ma trận Định dạng Hỗ trợ

Legend: **✅ Native** (Apple frameworks only) · **🧩 Extended** (bundled open-source codec, e.g. LAME / libwebp / ffmpeg-LGPL) · **🕒 Later** (backlog)

| Category (Nhóm) | ✅ Native (M1–M2) | 🧩 Extended (M4) | 🕒 Later | Quick Modifiers (Tham số nhanh) |
| --- | --- | --- | --- | --- |
| **🎵 Audio** | `wav`, `aiff`, `caf`, `m4a` (AAC/ALAC) ⟷ each other; decode `mp3`, `flac` | Encode `mp3`, `ogg`/`opus`, `flac` | ➔ `txt`/`srt` (speech-to-text) | `LEI16`, `24-bit`, `Mono`, `Trim (00:00-00:08)`, `Normalize` |
| **🖼️ Raster Image** | `heic`, `png`, `jpg`, `tiff`, `gif` ⟷ each other; decode `webp`, `avif`; `png ➔ icns` | Encode `webp`, `avif`; `ico` | OCR ➔ `txt`, `.appiconset`, SpriteSheet | `Scale 1x/2x/3x`, `Quality 80%`, `Remove Alpha` |
| **🎬 Video** | `mov` ⟷ `mp4` (`H.264/HEVC/ProRes`), extract audio ➔ `m4a`/`wav` | `webm`, `mkv`, `avi`, ➔ `gif`/`webp` animated | `png_seq` | `Trim`, `FPS 15/30/60`, `Mute Audio` |
| **✒️ Vector** | `pdf` ➔ `png`/`jpg` | `svg` ➔ raster | `eps`, SVG ➔ SwiftUI `Shape` | `DPI 72/150/300`, `Custom Dimension` |
| **📄 Document** | `pdf` pages ➔ image, merge/split PDF | — | `md` ⟷ `html` ⟷ `pdf` ⟷ `docx`, `epub` | `Merge`, `Split Pages`, `Compress PDF` |
| **🧬 Data & Config** | `json` ⟷ `plist` (binary/XML), `csv` ⟷ `tsv` | `yaml` | ➔ Markdown/HTML table | `Minify`, `Prettify` |

---

## 🛠️ Tech Stack / Công nghệ Sử dụng

Native-first for Apple Silicon to keep RAM overhead low and startup instant. Formats Apple frameworks cannot encode are handled by an optional, dynamically linked codec module.

* **UI & Animations:** `SwiftUI`, `AppKit` (`NSPanel` non-activating overlay for Notch & Radial Menu); iOS: Share/Action Extension, `App Intents`, `ActivityKit` (progress only).
* **Drag Detection (macOS):** `NSPasteboard(name: .drag)` + global mouse event monitor.
* **Type Inspection:** `UniformTypeIdentifiers` (`UTType`) for zero-latency format detection.
* **Audio Engine:** `AudioToolbox` (`ExtAudioFile`), `AVAssetReader`/`AVAssetWriter` (native replacement for `afconvert` & `ffmpeg` trimming).
* **Image Engine:** `ImageIO` (`CGImageSource` / `CGImageDestination`) & `CoreGraphics`.
* **Video Engine:** `AVFoundation` (`AVAssetExportSession`) & `VideoToolbox`.
* **Extended Codecs (optional):** LAME (`mp3`), libwebp (`webp`), libopus/libvorbis, ffmpeg (LGPL build) for `webm`/`mkv`.
* **Distribution:** Developer ID + Notarization (non-sandboxed, so output can be written next to the source file).

---

## 🗺️ Roadmap / Lộ trình Phát triển

> ✅ Plan locked (2026-10-21). Full plan with decisions, review notes & Definition of Done: **[ROADMAP.md](ROADMAP.md)**

* [x] UX/UI Concept & Conversion Matrix Architecture
* [x] **Phase 0 (Spikes):** Validate global drag detection, non-activating `NSPanel` drop target, native audio/image conversion, non-sandboxed output
* [x] **M1 (Engine + CLI):** `DropLabCore` Swift package + `droplab` CLI — native audio (`LEI16`, `24-bit`, `Trim`) & image (`HEIC`, `PNG`, `JPG`, `ICNS`)
* [x] **M2 (Radial Orbit MVP):** Menu bar app, drag & hold `0.4s` pie menu with sub-orbit presets, demo & file picker triggers, batch + Undo
* [x] **M3 (Notch Tray + Waveform Trimmer):** Drop into notch (top-center pill fallback) ➔ Trackpad scroll / arrow keys format picker + inline waveform trimmer with live audio preview ➔ export
* [ ] **M4 (Extended Codecs + Trim UI):** `MP3`/`WEBP`/`OGG`/`WEBM` encoders, waveform trimmer, video basics
* [ ] **M5 (Release 1.0 macOS):** Notarized DMG, Sparkle auto-update, onboarding
* [ ] **M6 (iOS/iPadOS Companion — secondary, optional):** Share/Action Extension, App Intents, in-app drop zone, Live Activity progress

---

## 🤝 Feedback & Contributions / Đóng góp Ý kiến

This project is in the **Plan Locked** stage — roadmap finalized, implementation starts with Phase 0.

Which interaction style do you prefer: **Radial Orbit (Concept 1)** or **Notch Alchemy (Concept 2)**? Feel free to open an [Issue](https://github.com/fury-fish/DropLab/issues) or join the discussion!
