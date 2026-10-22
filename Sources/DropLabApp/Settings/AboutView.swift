import SwiftUI
import DropLabCore

public struct AboutView: View {
    private let codecStatus = ExtendedCodecConverter.detectAvailableCodecs()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.10, green: 0.48, blue: 0.96),
                                        Color(red: 0.06, green: 0.14, blue: 0.32)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("DropLab 1.0.0 (macOS)")
                            .font(.title2.bold())
                        Text("Trợ lý Kéo & Thả Chuyển Đổi File Tức Thì • fury-fish")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trạng thái Codec Engine")
                        .font(.headline)

                    codecRow(
                        title: "Apple Native (AudioToolbox, AVFoundation, ImageIO, PDFKit)",
                        path: "Built-in macOS 14+",
                        isReady: true
                    )
                    codecRow(
                        title: "LAME MP3 Encoder (.mp3)",
                        path: codecStatus.lamePath ?? codecStatus.ffmpegPath ?? "Chưa tìm thấy",
                        isReady: codecStatus.hasMP3Support
                    )
                    codecRow(
                        title: "Google libwebp (.webp)",
                        path: codecStatus.cwebpPath ?? codecStatus.ffmpegPath ?? "Chưa tìm thấy",
                        isReady: codecStatus.hasWebPSupport
                    )
                    codecRow(
                        title: "FFmpeg Extended (.ogg, .flac, .webm)",
                        path: codecStatus.ffmpegPath ?? "Chưa tìm thấy",
                        isReady: codecStatus.hasFFmpegSupport
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Giấy phép Mã nguồn mở & Thư viện Bên thứ ba (Licenses)")
                        .font(.headline)

                    Text("""
                    • DropLab: Phát hành theo giấy phép MIT License — Copyright © 2026 fury-fish.
                    • LAME (libmp3lame): Phân phối theo giấy phép LGPL v2.0+ (https://lame.sourceforge.io).
                    • libwebp (cwebp): Phân phối theo giấy phép BSD 3-Clause License — Google Inc.
                    • FFmpeg / libvorbis / libopus / libvpx: Liên kết động theo giấy phép LGPL v2.1+ / BSD.
                    """)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 360)
    }

    private func codecRow(title: String, path: String, isReady: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? .green : .orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
