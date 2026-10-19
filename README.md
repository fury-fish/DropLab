<div align="center">

# 🌀 OrbitDrop (NotchAlchemy)
**Next-Gen Context-Aware File Converter & Quick Processor for macOS & iOS**  
*Công cụ chuyển đổi và xử lý file siêu tốc với trải nghiệm tương tác vật lý dành riêng cho hệ sinh thái Apple*

[![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B%20%7C%20iOS%2017%2B-000000?style=flat-square&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI%20%26%20AppKit-007AFF?style=flat-square&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

<br/>
<br/>

<img src="assets/concept-preview.png" alt="OrbitDrop Core Concepts" width="100%" />

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

**OrbitDrop** reimagines file conversion as an effortless, zero-window spatial gesture on **macOS** and **iOS**.

---

## ✨ Core Interaction Concepts / 2 Concept Tương Tác Cốt Lõi

Users can freely choose to enable **Concept 1**, **Concept 2**, or **both simultaneously** depending on their workflow.

*(Người dùng có thể tuỳ ý bật 1 trong 2 hoặc kết hợp cả 2 chế độ thao tác dưới đây)*

### 1. 🪐 Concept 1: Radial Orbit — Vòng Xoay Trọng Lực (macOS & iOS)

Convert files right where your cursor or finger is, without moving across the screen.  
*(Kéo và giữ nhẹ để chuyển đổi ngay tại chỗ)*

1. **Drag & Hold (Kéo & Giữ File):** Grab any file (e.g., `match.mp3`) and hold still for `0.4s` (or tap with a second finger on iOS).
2. **Context-Aware Pie Menu (Rê vào định dạng mong muốn):** A smart radial menu blooms right under your pointer, dynamically filtering only compatible target formats (`WAV`, `CAF`, `M4A`, `OGG`, `TXT`).
3. **Sub-Orbit Modifiers (Tuỳ chọn chuyên sâu):** Hovering over a primary slice like `WAV ->` expands an outer ring for instant technical presets: `LEI16`, `24-bit`, or `Cắt (Trim)`.
4. **Release to Convert (Thả tay để chuyển đổi):** Let go of the mouse/finger on your chosen slice, and `match_LEI16.wav` is generated instantly right next to the original file.

---

### 2. 🖤 Concept 2: Notch & Dynamic Island Alchemy — Lò Luyện Tai Thỏ (macOS & iOS)

Turn your device's hardware cutout into a tactile, fluid processing dock.  
*(Thả vào phần cứng để kích hoạt xử lý nhanh)*

* **On macOS (Notch Tray):**
  * **Drop into the Notch:** Drag `zapsplat_music.mp3` straight up into the MacBook Notch. The Notch morphs smoothly like liquid into a dark control tray.
  * **Trackpad Dial:** Scroll with two fingers on your Trackpad to cycle through target formats (`MP4 ➔ WAV ➔ M4A`).
  * **Inline Waveform Trimmer:** Need a quick cut? Adjust the yellow handles right inside the expanded Notch to trim the exact segment (e.g., `00:00 - 00:08`) with live audio preview before exporting.

* **On iOS (Dynamic Island):**
  * **Drag to Top:** Drag an image (`image.heic`) from Files or Photos toward the Dynamic Island.
  * **Swipe & Drop:** The Island expands into a format carousel (`PNG`, `WEBP`, `JPG`). Swipe horizontally with your thumb to select the target format and release.

---

## 🗂️ Supported Conversion Matrix / Ma trận Định dạng Hỗ trợ

| Category (Nhóm) | Input Formats (Đầu vào) | Intra-Group Targets (Cùng nhóm) | Cross-Group Targets (Chéo nhóm) | Quick Modifiers (Tham số nhanh) |
| --- | --- | --- | --- | --- |
| **🎵 Audio** | `mp3`, `wav`, `m4a`, `aac`, `ogg`, `flac`, `caf`, `aiff` | All audio formats | ➔ **Video:** `mp4`<br><br>➔ **Text:** `txt`, `srt` (Whisper) | `LEI16`, `24-bit`, `Trim (00:00-00:08)`, `Mono`, `Normalize` |
| **🖼️ Raster Image** | `png`, `jpg`, `webp`, `heic`, `avif`, `tiff`, `gif` | All image formats | ➔ **Icons:** `icns`, `ico`, `.appiconset`<br><br>➔ **Docs:** `pdf`, `txt` (OCR) | `Scale 1x/2x/3x`, `Quality 80%`, `Remove Alpha`, `SpriteSheet` |
| **✒️ Vector** | `svg`, `pdf`, `eps` | `svg` ⟷ `pdf` ⟷ `eps` | ➔ **Raster:** `png`, `webp`, `icns`<br><br>➔ **Code:** SwiftUI `Shape` | `DPI 72/150/300`, `Custom Dimension` |
| **🎬 Video** | `mp4`, `mov`, `webm`, `mkv`, `avi` | `mp4` ⟷ `mov` ⟷ `webm` | ➔ **Audio:** `mp3`, `wav`, `m4a`<br><br>➔ **Animated:** `gif`, `webp`, `png_seq` | `H.264/HEVC/ProRes`, `Trim`, `FPS 15/30/60`, `Mute Audio` |
| **📄 Document** | `pdf`, `md`, `html`, `docx`, `txt`, `rtf`, `epub` | `md` ⟷ `html` ⟷ `pdf` ⟷ `docx` | ➔ **Image:** Render pages to `png`, `jpg` | `Merge`, `Split Pages`, `Compress PDF` |
| **🧬 Data & Config** | `json`, `yaml`, `xml`, `plist`, `csv`, `tsv` | `json` ⟷ `yaml` ⟷ `xml` ⟷ `plist` | ➔ **Table:** `md`, `html` | `Minify`, `Prettify`, `Binary ⟷ XML Plist` |

---

## 🛠️ Native Tech Stack / Công nghệ Sử dụng

Built 100% natively for Apple Silicon (`M1/M2/M3/M4`) and iOS to achieve near-zero RAM overhead and instant startup:

* **UI & Animations:** `SwiftUI`, `AppKit` (`NSPanel` non-activating overlay for Notch & Radial Menu), `ActivityKit` (iOS Dynamic Island).
* **Type Inspection:** `UniformTypeIdentifiers` (`UTType`) for zero-latency format detection.
* **Audio Engine:** `CoreAudio`, `ExtAudioFileRef`, and `AVAssetReader`/`AVAssetWriter` (Native replacement for `afconvert` & `ffmpeg` audio trimming).
* **Image & Vector Engine:** `ImageIO` (`CGImageSource` / `CGImageDestination`) & `CoreGraphics` hardware-accelerated pipelines.
* **Video Engine:** `AVFoundation` (`AVAssetExportSession`) & `VideoToolbox`.

---

## 🗺️ Roadmap / Lộ trình Phát triển

* [x] UX/UI Concept & Conversion Matrix Architecture
* [ ] **Milestone 1 (macOS Core):** Global Drag-and-Drop listener + `Radial Orbit` Pie Menu overlay
* [ ] **Milestone 2 (Notch Engine):** MacBook Notch expansion window + Trackpad scroll gesture + Waveform trimmer
* [ ] **Milestone 3 (Native Converters):** Audio (`LEI16`, `CAF`, `WAV`, `MP3` + Trim) & Image (`HEIC`, `WEBP`, `PNG`, `ICNS`) pipelines
* [ ] **Milestone 4 (iOS Companion):** Action Extension + Dynamic Island Dropzone support

---

## 🤝 Feedback & Contributions / Đóng góp Ý kiến

This project is currently in the **Concept & Active Prototyping** stage.

Which interaction style do you prefer: **Radial Orbit (Concept 1)** or **Notch/Dynamic Island Alchemy (Concept 2)**? Feel free to open an [Issue](https://github.com/fury-fish/DropLab/issues) or join the discussion!
