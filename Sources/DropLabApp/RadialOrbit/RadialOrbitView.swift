import SwiftUI
import DropLabCore

/// Observable view model driving the Radial Orbit overlay.
@MainActor
public final class RadialOrbitViewModel: ObservableObject {
    @Published public var sourceURLs: [URL] = []
    @Published public var slices: [OrbitSliceSpec] = []
    @Published public var hoveredSliceIndex: Int? = nil
    @Published public var hoveredSubPresetIndex: Int? = nil
    @Published public var isExpanded: Bool = false

    public var onSelectConversion: ((TargetFormat, ConversionPreset) -> Void)?
    public var onCancel: (() -> Void)?

    public init() {}

    public func configure(with urls: [URL]) {
        self.sourceURLs = urls
        self.slices = DropLabEngine.shared.registry.orbitSlices(for: urls)
        self.hoveredSliceIndex = nil
        self.hoveredSubPresetIndex = nil
    }

    public var activeSlice: OrbitSliceSpec? {
        guard let idx = hoveredSliceIndex, slices.indices.contains(idx) else { return nil }
        return slices[idx]
    }

    public var activePreset: ConversionPreset {
        guard let slice = activeSlice else { return .standard }
        if let subIdx = hoveredSubPresetIndex, slice.subOrbitPresets.indices.contains(subIdx) {
            return slice.subOrbitPresets[subIdx]
        }
        return slice.subOrbitPresets.first ?? .standard
    }

    public var previewOutputFilename: String? {
        guard let firstURL = sourceURLs.first, let slice = activeSlice else { return nil }
        let opts = ConversionOptions(targetFormat: slice.targetFormat, preset: activePreset)
        let outURL = SafeOutputNaming.makeOutputURL(for: firstURL, options: opts)
        if sourceURLs.count > 1 {
            return "\(outURL.lastPathComponent) (+\(sourceURLs.count - 1) file)"
        }
        return outURL.lastPathComponent
    }

    /// Updates hover state from a cursor point in view coordinates (`460x460`, `y` increasing downward).
    /// Returns `true` if the cursor has moved outside the dismiss radius (`> 225pt`).
    @discardableResult
    public func updateHover(at pointInView: CGPoint) -> Bool {
        let (dist, angleDeg) = RadialOrbitGeometry.polar(from: pointInView)

        if dist > RadialOrbitGeometry.dismissRadius {
            hoveredSliceIndex = nil
            hoveredSubPresetIndex = nil
            return true
        }

        if dist < RadialOrbitGeometry.innerRingStart {
            // Inside center hub: keep current primary slice open if user briefly passes near center,
            // or clear sub-preset selection.
            hoveredSubPresetIndex = nil
            return false
        }

        if dist <= RadialOrbitGeometry.innerRingEnd + 8 {
            // Inside Primary Inner Ring
            if hoveredSubPresetIndex != nil {
                hoveredSubPresetIndex = nil
            }
            for i in slices.indices {
                let span = RadialOrbitGeometry.primarySliceSpan(index: i, total: slices.count)
                if span.contains(angleDegrees: angleDeg) {
                    if hoveredSliceIndex != i {
                        hoveredSliceIndex = i
                        HapticEngine.sliceChanged()
                    }
                    return false
                }
            }
            return false
        }

        // Inside Outer Sub-Orbit Ring
        if let parentIdx = hoveredSliceIndex, slices.indices.contains(parentIdx) {
            let presets = slices[parentIdx].subOrbitPresets
            for subIdx in presets.indices {
                let span = RadialOrbitGeometry.subOrbitSliceSpan(
                    parentIndex: parentIdx,
                    parentTotal: slices.count,
                    subIndex: subIdx,
                    subTotal: presets.count
                )
                if span.contains(angleDegrees: angleDeg) {
                    if hoveredSubPresetIndex != subIdx {
                        hoveredSubPresetIndex = subIdx
                        HapticEngine.sliceChanged()
                    }
                    return false
                }
            }
            // If cursor moved radially to another primary slice's angular zone while in outer ring:
            for i in slices.indices {
                let span = RadialOrbitGeometry.primarySliceSpan(index: i, total: slices.count)
                if span.contains(angleDegrees: angleDeg) {
                    if hoveredSliceIndex != i {
                        hoveredSliceIndex = i
                        HapticEngine.sliceChanged()
                    }
                    hoveredSubPresetIndex = nil
                    return false
                }
            }
        } else {
            for i in slices.indices {
                let span = RadialOrbitGeometry.primarySliceSpan(index: i, total: slices.count)
                if span.contains(angleDegrees: angleDeg) {
                    hoveredSliceIndex = i
                    hoveredSubPresetIndex = nil
                    HapticEngine.sliceChanged()
                    return false
                }
            }
        }

        return false
    }
}

