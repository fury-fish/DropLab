import SwiftUI
import DropLabCore

public struct NotchTrayView: View {
    @ObservedObject var viewModel: NotchTrayViewModel

    public static let panelWidth: CGFloat = 560
    public static let panelHeight: CGFloat = 268

    public init(viewModel: NotchTrayViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.mode == .dropTargetReady {
                collapsedDropTargetPill
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if viewModel.mode == .expanded {
                expandedTrayView
                    .transition(.scale(scale: 0.92, anchor: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(width: Self.panelWidth, height: Self.panelHeight, alignment: .top)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: viewModel.mode)
        .animation(.spring(response: 0.20, dampingFraction: 0.82), value: viewModel.selectedSliceIndex)
        .animation(.spring(response: 0.18, dampingFraction: 0.84), value: viewModel.selectedPresetIndex)
    }

    // MARK: - Collapsed Drop Zone Pill

    private var collapsedDropTargetPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(viewModel.isHoveringDropZone ? Color.orange : Color.cyan)

            Text(
                viewModel.isHoveringDropZone
                    ? "Thả vào Lò Luyện Tai Thỏ để xử lý!"
                    : "Lò Luyện Tai Thỏ • Thả file vào đây"
            )
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 22,
                bottomTrailingRadius: 22,
                topTrailingRadius: 4,
                style: .continuous
            )
            .fill(Color(red: 0.06, green: 0.07, blue: 0.10).opacity(0.96))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 22,
                    bottomTrailingRadius: 22,
                    topTrailingRadius: 4,
                    style: .continuous
                )
                .stroke(
                    viewModel.isHoveringDropZone
                        ? Color.orange
                        : Color.cyan.opacity(0.65),
                    lineWidth: viewModel.isHoveringDropZone ? 2.2 : 1.3
                )
            )
            .shadow(
                color: (viewModel.isHoveringDropZone ? Color.orange : Color.cyan).opacity(0.45),
                radius: 14,
                y: 4
            )
        )
        .scaleEffect(viewModel.isHoveringDropZone ? 1.05 : 1.0)
    }

    // MARK: - Expanded Control Tray

    private var expandedTrayView: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            presetRow
            if let waveform = viewModel.waveform {
                InlineWaveformTrimmerView(viewModel: viewModel, summary: waveform)
            }
            footerRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: 536)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 6,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.98),
                        Color(red: 0.10, green: 0.11, blue: 0.16).opacity(0.97)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 6,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 24,
                    topTrailingRadius: 6,
                    style: .continuous
                )
                .stroke(Color.cyan.opacity(0.35), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 18, y: 8)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            // Source file pill
            HStack(spacing: 6) {
                let first = viewModel.sourceURLs.first
                let cat = first.map { FileCategory.detect(for: $0) } ?? .unknown
                Image(systemName: cat.systemSymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cyan)

                Text(first?.lastPathComponent ?? "File")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 145, alignment: .leading)

                if viewModel.sourceURLs.count > 1 {
                    Text("+\(viewModel.sourceURLs.count - 1)")
                        .font(.system(size: 10.5, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.cyan.opacity(0.25)))
                        .foregroundStyle(Color.cyan)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )

            Spacer()

            // Format Carousel (MP4 -> WAV -> M4A)
            HStack(spacing: 6) {
                ForEach(Array(viewModel.slices.enumerated()), id: \.offset) { idx, slice in
                    let isSelected = (idx == viewModel.selectedSliceIndex)
                    Button {
                        viewModel.selectSlice(at: idx)
                    } label: {
                        Text(slice.targetFormat.label)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.78))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        isSelected
                                            ? Color(red: 1.0, green: 0.72, blue: 0.12)
                                            : Color.white.opacity(0.08)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    if idx < viewModel.slices.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.32))
                    }
                }
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            Text("Tuỳ chọn:")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            ForEach(Array(viewModel.activePresets.enumerated()), id: \.offset) { idx, preset in
                let isSelected = (idx == viewModel.selectedPresetIndex)
                Button {
                    viewModel.selectedPresetIndex = idx
                    if preset == .trim8s && viewModel.waveform != nil {
                        viewModel.isTrimEnabled = true
                        viewModel.trimStartSeconds = 0
                        viewModel.trimEndSeconds = min(8.0, viewModel.waveform?.durationSeconds ?? 8.0)
                    }
                } label: {
                    Text(preset.displayTitle)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.orange : Color.white.opacity(0.75))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.orange.opacity(0.18) : Color.white.opacity(0.06))
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("Cuộn Trackpad / ← →")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    private var footerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(Color.orange)

            Text(viewModel.previewOutputFilename)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                viewModel.onClose?()
            } label: {
                Text("Đóng (Esc)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)

            Button {
                if let opts = viewModel.currentConversionOptions {
                    viewModel.onCommitConversion?(opts)
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Chuyển đổi")
                    Text("↵")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.76, blue: 0.18),
                                    Color(red: 1.0, green: 0.56, blue: 0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

/// Interactive Waveform Trimmer with gold amplitude bars and draggable start/end handles (`00:00 - 00:08`).
struct InlineWaveformTrimmerView: View {
    @ObservedObject var viewModel: NotchTrayViewModel
    let summary: WaveformSummary

    private let trackHeight: CGFloat = 54

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let totalWidth = max(1, geo.size.width)
                let duration = max(0.5, summary.durationSeconds)
                let startFraction = CGFloat(max(0, min(1, viewModel.trimStartSeconds / duration)))
                let endFraction = CGFloat(max(startFraction, min(1, viewModel.trimEndSeconds / duration)))
                let startX = startFraction * totalWidth
                let endX = endFraction * totalWidth

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    // Highlighted active trim window
                    if viewModel.isTrimEnabled {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: max(4, endX - startX), height: trackHeight - 8)
                            .offset(x: startX)
                    }

                    // Waveform bars
                    HStack(alignment: .center, spacing: 3) {
                        ForEach(Array(summary.peaks.enumerated()), id: \.offset) { idx, peak in
                            let barProgress = Double(idx) / Double(max(1, summary.peaks.count - 1))
                            let barSec = barProgress * duration
                            let inRange = !viewModel.isTrimEnabled ||
                                (barSec >= viewModel.trimStartSeconds && barSec <= viewModel.trimEndSeconds)

                            Capsule()
                                .fill(
                                    inRange
                                        ? Color(red: 1.0, green: 0.72, blue: 0.14)
                                        : Color.white.opacity(0.18)
                                )
                                .frame(
                                    width: 4,
                                    height: max(6, CGFloat(peak) * (trackHeight - 14))
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(width: totalWidth, height: trackHeight)

                    // Playhead line when previewing audio
                    if viewModel.isPlayingPreview {
                        let playheadFrac = CGFloat(max(0, min(1, viewModel.playbackPlayheadSeconds / duration)))
                        Rectangle()
                            .fill(Color.cyan)
                            .frame(width: 2, height: trackHeight - 6)
                            .offset(x: playheadFrac * totalWidth)
                    }

                    // Left & Right Yellow Trim Handles (matching Concept 2 image)
                    if viewModel.isTrimEnabled {
                        trimHandleView
                            .offset(x: max(0, startX - 6))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let frac = max(0, min(1, value.location.x / totalWidth))
                                        let newStart = Double(frac) * duration
                                        viewModel.trimStartSeconds = min(newStart, viewModel.trimEndSeconds - 0.5)
                                    }
                            )

                        trimHandleView
                            .offset(x: min(totalWidth - 12, max(0, endX - 6)))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let frac = max(0, min(1, value.location.x / totalWidth))
                                        let newEnd = Double(frac) * duration
                                        viewModel.trimEndSeconds = max(newEnd, viewModel.trimStartSeconds + 0.5)
                                    }
                            )
                    }
                }
            }
            .frame(height: trackHeight)

            // Waveform controls bar
            HStack(spacing: 10) {
                Toggle("Cắt đoạn (Trim):", isOn: $viewModel.isTrimEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                if viewModel.isTrimEnabled {
                    let cutDuration = max(0, viewModel.trimEndSeconds - viewModel.trimStartSeconds)
                    let startStr = NotchTrayViewModel.formatTimestamp(viewModel.trimStartSeconds)
                    let endStr = NotchTrayViewModel.formatTimestamp(viewModel.trimEndSeconds)
                    Text(String(format: "%.1fs (%@ - %@)", cutDuration, startStr, endStr))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.76, blue: 0.22))
                } else {
                    Text("Giữ nguyên toàn bộ (\(NotchTrayViewModel.formatTimestamp(summary.durationSeconds)))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Button {
                    viewModel.togglePreview()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isPlayingPreview ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(viewModel.isPlayingPreview ? "Dừng thử" : "Nghe thử (Space)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.isPlayingPreview ? Color.cyan : Color.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trimHandleView: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color(red: 1.0, green: 0.74, blue: 0.12))
            .frame(width: 11, height: trackHeight - 4)
            .overlay(
                VStack(spacing: 2) {
                    Capsule().fill(Color.black.opacity(0.55)).frame(width: 3, height: 10)
                }
            )
            .shadow(color: Color.black.opacity(0.45), radius: 3)
    }
}
