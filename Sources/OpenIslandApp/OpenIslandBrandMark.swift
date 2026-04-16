import SwiftUI

struct OpenIslandBrandMark: View {
    enum Style {
        case duotone
        case template
    }

    /// The phase shown by the scout icon in the closed notch.
    enum ScoutPhase: Equatable {
        /// No active session — static idle pose.
        case idle
        /// Agent is thinking, no tool active.
        case thinking
        /// Agent is reading/writing code (Read, Edit, Write, Grep, Glob, …).
        case coding
        /// Agent is running a shell command (Bash, exec_command).
        case runningCommand
        /// Agent is searching/browsing (WebSearch, WebFetch, Agent, LSP).
        case searching
        /// Waiting for user to approve a tool/permission.
        case waitingForApproval
        /// Waiting for user to answer a question.
        case waitingForAnswer
        /// Session completed.
        case completed
        /// Context is being compacted/merged.
        case compacting

        /// All phases animate — each at its own rhythm.
        var isAnimated: Bool { true }
    }

    let size: CGFloat
    var tint: Color = .mint
    var isAnimating: Bool = false
    var phase: ScoutPhase = .idle
    var style: Style = .duotone

    // MARK: - Pixel patterns (8×8)
    //
    // B = body (primary tint)
    // H = highlight (lighter tint)
    // E = eye (dark)
    // W = wink/closed eye (medium tint, used in thinking poses)
    // G = happy eye (green, used in completed pose)

    // ── 1. Idle: Space Invader (frame A: arms down) ──
    private static let idleFrameA: [String] = [
        "..B..B..",
        "..BBBB..",
        ".BHHHHB.",
        "BBHEHEBB",
        ".BHHHHB.",
        "..BBBB..",
        ".B....B.",
        "........",
    ]

    // ── 1. Idle: Space Invader (frame B: arms up) ──
    private static let idleFrameB: [String] = [
        "..B..B..",
        "..BBBB..",
        ".BHHHHB.",
        "BBHEHEBB",
        ".BHHHHB.",
        "..BBBB..",
        "..B..B..",
        "........",
    ]

    // ── 2. Thinking: Wizard (frame A: hat sparkle left) ──
    private static let thinkingFrameA: [String] = [
        "H..BB...",
        "..BBBB..",
        ".BBBBBB.",
        "..HHHH..",
        ".BHEHEB.",
        "..HHHH..",
        "..B..B..",
        "........",
    ]

    // ── 2. Thinking: Wizard (frame B: hat sparkle right) ──
    private static let thinkingFrameB: [String] = [
        "...BB..H",
        "..BBBB..",
        ".BBBBBB.",
        "..HHHH..",
        ".BHEHEB.",
        "..HHHH..",
        "..B..B..",
        "........",
    ]

    // ── 3. Coding: Square-head robot (frame A: arms down) ──
    private static let codingFrameA: [String] = [
        ".B....B.",
        "BBBBBBBB",
        "BHEHBEHB",
        "BHHHHHHB",
        "BBBBBBBB",
        "..BBBB..",
        ".BB..BB.",
        "........",
    ]

    // ── 3. Coding: Square-head robot (frame B: arms out) ──
    private static let codingFrameB: [String] = [
        ".B....B.",
        "BBBBBBBB",
        "BHEHBEHB",
        "BHHHHHHB",
        "BBBBBBBB",
        "..BBBB..",
        "BB....BB",
        "........",
    ]

    // ── 4. Running Command: Pac-Man ghost (frame A) ──
    private static let commandFrameA: [String] = [
        "..BBBB..",
        ".BBBBBB.",
        "BBHEHEBB",
        "BBHHHHBB",
        "BBBBBBBB",
        "BBBBBBBB",
        "B.B..B.B",
        "........",
    ]

    // ── 4. Running Command: Pac-Man ghost (frame B: wave shift) ──
    private static let commandFrameB: [String] = [
        "..BBBB..",
        ".BBBBBB.",
        "BBHEHEBB",
        "BBHHHHBB",
        "BBBBBBBB",
        "BBBBBBBB",
        ".B.BB.B.",
        "........",
    ]

