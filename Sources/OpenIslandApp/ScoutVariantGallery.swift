import SwiftUI

/// A candidate 8×8 scout sprite shown in the Lab for A/B selection.
///
/// The Lab surfaces multiple drafts per phase so the user can eyeball
/// which silhouette works best at real notch size. Picking a winner is
/// out-of-band — the user tells the dev, who then swaps the frame into
/// `OpenIslandBrandMark`.
struct ScoutVariantSpec: Identifiable {
    let id: String
    let label: String
    let frame: [String]
    let tint: Color
    /// Accent pixel role (`G`) colour override. When `nil`, green is used.
    var accent: Color? = nil
}

/// Renders an 8×8 B/H/E/W/G pattern into a pixel-art sprite without
/// going through `OpenIslandBrandMark`.
struct ScoutVariantPixelView: View {
    let frame: [String]
    let size: CGFloat
    let tint: Color
    var accent: Color = .green

    private var pixels: [(x: Int, y: Int, role: Character)] {
        frame.enumerated().flatMap { rowIndex, row in
            row.enumerated().compactMap { columnIndex, character in
                character == "." ? nil : (columnIndex, rowIndex, character)
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / 8, proxy.size.height / 8)
            let markWidth = cell * 8
            let markHeight = cell * 8
            let originX = (proxy.size.width - markWidth) / 2
            let originY = (proxy.size.height - markHeight) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(pixels.enumerated()), id: \.offset) { _, pixel in
                    Rectangle()
                        .fill(color(for: pixel.role))
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

    private func color(for role: Character) -> Color {
        switch role {
        case "B": return tint.opacity(0.95)
        case "H": return tint.opacity(0.55)
        case "E": return Color.black.opacity(0.78)
        case "W": return Color.white.opacity(0.9)
        case "G": return accent.opacity(0.95)
        case "Y": return Color.yellow.opacity(0.95)
        default:  return .clear
        }
    }
}

struct ScoutVariantRow: View {
    let spec: ScoutVariantSpec

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                ScoutVariantPixelView(frame: spec.frame, size: 14, tint: spec.tint, accent: spec.accent ?? .green)
                    .frame(width: 14, height: 14)
                    .padding(4)
                    .background(Color.black, in: Capsule())

                ScoutVariantPixelView(frame: spec.frame, size: 48, tint: spec.tint, accent: spec.accent ?? .green)
                    .frame(width: 48, height: 48)
            }

            Text(spec.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(width: 120)
        }
    }
}

