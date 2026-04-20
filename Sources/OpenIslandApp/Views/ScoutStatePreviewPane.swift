import SwiftUI

struct ScoutStatePreviewPane: View {
    var model: AppModel

    private let states: [(label: String, toolLabel: String?, phase: OpenIslandBrandMark.ScoutPhase, tint: Color)] = [
        ("Idle", nil, .idle, .mint),
        ("Thinking", nil, .thinking, Color(red: 0.43, green: 0.62, blue: 1.0)),
        ("Coding", "Edit", .coding, Color(red: 0.0, green: 0.8, blue: 0.85)),
        ("Command", "Bash", .runningCommand, Color(red: 0.65, green: 0.45, blue: 1.0)),
        ("Searching", "Search", .searching, Color(red: 0.3, green: 0.5, blue: 0.95)),
        ("Subagent", "Task", .subagent, Color(red: 0.55, green: 0.85, blue: 0.95)),
        ("Approval", nil, .waitingForApproval, .orange),
        ("Answer", nil, .waitingForAnswer, .yellow),
        ("Completed", nil, .completed, .green),
        ("Compact", "Compact", .compacting, Color(red: 0.85, green: 0.55, blue: 0.2)),
        ("Input", nil, .waitingForInput, Color(red: 0.5, green: 0.8, blue: 0.5)),
        ("Awaiting", nil, .awaitingPrompt, Color(red: 0.6, green: 0.75, blue: 0.95)),
        ("Failed", nil, .failed, Color(red: 0.95, green: 0.35, blue: 0.35)),
        ("Interrupted", nil, .interrupted, Color(red: 0.95, green: 0.55, blue: 0.25)),
        ("Stale", nil, .stale, Color(red: 0.55, green: 0.6, blue: 0.65)),
    ]

    private static let gridColumns = [
        GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 12, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                notchSizeGroup

                largeGroup
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scout States")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("15 种像素小人状态：agent 活动、交互、结局（成功 / 失败 / 中断 / 休眠）。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var notchSizeGroup: some View {
        sectionCard(title: "实际 Notch 尺寸 (14px)") {
            LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    notchCard(for: state)
                }
            }
        }
    }

    private var largeGroup: some View {
        sectionCard(title: "放大预览 (32px)") {
            LazyVGrid(columns: Self.gridColumns, spacing: 12) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    largeCard(for: state)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.42))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func notchCard(for state: (label: String, toolLabel: String?, phase: OpenIslandBrandMark.ScoutPhase, tint: Color)) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                OpenIslandBrandMark(
                    size: 14,
                    tint: state.tint,
                    isAnimating: state.phase.isAnimated,
                    phase: state.phase,
                    style: .duotone
                )
                .frame(width: 14, height: 14)

                ScoutBadgeView(size: 14, phase: state.phase, tint: state.tint)
                    .frame(width: 14, height: 14)

                if state.phase == .compacting {
                    CompactSpinner(size: 10, tint: state.tint)
                }

                if let tool = state.toolLabel {
                    Text(tool)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(state.tint.opacity(0.8))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black, in: Capsule())

            Text(state.label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func largeCard(for state: (label: String, toolLabel: String?, phase: OpenIslandBrandMark.ScoutPhase, tint: Color)) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                OpenIslandBrandMark(
                    size: 32,
                    tint: state.tint,
                    isAnimating: state.phase.isAnimated,
                    phase: state.phase,
                    style: .duotone
                )
                .frame(width: 32, height: 32)

                ScoutBadgeView(size: 32, phase: state.phase, tint: state.tint)
                    .frame(width: 32, height: 32)

                if state.phase == .compacting {
                    CompactSpinner(size: 20, tint: state.tint)
                }
            }
            .frame(height: 32)

            Text(state.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            if let tool = state.toolLabel {
                Text(tool)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(state.tint.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