    // ── 5. Searching: Owl (frame A: looking left) ──
    private static let searchingFrameA: [String] = [
        ".BB..BB.",
        "BBBBBBBB",
        "BHEBBEHB",
        "BHHBBHHB",
        ".BBBBBB.",
        "..BBBB..",
        "..B..B..",
        "........",
    ]

    // ── 5. Searching: Owl (frame B: looking right) ──
    private static let searchingFrameB: [String] = [
        ".BB..BB.",
        "BBBBBBBB",
        "BEHBBHEB",
        "BHHBBHHB",
        ".BBBBBB.",
        "..BBBB..",
        "..B..B..",
        "........",
    ]

    // ── 6. Approval: Shield guard (frame A: arms down) ──
    private static let approvalFrameA: [String] = [
        "..BBBB..",
        ".BBBBBB.",
        "BBHEEHBB",
        "BBHHHBBB",
        ".BBBBBB.",
        "..BBBB..",
        ".B.BB.B.",
        "........",
    ]

    // ── 6. Approval: Shield guard (frame B: arms raised) ──
    private static let approvalFrameB: [String] = [
        "B.BBBB.B",
        ".BBBBBB.",
        "BBHEEHBB",
        "BBHHHBBB",
        ".BBBBBB.",
        "..BBBB..",
        "...BB...",
        "........",
    ]

    // ── 7. Answer: Cat (frame A: ears up) ──
    private static let answerFrameA: [String] = [
        "B......B",
        "BB....BB",
        "BBBBBBBB",
        "BHEWWEHB",
        "BBHHHHBB",
        ".BBBBBB.",
        "..B..B..",
        "........",
    ]

    // ── 7. Answer: Cat (frame B: ear twitch) ──
    private static let answerFrameB: [String] = [
        ".B....B.",
        "BB....BB",
        "BBBBBBBB",
        "BHEBBEHB",
        "BBHHHHBB",
        ".BBBBBB.",
        "..B..B..",
        "........",
    ]

    // ── 8. Completed: Trophy (frame A: sparkle left) ──
    private static let completedFrameA: [String] = [
        "H..BB...",
        "..BGBB..",
        ".BGGGGB.",
        "BBGGGGBB",
        ".BBGGBB.",
        "..BBBB..",
        "..B..B..",
        ".BB..BB.",
    ]

    // ── 8. Completed: Trophy (frame B: sparkle right) ──
    private static let completedFrameB: [String] = [
        "...BB..H",
        "..BGBB..",
        ".BGGGGB.",
        "BBGGGGBB",
        ".BBGGBB.",
        "..BBBB..",
        "..B..B..",
        ".BB..BB.",
    ]

    // ── 9. Compacting: Vortex creature (frame A: spin left) ──
    private static let compactingFrameA: [String] = [
        "BBBBBBB.",
        ".BBBBBB.",
        ".BHHHHB.",
        "BBHEHEBB",
        ".BHHHHB.",
        "..BBBB..",
        "...BB...",
        "........",
    ]

    // ── 9. Compacting: Vortex creature (frame B: spin right) ──
    private static let compactingFrameB: [String] = [
        ".BBBBBBB",
        ".BBBBBB.",
        ".BHHHHB.",
        "BBHEHEBB",
        ".BHHHHB.",
        "..BBBB..",
        "...BB...",
        "........",
    ]

    // MARK: - Badge symbol patterns (8×8, rendered to the right of the scout)

    /// "..." thinking dots
    private static let dotsBadgePattern: [String] = [
        "........",
        "........",
        ".B...B..",
        "BBB.BBB.",
        ".B...B..",
        "........",
        "........",
        "........",
    ]

    /// ⚡ lightning bolt (thin)
    private static let lightningBadgePattern: [String] = [
        "....BB..",
        "...BB...",
        "..BB....",
        ".BBBB...",
        "...BB...",
        "..BB....",
        ".BB.....",
        "........",
    ]

    /// 🔍 magnifying glass
    private static let searchBadgePattern: [String] = [
        "........",
        "..BBB...",
        ".B...B..",
        ".B...B..",
        "..BBB...",
        "....B...",
        ".....BB.",
        "........",
    ]