struct ScoutVariantGallery: View {
    let title: String
    let subtitle: String
    let variants: [ScoutVariantSpec]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(variants) { spec in
                        ScoutVariantRow(spec: spec)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Candidate sprite bank
//
// Every candidate is modelled on a *widely recognised* 8-bit / pixel-art
// icon so the reading is unambiguous at 14 px — trophy, star, ? block,
// skull, pause bars, etc. Bespoke "scout in a pose" drafts have been
// removed.
//
// Role keys:
//   B — body (phase tint)
//   H — highlight (softer tint)
//   E — dark (outline / shadow / eye hole)
//   W — bright white (for skull teeth, pause gaps)
//   G — accent (green for happy, red for failed/interrupted)
//   Y — yellow (used by the coin / ? block Mario icons)

enum ScoutVariantBank {

    // MARK: Completed

    static let completedCandidates: [ScoutVariantSpec] = [
        // 1. Classic cup trophy with two side handles.
        ScoutVariantSpec(
            id: "completed.trophy",
            label: "A · 金奖杯",
            frame: [
                ".B....B.",
                "BBBBBBBB",
                "BHHHHHHB",
                "BHHHHHHB",
                ".BHHHHB.",
                "..BHHB..",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        // 2. Five-point star (Mario power-up / "win" star).
        ScoutVariantSpec(
            id: "completed.star5",
            label: "B · 5 角星",
            frame: [
                "...BB...",
                "...BB...",
                "BBBBBBBB",
                ".BBBBBB.",
                "..BBBB..",
                "..BBBB..",
                ".BB..BB.",
                ".B....B.",
            ],
            tint: .green
        ),
        // 3. Sparkle burst — 4-point diamond star with radial rays.
        ScoutVariantSpec(
            id: "completed.sparkle",
            label: "C · 闪光爆炸",
            frame: [
                "...BB...",
                ".B.BB.B.",
                "..BBBB..",
                "BBBBBBBB",
                "BBBBBBBB",
                "..BBBB..",
                ".B.BB.B.",
                "...BB...",
            ],
            tint: .green
        ),
        // 4. 1UP mushroom — red cap with white spots in the original,
        //    rendered here with highlight (H) spots on the tint body.
        ScoutVariantSpec(
            id: "completed.mushroom",
            label: "D · 1UP 蘑菇",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "B.BHHB.B",
                "BBBBBBBB",
                "BBHHHHBB",
                "BBEBBEBB",
                ".BHHHHB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        // 5. Coin — concentric circles with a highlight stripe.
        ScoutVariantSpec(
            id: "completed.coin",
            label: "E · 金币",
            frame: [
                "..BBBB..",
                ".BBHHBB.",
                "BBBHHBBB",
                "BBBHHBBB",
                "BBBHHBBB",
                "BBBHHBBB",
                ".BBHHBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        // 6. Medal with ribbon triangle on top.
        ScoutVariantSpec(
            id: "completed.medal",
            label: "F · 奖牌（带缎带）",
            frame: [
                ".B....B.",
                ".BB..BB.",
                "..BBBB..",
                ".BBBBBB.",
                "BBHHHHBB",
                "BBHHHHBB",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        // 7. Treasure chest with lid ajar and shine rays.
        ScoutVariantSpec(
            id: "completed.chest",
            label: "G · 宝箱开启",
            frame: [
                "...HH...",
                ".H.BB.H.",
                ".BBBBBB.",
                "B......B",
                "BBBBBBBB",
                "BEBBBBEB",
                "BBBBBBBB",
                ".BBBBBB.",
            ],
            tint: .green
        ),
        // 8. Current "cheering scout" (kept for fairness).
        ScoutVariantSpec(
            id: "completed.cheering",
            label: "H · 举手欢呼（之前）",
            frame: [
                "B......B",
                ".BB..BB.",
                "..BBBB..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                "B.HGGH.B",
                ".B.BB.B.",
            ],
            tint: .green
        ),
    ]

    // MARK: Waiting for Approval

    static let approvalCandidates: [ScoutVariantSpec] = [
        // 1. Classic Mario "!" block — yellow square with a centered mark.
        ScoutVariantSpec(
            id: "approval.bangBlock",
            label: "A · ! 砖块（Mario ! Block）",
            frame: [
                "BBBBBBBB",
                "BHHHHHHB",
                "BHHEEHHB",
                "BHHEEHHB",
                "BHHEEHHB",
                "BHHHHHHB",
                "BHHEEHHB",
                "BBBBBBBB",
            ],
            tint: .orange
        ),
        // 2. Octagonal STOP sign silhouette.
        ScoutVariantSpec(
            id: "approval.stopSign",
            label: "B · STOP 八边形",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBBBBBBB",
                "BBWWWWBB",
                "BBWWWWBB",
                "BBBBBBBB",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .orange
        ),
        // 3. Raised palm (hand signalling "halt").
        ScoutVariantSpec(
            id: "approval.palm",
            label: "C · 手掌 HALT",
            frame: [
                "B.B.B.B.",
                "BBBBBBB.",
                "BBBBBBB.",
                "BBBBBBB.",
                ".BBBBBB.",
                ".BBBBBB.",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .orange
        ),
        // 4. Heraldic shield — "access control".
        ScoutVariantSpec(
            id: "approval.shield",
            label: "D · 盾牌",
            frame: [
                "BBBBBBBB",
                "BHHHHHHB",
                "BHHHHHHB",
                "BHH..HHB",
                "BHH..HHB",
                ".BHHHHB.",
                "..BHHB..",
                "...BB...",
            ],
            tint: .orange
        ),
        // 5. Current scout-as-guard (for reference).
        ScoutVariantSpec(
            id: "approval.guard",
            label: "E · 盾牌守卫（之前）",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBHEEHBB",
                "BBHHHBBB",
                ".BBBBBB.",
                "..BBBB..",
                ".B.BB.B.",
                "........",
            ],
            tint: .orange
        ),
    ]

    // MARK: Waiting for Answer

    static let answerCandidates: [ScoutVariantSpec] = [
        // 1. Classic Mario "?" block.
        ScoutVariantSpec(
            id: "answer.questionBlock",
            label: "A · ? 砖块（Mario ? Block）",
            frame: [
                "BBBBBBBB",
                "BHHHHHHB",
                "BHEEEEHB",
                "BHHHHEHB",
                "BHHHEHHB",
                "BHHHHHHB",
                "BHHHEHHB",
                "BBBBBBBB",
            ],
            tint: .yellow
        ),
        // 2. Speech bubble with "?" in the middle.
        ScoutVariantSpec(
            id: "answer.speechBubble",
            label: "B · 问号气泡",
            frame: [
                "BBBBBBB.",
                "BEEEEEB.",
                "BE..EEB.",
                "BEEEEEB.",
                "BE.EEEB.",
                "BEEEEEB.",
                "BBBBB.B.",
                "....BB..",
            ],
            tint: .yellow
        ),
        // 3. Raised hand (asking).
        ScoutVariantSpec(
            id: "answer.raisedHand",
            label: "C · 举手提问",
            frame: [
                "B.B.B.B.",
                "BBBBBBB.",
                "BBBBBBB.",
                ".BBBBBB.",
                ".BBBBBB.",
                "..BBBB..",
                "..BBBB..",
                "..B..B..",
            ],
            tint: .yellow
        ),
        // 4. Current cat-curious (for reference).
        ScoutVariantSpec(
            id: "answer.cat",
            label: "D · 好奇猫咪（之前）",
            frame: [
                "B......B",
                "BB....BB",
                "BBBBBBBB",
                "BHEWWEHB",
                "BBHHHHBB",
                ".BBBBBB.",
                "..B..B..",
                "........",
            ],
            tint: .yellow
        ),
    ]

    // MARK: Failed

    static let failedCandidates: [ScoutVariantSpec] = [
        // 1. Classic skull — hollow eye sockets, teeth row.
        ScoutVariantSpec(
            id: "failed.skull",
            label: "A · 骷髅头",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBBBBBBB",
                "BEEBBEEB",
                "BEEBBEEB",
                "BBBBBBBB",
                ".B.BB.B.",
                ".BWBWBWB",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
        // 2. Broken heart — heart split down the middle.
        ScoutVariantSpec(
            id: "failed.brokenHeart",
            label: "B · 碎心",
            frame: [
                ".BB..BB.",
                "BBBBBBBB",
                "BBBWWBBB",
                "BBWBBWBB",
                ".BWBBWB.",
                "..WBBW..",
                "...WW...",
                "........",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
        // 3. "X" eyes scout (classic dead cartoon).
        ScoutVariantSpec(
            id: "failed.xEyes",
            label: "C · X 眼 scout",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BEBBBEBB",
                "BBEBEBBB",
                "BEBBBEBB",
                "BBHHHHBB",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
        // 4. Ghost Pac-Man "eyes only" — classic defeat visual where
        //    the ghost body vanishes and only its eyes flee home.
        ScoutVariantSpec(
            id: "failed.pacGhostEyes",
            label: "D · 只剩眼睛（GameOver）",
            frame: [
                "........",
                "........",
                "..BB.BB.",
                "..BB.BB.",
                "..EE.EE.",
                "........",
                "........",
                "........",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
        // 5. Cracked scout (current).
        ScoutVariantSpec(
            id: "failed.crackedDome",
            label: "E · 破顶笑脸（之前）",
            frame: [
                "..B..B..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                "B..GG..B",
                "B.GBBG.B",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
    ]

    // MARK: Interrupted

    static let interruptedCandidates: [ScoutVariantSpec] = [
        // 1. Universal pause icon — two thick vertical bars.
        ScoutVariantSpec(
            id: "interrupted.pauseBars",
            label: "A · 暂停键 ⏸",
            frame: [
                "........",
                ".BBB.BBB",
                ".BBB.BBB",
                ".BBB.BBB",
                ".BBB.BBB",
                ".BBB.BBB",
                ".BBB.BBB",
                "........",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25)
        ),
        // 2. Stop sign (octagon, solid) in interrupt tint.
        ScoutVariantSpec(
            id: "interrupted.stopSign",
            label: "B · 停止标志",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBBBBBBB",
                "BWWWWWWB",
                "BWWWWWWB",
                "BBBBBBBB",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25)
        ),
        // 3. Power button (circle with a gap + bar) — universal stop.
        ScoutVariantSpec(
            id: "interrupted.powerButton",
            label: "C · 电源按钮",
            frame: [
                "...BB...",
                ".BBBBBB.",
                "BB.BB.BB",
                "BB.BB.BB",
                "BB....BB",
                "BB....BB",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25)
        ),
        // 4. Red bar through scout (current).
        ScoutVariantSpec(
            id: "interrupted.redBar",
            label: "D · 红条拦腰（之前）",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                "GGGGGGGG",
                "..BBBB..",
                ".BB..BB.",
                "........",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25),
            accent: .red
        ),
    ]

    // MARK: Subagent

    static let subagentCandidates: [ScoutVariantSpec] = [
        // 1. Twin pixel sprites — two Invaders side-by-side.
        ScoutVariantSpec(
            id: "subagent.twinInvaders",
            label: "A · 双入侵者",
            frame: [
                "B.B..B.B",
                ".BB..BB.",
                "BBB..BBB",
                "BEB..BEB",
                ".BB..BB.",
                "B.B..B.B",
                "B......B",
                "B......B",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
        // 2. Parent + child — scout with a small scout on its shoulder.
        ScoutVariantSpec(
            id: "subagent.parentChild",
            label: "B · 肩负小 scout",
            frame: [
                ".BB.....",
                ".EB.....",
                ".BBBBBB.",
                "BBBBBBBB",
                "BBEBBEBB",
                "BBHHHHBB",
                ".BBBBBB.",
                "..B..B..",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
        // 3. Two-player controller layout — classic arcade "2P" icon.
        ScoutVariantSpec(
            id: "subagent.twoPlayer",
            label: "C · 2P 双人控制器",
            frame: [
                "........",
                ".BBBBBBB",
                "BB.EE.BB",
                "BB.EE.BB",
                ".BBBBBBB",
                "BB.HH.BB",
                "BB.HH.BB",
                ".BBBBBBB",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
        // 4. Current twin robots (for reference).
        ScoutVariantSpec(
            id: "subagent.twinRobots",
            label: "D · 双胞胎机器人（之前）",
            frame: [
                ".B....B.",
                "BBBBBBBB",
                "BEHBBHEB",
                "BHHHHHHB",
                ".BBBBBB.",
                ".BBBBBB.",
                "..B..B..",
                ".B....B.",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
    ]
}
