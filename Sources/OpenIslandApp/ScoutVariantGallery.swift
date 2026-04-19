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
    /// Accent pixel role (`G`) colour override. `.green` for happy states,
    /// `.red` for failure/interrupt, `nil` to use the default (green).
    var accent: Color? = nil
}

/// Renders an 8×8 B/H/E/W/G pattern into a pixel-art sprite without
/// going through `OpenIslandBrandMark`. Kept intentionally small so the
/// Lab can draw many candidates side-by-side cheaply.
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
        case "H": return tint.opacity(0.7)
        case "E": return Color.black.opacity(0.72)
        case "W": return tint.opacity(0.5)
        case "G": return accent.opacity(0.9)
        default:  return .clear
        }
    }
}

/// One row in the Lab: a candidate sprite at notch size (14 px) and a
/// blown-up preview (48 px) with its label underneath.
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
                .frame(width: 110)
        }
    }
}

/// A titled block of candidates for one phase. The Lab stacks several
/// of these so the user can scan across phases in one view.
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

enum ScoutVariantBank {
    // ── Completed candidates ─────────────────────────────────────────
    // The completed phase has gone through several revisions; all prior
    // drafts live here so the user can compare them directly against new
    // proposals at real 14 px size instead of imagining what each would
    // look like. Pick the winner in the Lab, then the chosen frame
    // graduates into `OpenIslandBrandMark.completedFrameA`.

