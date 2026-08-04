import SwiftUI

/// Dynamic Island shell: black upper lips extend to the screen edge, then
/// taper into a slightly narrower body.
struct NotchShellShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = min(topCornerRadius, rect.height / 3)
        let inset = min(top * 0.8, rect.width / 12)
        let bottom = min(bottomCornerRadius, rect.width / 3, rect.height / 2)
        let left = rect.minX + inset
        let right = rect.maxX - inset
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: right, y: rect.minY + top),
            control1: CGPoint(x: rect.maxX - inset * 0.45, y: rect.minY),
            control2: CGPoint(x: right, y: rect.minY + top * 0.45)
        )
        path.addLine(to: CGPoint(x: right, y: rect.maxY - bottom))
        path.addCurve(
            to: CGPoint(x: right - bottom, y: rect.maxY),
            control1: CGPoint(x: right, y: rect.maxY - bottom * 0.45),
            control2: CGPoint(x: right - bottom * 0.45, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: left + bottom, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: left, y: rect.maxY - bottom),
            control1: CGPoint(x: left + bottom * 0.45, y: rect.maxY),
            control2: CGPoint(x: left, y: rect.maxY - bottom * 0.45)
        )
        path.addLine(to: CGPoint(x: left, y: rect.minY + top))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: left, y: rect.minY + top * 0.45),
            control2: CGPoint(x: rect.minX + inset * 0.45, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
