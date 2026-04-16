import SwiftUI

/// Renders a pixel-art badge symbol at the same scale as the scout icon.
/// Place this to the right of `OpenIslandBrandMark` in an HStack.
struct ScoutBadgeView: View {
    let size: CGFloat
    let phase: OpenIslandBrandMark.ScoutPhase
    var tint: Color = .white

    private var badgePixels: [(x: Int, y: Int, role: Character)]? {
        // Reuse the precomputed badge pixel data from BrandMark
        let mark = OpenIslandBrandMark(size: size, phase: phase)
        return mark.currentBadgePixels
    }

    var body: some View {
        if let pixels = badgePixels {
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
            .frame(width: size, height: size)
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
        }
    }
}