    static let completedCandidates: [ScoutVariantSpec] = [
        ScoutVariantSpec(
            id: "completed.cheering",
            label: "A · 举手欢呼（当前）",
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
        ScoutVariantSpec(
            id: "completed.trophy",
            label: "B · 金奖杯",
            frame: [
                ".B....B.",
                "BBBBBBBB",
                "BHGGGGHB",
                "BHGGGGHB",
                ".BHHHHB.",
                "..BHHB..",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        ScoutVariantSpec(
            id: "completed.sparkleSmiley",
            label: "C · 笑脸+闪光",
            frame: [
                "H..BB..H",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                "B.HGGH.B",
                "B..GG..B",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        ScoutVariantSpec(
            id: "completed.partyHat",
            label: "D · 派对帽",
            frame: [
                "...BB...",
                "..BGGB..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                "B.HGGH.B",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        ScoutVariantSpec(
            id: "completed.crown",
            label: "E · 皇冠笑脸",
            frame: [
                ".B.BB.B.",
                "BBBBBBBB",
                "BBEBBEBB",
                "BBHHHHBB",
                "B.HGGH.B",
                "B..GG..B",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: .green
        ),
        ScoutVariantSpec(
            id: "completed.medal",
            label: "F · 胸前奖牌",
            frame: [
                "..BBBB..",
                ".BHEEHB.",
                ".BHHHHB.",
                ".BBBBBB.",
                "B.BGGB.B",
                "B.BGGB.B",
                "..BBBB..",
                ".B....B.",
            ],
            tint: .green
        ),
        ScoutVariantSpec(
            id: "completed.flag",
            label: "G · 举旗到达终点",
            frame: [
                "BGGB....",
                "BGGB....",
                "BGGBBBB.",
                "BBBEHEHB",
                "...BHHB.",
                "...BBBB.",
                "...BBBB.",
                "...B..B.",
            ],
            tint: .green
        ),
        ScoutVariantSpec(
            id: "completed.thumbsUp",
            label: "H · 竖大拇指",
            frame: [
                "..BBBB..",
                ".BHEEHB.",
                ".BHHHHB.",
                "..BBBB..",
                "BBBBBB..",
                "GBBBBB..",
                "GBBBBB..",
                "BBBB....",
            ],
            tint: .green
        ),
    ]

    // ── Approval candidates ──────────────────────────────────────────

    static let approvalCandidates: [ScoutVariantSpec] = [
        ScoutVariantSpec(
            id: "approval.guard",
            label: "A · 盾牌守卫（当前）",
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
        ScoutVariantSpec(
            id: "approval.stopHand",
            label: "B · 举手 STOP",
            frame: [
                "...B....",
                "..BBB...",
                ".BBBBB..",
                "..BHB...",
                "..BBB...",
                ".BBEEBB.",
                "BBHHHHBB",
                ".BBBBBB.",
            ],
            tint: .orange
        ),
        ScoutVariantSpec(
            id: "approval.bangBadge",
            label: "C · 胸前警示 !",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                ".BBBBBB.",
                "..BGB...",
                "..BGB...",
                "..B.B...",
            ],
            tint: .orange
        ),
        ScoutVariantSpec(
            id: "approval.gate",
            label: "D · 门卫挡住",
            frame: [
                "B......B",
                "BBBBBBBB",
                "BHEBBEHB",
                "BHHHHHHB",
                "B.BBBB.B",
                "B.BBBB.B",
                "B......B",
                "B......B",
            ],
            tint: .orange
        ),
    ]

    // ── Answer candidates ────────────────────────────────────────────

    static let answerCandidates: [ScoutVariantSpec] = [
        ScoutVariantSpec(
            id: "answer.cat",
            label: "A · 好奇猫咪（当前）",
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
        ScoutVariantSpec(
            id: "answer.raisedHand",
            label: "B · 举手提问",
            frame: [
                "...B....",
                "..BBB...",
                "..BBB...",
                "..BBBBBB",
                "..BHEHEB",
                "..BHHHHB",
                "..BBBBBB",
                "..B..B..",
            ],
            tint: .yellow
        ),
        ScoutVariantSpec(
            id: "answer.questionHead",
            label: "C · 头顶大问号",
            frame: [
                "..GGG...",
                ".G...G..",
                "....G...",
                "...G....",
                "..BBBB..",
                ".BHEEHB.",
                ".BHHHHB.",
                "..BBBB..",
            ],
            tint: .yellow
        ),
        ScoutVariantSpec(
            id: "answer.scratchHead",
            label: "D · 挠头思考",
            frame: [
                "...B....",
                "..BBB...",
                "..BBB...",
                ".BBEEBB.",
                "BBHHHHBB",
                ".BBBBBB.",
                "..B..B..",
                "........",
            ],
            tint: .yellow
        ),
    ]

    // ── Failed candidates ────────────────────────────────────────────

    static let failedCandidates: [ScoutVariantSpec] = [
        ScoutVariantSpec(
            id: "failed.crackedDome",
            label: "A · 头顶破裂（当前）",
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
        ScoutVariantSpec(
            id: "failed.xEyes",
            label: "B · X 眼（死掉）",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BGBBBGBB",
                "BBGBGBBB",
                "BGBBBGBB",
                "B..GG..B",
                ".BBBBBB.",
                "..BBBB..",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
        ScoutVariantSpec(
            id: "failed.fallen",
            label: "C · 倒下的 scout",
            frame: [
                "........",
                "........",
                "..BBBB..",
                ".BHEEHB.",
                "BHHHHHHB",
                ".BBBBBB.",
                "BBBGGBBB",
                ".B....B.",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
        ScoutVariantSpec(
            id: "failed.crackedRobot",
            label: "D · 裂开的机器人",
            frame: [
                ".B....B.",
                "BBBBBBBB",
                "BGEHBEGB",
                "BHHHHHHB",
                "BB.BB.BB",
                "..BBBB..",
                "B.B..B.B",
                ".B....B.",
            ],
            tint: Color(red: 0.95, green: 0.35, blue: 0.35),
            accent: .red
        ),
    ]

    // ── Interrupted candidates ───────────────────────────────────────

    static let interruptedCandidates: [ScoutVariantSpec] = [
        ScoutVariantSpec(
            id: "interrupted.redBar",
            label: "A · 红条拦腰（当前）",
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
        ScoutVariantSpec(
            id: "interrupted.stopPalm",
            label: "B · 举手暂停",
            frame: [
                "...GG...",
                "..GGGG..",
                "..GGGG..",
                "..GHHG..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                ".BBBBBB.",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25),
            accent: .red
        ),
        ScoutVariantSpec(
            id: "interrupted.frozen",
            label: "C · 被冻结（外层白壳）",
            frame: [
                "WWWWWWWW",
                "W.BBBB.W",
                "W.BEBB.W",
                "W.BBEH.W",
                "W.BHHB.W",
                "W.BBBB.W",
                "WWWWWWWW",
                "........",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25)
        ),
        ScoutVariantSpec(
            id: "interrupted.brokenLink",
            label: "D · 断裂的 scout",
            frame: [
                "..BBBB..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                ".B....B.",
                ".G....G.",
                "..BBBB..",
                ".B....B.",
            ],
            tint: Color(red: 0.95, green: 0.55, blue: 0.25),
            accent: .red
        ),
    ]

    // ── Subagent candidates ──────────────────────────────────────────

    static let subagentCandidates: [ScoutVariantSpec] = [
        ScoutVariantSpec(
            id: "subagent.twinRobots",
            label: "A · 双胞胎机器人（当前）",
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
        ScoutVariantSpec(
            id: "subagent.parentChild",
            label: "B · 大 scout 带小 scout",
            frame: [
                "...BB...",
                "..BEEB..",
                "..BBBB..",
                ".BBBBBB.",
                "BBEBBEBB",
                "BBHHHHBB",
                ".BBBBBB.",
                "..B..B..",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
        ScoutVariantSpec(
            id: "subagent.cloned",
            label: "C · scout + 分身虚影",
            frame: [
                "..BBBBHH",
                ".BBBBBHH",
                "BBEBBEHH",
                "BBHHHHHH",
                ".BBBBBHH",
                "..BBBBHH",
                "..B..BHH",
                "........",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
        ScoutVariantSpec(
            id: "subagent.spawning",
            label: "D · 头顶派生出小 scout",
            frame: [
                ".BB..BB.",
                ".BE..EB.",
                ".BB..BB.",
                "...BB...",
                "..BBBB..",
                ".BHEEHB.",
                ".BHHHHB.",
                "..BBBB..",
            ],
            tint: Color(red: 0.55, green: 0.85, blue: 0.95)
        ),
    ]
}