public struct RadialOrbitView: View {
    @ObservedObject var viewModel: RadialOrbitViewModel

    private let size = RadialOrbitGeometry.canvasSize

    public init(viewModel: RadialOrbitViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Subtle ambient dark backdrop ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.65),
                            Color(red: 0.07, green: 0.09, blue: 0.14).opacity(0.45),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: RadialOrbitGeometry.outerRingEnd + 16
                    )
                )
                .frame(width: size, height: size)

            // Outer Sub-Orbit Ring (Presets for active primary slice)
            if let parentIdx = viewModel.hoveredSliceIndex,
               viewModel.slices.indices.contains(parentIdx) {
                let presets = viewModel.slices[parentIdx].subOrbitPresets
                ForEach(Array(presets.enumerated()), id: \.offset) { subIdx, preset in
                    subOrbitSliceView(
                        parentIndex: parentIdx,
                        subIndex: subIdx,
                        subTotal: presets.count,
                        preset: preset,
                        isHovered: viewModel.hoveredSubPresetIndex == subIdx
                    )
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            // Inner Primary Orbit Ring (Target Formats)
            ForEach(Array(viewModel.slices.enumerated()), id: \.offset) { idx, slice in
                primarySliceView(
                    index: idx,
                    total: viewModel.slices.count,
                    slice: slice,
                    isHovered: viewModel.hoveredSliceIndex == idx
                )
            }

            // Center Hub (File Badge + Active Selection Readout so Finder's drag thumbnail never hides selection)
            centerHubView

            // Top & Bottom Live Selection HUD Pills
            VStack {
                if let activeSlice = viewModel.activeSlice {
                    topSelectionCalloutPill(slice: activeSlice, preset: viewModel.activePreset)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                previewFooterPill
                    .padding(.bottom, 6)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(viewModel.isExpanded ? 1.0 : 0.72)
        .opacity(viewModel.isExpanded ? 1.0 : 0.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: viewModel.isExpanded)
        .animation(.spring(response: 0.18, dampingFraction: 0.80), value: viewModel.hoveredSliceIndex)
        .animation(.spring(response: 0.15, dampingFraction: 0.82), value: viewModel.hoveredSubPresetIndex)
    }

    @ViewBuilder
    private func primarySliceView(
        index: Int,
        total: Int,
        slice: OrbitSliceSpec,
        isHovered: Bool
    ) -> some View {
        let span = RadialOrbitGeometry.primarySliceSpan(index: index, total: total)
        let sector = AnnularSectorShape(
            startDegrees: span.startDegrees,
            endDegrees: span.endDegrees,
            innerRadius: RadialOrbitGeometry.innerRingStart,
            outerRadius: isHovered ? RadialOrbitGeometry.innerRingEnd + 4 : RadialOrbitGeometry.innerRingEnd,
            gapDegrees: 2.2
        )
        let labelPos = RadialOrbitGeometry.point(
            radius: (RadialOrbitGeometry.innerRingStart + RadialOrbitGeometry.innerRingEnd) * 0.5,
            angleDegrees: span.midDegrees
        )

        ZStack {
            sector
                .fill(
                    LinearGradient(
                        colors: isHovered
                            ? [
                                Color(red: 1.0, green: 0.54, blue: 0.08).opacity(0.92),
                                Color(red: 0.85, green: 0.34, blue: 0.04).opacity(0.85)
                            ]
                            : [
                                Color(red: 0.16, green: 0.18, blue: 0.23).opacity(0.92),
                                Color(red: 0.11, green: 0.12, blue: 0.16).opacity(0.92)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    sector.stroke(
                        isHovered
                            ? Color(red: 1.0, green: 0.75, blue: 0.25)
                            : Color.white.opacity(0.14),
                        lineWidth: isHovered ? 2.2 : 1.0
                    )
                )
                .shadow(
                    color: isHovered ? Color.orange.opacity(0.55) : Color.black.opacity(0.35),
                    radius: isHovered ? 12 : 4
                )
                .onTapGesture {
                    let defaultPreset = slice.subOrbitPresets.first ?? .standard
                    viewModel.onSelectConversion?(slice.targetFormat, defaultPreset)
                }

            HStack(spacing: 3) {
                Text(slice.targetFormat.label)
                    .font(.system(size: isHovered ? 15 : 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isHovered ? Color.white : Color.white.opacity(0.86))
                if isHovered && !slice.subOrbitPresets.isEmpty {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.white)
                }
            }
            .position(labelPos)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func subOrbitSliceView(
        parentIndex: Int,
        subIndex: Int,
        subTotal: Int,
        preset: ConversionPreset,
        isHovered: Bool
    ) -> some View {
        let span = RadialOrbitGeometry.subOrbitSliceSpan(
            parentIndex: parentIndex,
            parentTotal: viewModel.slices.count,
            subIndex: subIndex,
            subTotal: subTotal
        )
        let sector = AnnularSectorShape(
            startDegrees: span.startDegrees,
            endDegrees: span.endDegrees,
            innerRadius: RadialOrbitGeometry.outerRingStart,
            outerRadius: isHovered ? RadialOrbitGeometry.outerRingEnd + 5 : RadialOrbitGeometry.outerRingEnd,
            gapDegrees: 2.0
        )
        let labelPos = RadialOrbitGeometry.point(
            radius: (RadialOrbitGeometry.outerRingStart + RadialOrbitGeometry.outerRingEnd) * 0.5,
            angleDegrees: span.midDegrees
        )

        ZStack {
            sector
                .fill(
                    LinearGradient(
                        colors: isHovered
                            ? [
                                Color(red: 1.0, green: 0.65, blue: 0.12).opacity(0.96),
                                Color(red: 0.92, green: 0.42, blue: 0.05).opacity(0.92)
                            ]
                            : [
                                Color(red: 0.20, green: 0.22, blue: 0.28).opacity(0.92),
                                Color(red: 0.14, green: 0.15, blue: 0.20).opacity(0.92)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    sector.stroke(
                        isHovered
                            ? Color(red: 1.0, green: 0.84, blue: 0.42)
                            : Color.orange.opacity(0.45),
                        lineWidth: isHovered ? 2.2 : 1.1
                    )
                )
                .shadow(
                    color: isHovered ? Color.orange.opacity(0.6) : Color.black.opacity(0.3),
                    radius: isHovered ? 10 : 3
                )
                .onTapGesture {
                    if let format = viewModel.activeSlice?.targetFormat {
                        viewModel.onSelectConversion?(format, preset)
                    }
                }

            Text(preset.displayTitle)
                .font(.system(size: isHovered ? 12.5 : 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? Color.white : Color(red: 1.0, green: 0.78, blue: 0.38))
                .position(labelPos)
                .allowsHitTesting(false)
        }
    }

    private var centerHubView: some View {
        let firstURL = viewModel.sourceURLs.first
        let ext = firstURL?.pathExtension.lowercased() ?? "file"
        let category = firstURL.map { FileCategory.detect(for: $0) } ?? .unknown
        let activeSlice = viewModel.activeSlice

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: activeSlice != nil
                            ? [
                                Color(red: 1.0, green: 0.56, blue: 0.10).opacity(0.48),
                                Color(red: 0.10, green: 0.11, blue: 0.18).opacity(0.96)
                            ]
                            : [
                                Color(red: 0.12, green: 0.55, blue: 0.98).opacity(0.42),
                                Color(red: 0.08, green: 0.11, blue: 0.18).opacity(0.95)
                            ],
                        center: .center,
                        startRadius: 4,
                        endRadius: RadialOrbitGeometry.hubRadius
                    )
                )
                .frame(
                    width: RadialOrbitGeometry.hubRadius * 2,
                    height: RadialOrbitGeometry.hubRadius * 2
                )
                .overlay(
                    Circle()
                        .stroke(
                            activeSlice != nil ? Color.orange.opacity(0.9) : Color.cyan.opacity(0.75),
                            lineWidth: 2.0
                        )
                )
                .shadow(
                    color: (activeSlice != nil ? Color.orange : Color.cyan).opacity(0.45),
                    radius: 10
                )

            if let slice = activeSlice {
                VStack(spacing: 1) {
                    Text(slice.targetFormat.label)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                    Text(viewModel.activePreset.displayTitle)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 6)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: category.systemSymbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    Text(".\(ext)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                    if viewModel.sourceURLs.count > 1 {
                        Text("\(viewModel.sourceURLs.count) files")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }
        }
        .position(RadialOrbitGeometry.center)
    }

    private func topSelectionCalloutPill(slice: OrbitSliceSpec, preset: ConversionPreset) -> some View {
        HStack(spacing: 6) {
            Text(slice.targetFormat.label)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.orange)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(preset.displayTitle)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.94))
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.55), lineWidth: 1.2)
                )
        )
    }

    private var previewFooterPill: some View {
        HStack(spacing: 6) {
            if let previewName = viewModel.previewOutputFilename {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.orange)
                Text(previewName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white)
                Text("• Thả tay để chuyển đổi")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
            } else {
                Text("Rê vào định dạng mong muốn • Rê ra ngoài / Esc để huỷ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.92))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}