    /// ! exclamation mark
    private static let exclamationBadgePattern: [String] = [
        "...BB...",
        "...BB...",
        "...BB...",
        "...BB...",
        "...BB...",
        "........",
        "...BB...",
        "........",
    ]

    /// ? question mark
    private static let questionBadgePattern: [String] = [
        "..BBBB..",
        ".B....B.",
        "......B.",
        "....BB..",
        "...B....",
        "........",
        "...B....",
        "........",
    ]

    /// ✓ checkmark
    private static let checkBadgePattern: [String] = [
        "........",
        ".......B",
        "......B.",
        ".....B..",
        ".B..B...",
        "..BB....",
        "...B....",
        "........",
    ]

    // MARK: - Precomputed pixel lists

    private static func parsePixels(_ pattern: [String]) -> [(x: Int, y: Int, role: Character)] {
        pattern.enumerated().flatMap { rowIndex, row in
            row.enumerated().compactMap { columnIndex, character in
                character == "." ? nil : (columnIndex, rowIndex, character)
            }
        }
    }

    private static let idlePixelsA = parsePixels(idleFrameA)
    private static let idlePixelsB = parsePixels(idleFrameB)
    private static let thinkingPixelsA = parsePixels(thinkingFrameA)
    private static let thinkingPixelsB = parsePixels(thinkingFrameB)
    private static let codingPixelsA = parsePixels(codingFrameA)
    private static let codingPixelsB = parsePixels(codingFrameB)
    private static let commandPixelsA = parsePixels(commandFrameA)
    private static let commandPixelsB = parsePixels(commandFrameB)
    private static let searchingPixelsA = parsePixels(searchingFrameA)
    private static let searchingPixelsB = parsePixels(searchingFrameB)
    private static let approvalPixelsA = parsePixels(approvalFrameA)
    private static let approvalPixelsB = parsePixels(approvalFrameB)
    private static let answerPixelsA = parsePixels(answerFrameA)
    private static let answerPixelsB = parsePixels(answerFrameB)
    private static let completedPixelsA = parsePixels(completedFrameA)
    private static let completedPixelsB = parsePixels(completedFrameB)
    private static let compactingPixelsA = parsePixels(compactingFrameA)
    private static let compactingPixelsB = parsePixels(compactingFrameB)

    // MARK: - Pixel badge patterns (3×5, drawn top-right of scout)
    //
    // S = badge pixel (colored per phase)

    /// Thinking: "..." three dots
    private static let dotsBadge: [String] = [
        "...",
        "...",
        "...",
        "S.S",
        "...",
    ]

    /// Lightning bolt for running command.
    private static let lightningBadge: [String] = [
        ".SS",
        ".S.",
        "SS.",
        ".S.",
        "S..",
    ]

    /// "!" exclamation for approval.
    private static let exclamationBadge: [String] = [
        ".S.",
        ".S.",
        ".S.",
        "...",
        ".S.",
    ]

    /// "?" question mark for answer.
    private static let questionBadge: [String] = [
        "SS.",
        "..S",
        ".S.",
        "...",
        ".S.",
    ]

    /// Checkmark for completed.
    private static let checkBadge: [String] = [
        "...",
        "..S",
        ".S.",
        "S..",
        "...",
    ]

    /// Magnifying glass for searching.
    private static let searchBadge: [String] = [
        "SS.",
        "S.S",
        "SS.",
        "..S",
        "...",
    ]

    private static let dotsBadgePixels = parsePixels(dotsBadgePattern)
    private static let lightningBadgePixels = parsePixels(lightningBadgePattern)
    private static let searchBadgePixels = parsePixels(searchBadgePattern)
    private static let exclamationBadgePixels = parsePixels(exclamationBadgePattern)
    private static let questionBadgePixels = parsePixels(questionBadgePattern)
    private static let checkBadgePixels = parsePixels(checkBadgePattern)

    /// The badge pixel pattern for the current phase, if any.
    var currentBadgePixels: [(x: Int, y: Int, role: Character)]? {
        switch phase {
        case .idle:                 return nil
        case .thinking:             return Self.dotsBadgePixels
        case .coding:               return nil
        case .runningCommand:       return Self.lightningBadgePixels
        case .searching:            return Self.searchBadgePixels
        case .waitingForApproval:   return Self.exclamationBadgePixels
        case .waitingForAnswer:     return Self.questionBadgePixels
        case .completed:            return Self.checkBadgePixels
        case .compacting:           return nil
        }
    }

