import SwiftUI
import DropLabCore

/// Polar geometry and hit-testing for the 2-tier Radial Orbit menu.
public struct RadialOrbitGeometry {
    public static let canvasSize: CGFloat = 460
    public static let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)

    public static let hubRadius: CGFloat = 44
    public static let innerRingStart: CGFloat = 50
    public static let innerRingEnd: CGFloat = 128
    public static let outerRingStart: CGFloat = 136
    public static let outerRingEnd: CGFloat = 204
    public static let dismissRadius: CGFloat = 225

    public struct AngleSpan: Equatable, Sendable {
        public var startDegrees: Double
        public var endDegrees: Double

        public var midDegrees: Double {
            (startDegrees + endDegrees) * 0.5
        }

        public var spanDegrees: Double {
            endDegrees - startDegrees
        }

        public func contains(angleDegrees: Double) -> Bool {
            let norm = RadialOrbitGeometry.normalize(angleDegrees - startDegrees)
            return norm >= 0 && norm <= spanDegrees
        }
    }

    /// Normalizes an angle in degrees into `[0, 360)`.
    public static func normalize(_ degrees: Double) -> Double {
        let mod = degrees.truncatingRemainder(dividingBy: 360)
        return mod < 0 ? mod + 360 : mod
    }

    /// Computes the angle span for primary slice `index` out of `total` slices.
    /// Slice 0 is centered around the right-top (`-30°` / `330°`), matching the WAV slice in the concept art.
    public static func primarySliceSpan(index: Int, total: Int) -> AngleSpan {
        guard total > 0 else { return AngleSpan(startDegrees: 0, endDegrees: 360) }
        let step = 360.0 / Double(total)
        let startOffset = -step * 0.5
        let start = startOffset + Double(index) * step
        return AngleSpan(startDegrees: start, endDegrees: start + step)
    }

    /// Computes the angle span for sub-orbit preset `subIndex` out of `subTotal` around a parent primary slice.
    public static func subOrbitSliceSpan(
        parentIndex: Int,
        parentTotal: Int,
        subIndex: Int,
        subTotal: Int
    ) -> AngleSpan {
        let parent = primarySliceSpan(index: parentIndex, total: parentTotal)
        guard subTotal > 0 else { return parent }
        let totalArc = min(150.0, max(parent.spanDegrees, Double(subTotal) * 28.0))
        let step = totalArc / Double(subTotal)
        let start = parent.midDegrees - (totalArc * 0.5) + Double(subIndex) * step
        return AngleSpan(startDegrees: start, endDegrees: start + step)
    }

    /// Converts polar `(radius, angleDegrees)` to Cartesian `CGPoint` in the view's coordinate space.
    public static func point(radius: CGFloat, angleDegrees: Double) -> CGPoint {
        let rad = angleDegrees * .pi / 180.0
        return CGPoint(
            x: center.x + radius * CGFloat(cos(rad)),
            y: center.y + radius * CGFloat(sin(rad))
        )
    }

    /// Computes `(distance, angleDegrees)` from `center` to a point in view coordinates (`y` down).
    public static func polar(from pointInView: CGPoint) -> (distance: CGFloat, angleDegrees: Double) {
        let dx = pointInView.x - center.x
        let dy = pointInView.y - center.y
        let dist = hypot(dx, dy)
        let deg = atan2(Double(dy), Double(dx)) * 180.0 / .pi
        return (dist, normalize(deg))
    }
}

/// Draws an annular sector (donut slice) between `innerRadius` and `outerRadius` with a small angular gap.
public struct AnnularSectorShape: Shape {
    public var startDegrees: Double
    public var endDegrees: Double
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat
    public var gapDegrees: Double = 2.0

    public init(
        startDegrees: Double,
        endDegrees: Double,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        gapDegrees: Double = 2.0
    ) {
        self.startDegrees = startDegrees
        self.endDegrees = endDegrees
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.gapDegrees = gapDegrees
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let s = Angle.degrees(startDegrees + gapDegrees * 0.5)
        let e = Angle.degrees(endDegrees - gapDegrees * 0.5)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: s,
            endAngle: e,
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: e,
            endAngle: s,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
