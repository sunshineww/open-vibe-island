import SwiftUI

/// Renders a pixel-art badge symbol at the same scale as the scout icon.
/// Place this to the right of `OpenIslandBrandMark` in an HStack.
///
/// When the phase supports a multi-frame badge animation (currently only
/// `.thinking`'s typing-indicator dots), the view uses a `TimelineView`
/// to advance frames on a fixed cadence so the badge pulses alongside
/// the body sprite.
struct ScoutBadgeView: View {
    let size: CGFloat
    let phase: OpenIslandBrandMark.ScoutPhase
    var tint: Color = .white

    /// Phases whose badge changes across frames. Kept tiny — if the list
    /// grows, consider moving the "is animated?" flag onto ScoutPhase.
    private var badgeIsAnimated: Bool {
        phase == .thinking
    }

    /// Seconds per badge frame when animated. The thinking dots work
    /// best around 3 Hz — fast enough to register as motion at notch
    /// size, slow enough not to flicker.
    private static let frameInterval: TimeInterval = 0.32

    var body: some View {
        if badgeIsAnimated {
            TimelineView(.periodic(from: .now, by: Self.frameInterval)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / Self.frameInterval)
                let mark = OpenIslandBrandMark(size: size, phase: phase)
                if let pixels = mark.badgePixels(at: tick) {
                    pixelGrid(pixels)
                }
            }
            .frame(width: size, height: size)
        } else {
            let mark = OpenIslandBrandMark(size: size, phase: phase)
            if let pixels = mark.currentBadgePixels {
                pixelGrid(pixels)
                    .frame(width: size, height: size)
            }
        }
    }

    @ViewBuilder
    private func pixelGrid(_ pixels: [(x: Int, y: Int, role: Character)]) -> some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / 8, proxy.size.height / 8)
            let markWidth = cell * 8
            let markHeight = cell * 8
            let originX = (proxy.size.width - markWidth) / 2
            let originY = (proxy.size.height - markHeight) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(pixels.enumerated()), id: \.offset) { _, pixel in
                    Rectangle()
                        .fill(tint)
                        .frame(width: cell, height: cell)
                        .offset(
                            x: originX + CGFloat(pixel.x) * cell,
                            y: originY + CGFloat(pixel.y) * cell
                        )
                }
            }
        }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
    }
}