    // MARK: - Animation state

    @State private var animationFrame = false
    @State private var breatheOpacity: Double = 1.0

    private var currentPixels: [(x: Int, y: Int, role: Character)] {
        switch phase {
        case .idle:
            return animationFrame ? Self.idlePixelsB : Self.idlePixelsA
        case .thinking:
            return animationFrame ? Self.thinkingPixelsB : Self.thinkingPixelsA
        case .coding:
            return animationFrame ? Self.codingPixelsB : Self.codingPixelsA
        case .runningCommand:
            return animationFrame ? Self.commandPixelsB : Self.commandPixelsA
        case .searching:
            return animationFrame ? Self.searchingPixelsB : Self.searchingPixelsA
        case .waitingForApproval:
            return animationFrame ? Self.approvalPixelsB : Self.approvalPixelsA
        case .waitingForAnswer:
            return animationFrame ? Self.answerPixelsB : Self.answerPixelsA
        case .completed:
            return animationFrame ? Self.completedPixelsB : Self.completedPixelsA
        case .compacting:
            return animationFrame ? Self.compactingPixelsB : Self.compactingPixelsA
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / 8, proxy.size.height / 8)
            let markWidth = cell * 8
            let markHeight = cell * 8
            let originX = (proxy.size.width - markWidth) / 2
            let originY = (proxy.size.height - markHeight) / 2

            ZStack(alignment: .topLeading) {
                // Scout body
                ForEach(Array(currentPixels.enumerated()), id: \.offset) { _, pixel in
                    Rectangle()
                        .fill(fillColor(for: pixel.role))
                        .frame(width: cell, height: cell)
                        .offset(
                            x: originX + CGFloat(pixel.x) * cell,
                            y: originY + CGFloat(pixel.y) * cell
                        )
                }

            }
            .opacity(phase.isAnimated ? breatheOpacity : 1.0)
        }
        .frame(width: size, height: size)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .onAppear { startAnimationsIfNeeded() }
        .onChange(of: phase) { startAnimationsIfNeeded() }
    }

    // MARK: - Animation

    private func startAnimationsIfNeeded() {
        guard phase.isAnimated else {
            animationFrame = false
            breatheOpacity = 1.0
            return
        }

        let frameDuration: Double
        switch phase {
        case .idle:
            frameDuration = 1.2          // slow gentle sway
        case .thinking:
            frameDuration = 0.8          // sparkle flicker
        case .coding:
            frameDuration = 0.5          // fast typing
        case .runningCommand:
            frameDuration = 0.4          // ghost wave
        case .searching:
            frameDuration = 0.7          // looking around
        case .waitingForApproval:
            frameDuration = 0.6          // waving arms
        case .waitingForAnswer:
            frameDuration = 0.8          // ear twitch
        case .completed:
            frameDuration = 0.9          // sparkle celebration
        case .compacting:
            frameDuration = 0.6          // hourglass flip
        }

        withAnimation(.easeInOut(duration: frameDuration).repeatForever(autoreverses: true)) {
            animationFrame.toggle()
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            breatheOpacity = 0.72
        }
    }

    // MARK: - Colors

    private func fillColor(for role: Character) -> Color {
        switch style {
        case .duotone:
            switch role {
            case "B":
                return tint.opacity(isAnimating ? 1.0 : 0.86)
            case "H":
                return tint.opacity(isAnimating ? 0.84 : 0.64)
            case "E":
                return Color.black.opacity(0.72)
            case "W":
                // Wink/closed eye — lighter than normal eye.
                return tint.opacity(0.5)
            case "G":
                // Happy eye — green tint for completed state.
                return Color.green.opacity(0.9)
            case "S":
                // Badge symbol pixel — bright white for maximum contrast.
                return .white.opacity(0.95)
            default:
                return .clear
            }
        case .template:
            switch role {
            case "E", "W", "G":
                return Color.primary.opacity(0.9)
            case "S":
                return .white
            default:
                return Color.primary
            }
        }
    }
}
