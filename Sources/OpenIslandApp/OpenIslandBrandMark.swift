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
        /// Agent spawned a sub-agent (Task tool) to do work on its behalf.
        case subagent
        /// Waiting for user to approve a tool/permission.
        case waitingForApproval
        /// Waiting for user to answer a question.
        case waitingForAnswer
        /// Session completed successfully.
        case completed
        /// Context is being compacted/merged.
        case compacting
        /// Session ended with a failure (StopFailure / PostToolUseFailure).
        case failed
        /// Session was interrupted by the user (Ctrl+C / deny+interrupt).
        case interrupted
        /// Session is technically alive but its terminal is gone — stale.
        case stale

        /// Whether the scout body frames should cycle while this phase is on screen.
        /// Idle / completed / failed / interrupted / stale are terminal or passive,
        /// so their pixel art stays still to avoid distracting background motion.
        var isAnimated: Bool {
            switch self {
            case .idle, .completed, .failed, .interrupted, .stale:
                return false
            case .thinking, .coding, .runningCommand, .searching,
                 .subagent, .waitingForApproval, .waitingForAnswer, .compacting:
                return true
            }
        }
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
    // W = wink/closed eye (medium tint, used in thinking / stale poses)
    // G = happy eye / accent pixel (green for completed, red-tinted for failed)

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

    // ── 3. Coding: Square-head robot (frame A — eyes center, hands down) ──
    //
    // Both frames share the robot body but shift the eyes across rows —
    // reads as the robot "scanning" a line of code rather than just
    // stomping its feet (the old frames only differed in toe position).
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

    // ── 3. Coding: Square-head robot (frame B — eyes glance, hands out) ──
    private static let codingFrameB: [String] = [
        ".B....B.",
        "BBBBBBBB",
        "BEHHBHEB",
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

    // ── 8. Completed: Cheering scout with both arms raised (frame A) ──
    //
    // Iteration 4 on the "done" sprite. Trophy read as idle; round
    // smiley collided with the failed frown; crown looked royal rather
    // than victorious. This version freezes the scout mid-celebration
    // with both arms thrown up in a V — the universal "I did it!"
    // posture. The head is centered (not touching the top row) so the
    // outline reads as arms + body, distinct from every other sprite.
    // Green (G) pixels still carve a smile so the happy semantics are
    // obvious even before the tint lands.
    private static let completedFrameA: [String] = [
        "B......B",
        ".BB..BB.",
        "..BBBB..",
        ".BBBBBB.",
        "BBEBBEBB",
        "BBHHHHBB",
        "B.HGGH.B",
        ".B.BB.B.",
    ]

    // ── 8. Completed: Cheering scout (frame B — reserved) ──
    //
    // Completed is static (`isAnimated == false`) so frame B is never
    // rendered. It mirrors frame A so that a future one-shot celebration
    // animation can toggle between "arms up" and "arms a touch lower"
    // without touching the renderer.
    private static let completedFrameB: [String] = [
        "B......B",
        ".BB..BB.",
        "..BBBB..",
        ".BBBBBB.",
        "BBEBBEBB",
        "BBHHHHBB",
        "B.HGGH.B",
        ".B.BB.B.",
    ]

    // ── 9. Compacting: Hourglass (frame A — sand on top) ──
    //
    // The old vortex reused the running-command ghost silhouette too
    // closely, so two different active states looked alike at 14 px. An
    // hourglass reads unambiguously as "condensing / time passing" and
    // gets a satisfying flip on frame B.
    private static let compactingFrameA: [String] = [
        "BBBBBBBB",
        ".BEEEEB.",
        "..BEEB..",
        "...BB...",
        "...BB...",
        "..BHHB..",
        ".BHHHHB.",
        "BBBBBBBB",
    ]

    // ── 9. Compacting: Hourglass (frame B — sand falling to bottom) ──
    private static let compactingFrameB: [String] = [
        "BBBBBBBB",
        ".BHHHHB.",
        "..BHHB..",
        "...BB...",
        "...BB...",
        "..BEEB..",
        ".BEEEEB.",
        "BBBBBBBB",
    ]

    // ── 10. Subagent: Twin square-head robots (frame A — left leg step) ──
    //
    // Reads as a pair of coding-robots working side-by-side, which is
    // much closer to what `Task` / sub-agent dispatch actually means.
    // The old single-ghost-with-a-gap design was too abstract.
    private static let subagentFrameA: [String] = [
        ".B....B.",
        "BBBBBBBB",
        "BEHBBHEB",
        "BHHHHHHB",
        ".BBBBBB.",
        ".BBBBBB.",
        "..B..B..",
        ".B....B.",
    ]

    // ── 10. Subagent: Twin square-head robots (frame B — right leg step) ──
    private static let subagentFrameB: [String] = [
        ".B....B.",
        "BBBBBBBB",
        "BHEBBEHB",
        "BHHHHHHB",
        ".BBBBBB.",
        ".BBBBBB.",
        ".B....B.",
        "..B..B..",
    ]

    // ── 11. Failed: Cracked scout (single frame — phase is passive) ──
    //
    // Cracking the top of the dome (..B..B.. instead of ..BBBB..) breaks
    // the silhouette against the completed smiley, so the state is
    // recognisable even before the red tint / frown register. The G
    // pixels (recoloured red by `fillColor(for:)`) draw a frown in the
    // mouth row.
    private static let failedFrameA: [String] = [
        "..B..B..",
        ".BBBBBB.",
        "BBEBBEBB",
        "BBHHHHBB",
        "B..GG..B",
        "B.GBBG.B",
        ".BBBBBB.",
        "..BBBB..",
    ]

    // ── 12. Interrupted: Stopped scout with a horizontal bar (single frame) ──
    private static let interruptedFrameA: [String] = [
        "..BBBB..",
        ".BBBBBB.",
        "BBEBBEBB",
        "BBHHHHBB",
        "GGGGGGGG",
        "..BBBB..",
        ".BB..BB.",
        "........",
    ]

    // ── 13. Stale: Sleeping Space Invader (single frame) ──
    //
    // Reuses the idle invader silhouette with eyes shut (W pixels) so it
    // reads immediately as "the same session, just napping". The previous
    // round-face "snoozing head" was too similar to completed / failed.
    private static let staleFrameA: [String] = [
        "..B..B..",
        "..BBBB..",
        ".BHHHHB.",
        "BBWWWWBB",
        ".BHHHHB.",
        "..BBBB..",
        ".B....B.",
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

    /// ✓ checkmark — a clean V that reads as "tick" even at 14 px.
    ///
    /// The left arm is 2 px, the right arm is 4 px, with the corner at
    /// (3, 6). This is the ratio used on most emoji / system checkmark
    /// glyphs; the previous pattern had a misaligned left arm that looked
    /// more like a jagged W.
    private static let checkBadgePattern: [String] = [
        "........",
        "........",
        ".......B",
        "......B.",
        ".....B..",
        ".B..B...",
        "..BB....",
        "........",
    ]

    /// </> angle brackets — "editing code" for the coding phase.
    private static let codeBracketsBadgePattern: [String] = [
        "........",
        "..B..B..",
        ".B....B.",
        "B......B",
        ".B....B.",
        "..B..B..",
        "........",
        "........",
    ]

    /// ⑂ fork icon — a central stem that splits into a Y, reads as
    /// "spawning sub-agents". The earlier pattern scattered pixels across
    /// the grid and the branching was hard to identify at badge size.
    private static let forkBadgePattern: [String] = [
        "...B....",
        "...B....",
        "...B....",
        "..B.B...",
        ".B...B..",
        "B.....B.",
        "B......B",
        "........",
    ]

    /// ✗ cross — failure.
    private static let crossBadgePattern: [String] = [
        "........",
        "B......B",
        ".B....B.",
        "..B..B..",
        "...BB...",
        "..B..B..",
        ".B....B.",
        "B......B",
    ]

    /// ⏸ double bar — interrupted.
    private static let pauseBadgePattern: [String] = [
        "........",
        ".BB..BB.",
        ".BB..BB.",
        ".BB..BB.",
        ".BB..BB.",
        ".BB..BB.",
        ".BB..BB.",
        "........",
    ]

    /// "Z" — stale / sleeping.
    private static let zBadgePattern: [String] = [
        "........",
        "BBBBBB..",
        "....B...",
        "...B....",
        "..B.....",
        ".B......",
        "BBBBBB..",
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
    private static let subagentPixelsA = parsePixels(subagentFrameA)
    private static let subagentPixelsB = parsePixels(subagentFrameB)
    private static let failedPixels = parsePixels(failedFrameA)
    private static let interruptedPixels = parsePixels(interruptedFrameA)
    private static let stalePixels = parsePixels(staleFrameA)

    private static let dotsBadgePixels = parsePixels(dotsBadgePattern)
    private static let lightningBadgePixels = parsePixels(lightningBadgePattern)
    private static let searchBadgePixels = parsePixels(searchBadgePattern)
    private static let exclamationBadgePixels = parsePixels(exclamationBadgePattern)
    private static let questionBadgePixels = parsePixels(questionBadgePattern)
    private static let checkBadgePixels = parsePixels(checkBadgePattern)
    private static let codeBracketsBadgePixels = parsePixels(codeBracketsBadgePattern)
    private static let forkBadgePixels = parsePixels(forkBadgePattern)
    private static let crossBadgePixels = parsePixels(crossBadgePattern)
    private static let pauseBadgePixels = parsePixels(pauseBadgePattern)
    private static let zBadgePixels = parsePixels(zBadgePattern)

    /// The badge pixel pattern for the current phase, if any.
    var currentBadgePixels: [(x: Int, y: Int, role: Character)]? {
        switch phase {
        case .idle:                 return nil
        case .thinking:             return Self.dotsBadgePixels
        case .coding:               return Self.codeBracketsBadgePixels
        case .runningCommand:       return Self.lightningBadgePixels
        case .searching:            return Self.searchBadgePixels
        case .subagent:             return Self.forkBadgePixels
        case .waitingForApproval:   return Self.exclamationBadgePixels
        case .waitingForAnswer:     return Self.questionBadgePixels
        case .completed:            return Self.checkBadgePixels
        case .compacting:           return nil
        case .failed:               return Self.crossBadgePixels
        case .interrupted:          return Self.pauseBadgePixels
        case .stale:                return Self.zBadgePixels
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
        case .subagent:
            return animationFrame ? Self.subagentPixelsB : Self.subagentPixelsA
        case .waitingForApproval:
            return animationFrame ? Self.approvalPixelsB : Self.approvalPixelsA
        case .waitingForAnswer:
            return animationFrame ? Self.answerPixelsB : Self.answerPixelsA
        case .completed:
            return animationFrame ? Self.completedPixelsB : Self.completedPixelsA
        case .compacting:
            return animationFrame ? Self.compactingPixelsB : Self.compactingPixelsA
        case .failed:
            return Self.failedPixels
        case .interrupted:
            return Self.interruptedPixels
        case .stale:
            return Self.stalePixels
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
        case .thinking:
            frameDuration = 0.8          // sparkle flicker
        case .coding:
            frameDuration = 0.5          // fast typing
        case .runningCommand:
            frameDuration = 0.4          // ghost wave
        case .searching:
            frameDuration = 0.7          // looking around
        case .subagent:
            frameDuration = 0.6          // alternating arms
        case .waitingForApproval:
            frameDuration = 0.6          // waving arms
        case .waitingForAnswer:
            frameDuration = 0.8          // ear twitch
        case .compacting:
            frameDuration = 0.6          // hourglass flip
        case .idle, .completed, .failed, .interrupted, .stale:
            // Handled by the `guard phase.isAnimated` above — unreachable here.
            return
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
                // Accent pixel. Green for the happy/completed state; for the
                // failed/interrupted states we tint it red so a frown or stop
                // bar stands out against the tinted body.
                switch phase {
                case .failed, .interrupted:
                    return Color.red.opacity(0.85)
                default:
                    return Color.green.opacity(0.9)
                }
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
