import SwiftUI

struct ScoutStatePreviewPane: View {
    var model: AppModel

    private let states: [(label: String, toolLabel: String?, phase: OpenIslandBrandMark.ScoutPhase, tint: Color)] = [
        ("Idle", nil, .idle, .mint),
        ("Thinking", nil, .thinking, Color(red: 0.43, green: 0.62, blue: 1.0)),       // 蓝色
        ("Coding", "Edit", .coding, Color(red: 0.0, green: 0.8, blue: 0.85)),         // 青色
        ("Command", "Bash", .runningCommand, Color(red: 0.65, green: 0.45, blue: 1.0)), // 紫色
        ("Searching", "Search", .searching, Color(red: 0.3, green: 0.5, blue: 0.95)),  // 靛蓝
        ("Subagent", "Task", .subagent, Color(red: 0.55, green: 0.85, blue: 0.95)),    // 浅青
        ("Approval", nil, .waitingForApproval, .orange),                                // 橙色
        ("Answer", nil, .waitingForAnswer, .yellow),                                    // 黄色
        ("Completed", nil, .completed, .green),                                         // 绿色
        ("Compact", "Compact", .compacting, Color(red: 0.85, green: 0.55, blue: 0.2)),  // 琥珀色
        ("Failed", nil, .failed, Color(red: 0.95, green: 0.35, blue: 0.35)),           // 红
        ("Interrupted", nil, .interrupted, Color(red: 0.95, green: 0.55, blue: 0.25)), // 橙红
        ("Stale", nil, .stale, Color(red: 0.55, green: 0.6, blue: 0.65)),              // 冷灰
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Scout States Preview")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("13 种像素小人状态，覆盖 agent 活动、交互态与结局（成功 / 失败 / 中断 / 休眠）。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            // Large preview (48px)
            VStack(alignment: .leading, spacing: 12) {
                Text("Large (48px)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 20) {
                    ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                OpenIslandBrandMark(
                                    size: 48,
                                    tint: state.tint,
                                    isAnimating: state.phase.isAnimated,
                                    phase: state.phase,
                                    style: .duotone
                                )
                                .frame(width: 48, height: 48)

                                ScoutBadgeView(
                                    size: 48,
                                    phase: state.phase,
                                    tint: state.tint
                                )
                                .frame(width: 48, height: 48)

                                if state.phase == .compacting {
                                    CompactSpinner(size: 28, tint: state.tint)
                                }
                            }

                            VStack(spacing: 2) {
                                Text(state.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                if let tool = state.toolLabel {
                                    Text(tool)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(state.tint.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            // Actual notch size preview (14px)
            VStack(alignment: .leading, spacing: 12) {
                Text("Actual Notch Size (14px)")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 16) {
                    ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                        VStack(spacing: 6) {
                            HStack(spacing: 2) {
                                OpenIslandBrandMark(
                                    size: 14,
                                    tint: state.tint,
                                    isAnimating: state.phase.isAnimated,
                                    phase: state.phase,
                                    style: .duotone
                                )
                                .frame(width: 14, height: 14)

                                ScoutBadgeView(
                                    size: 14,
                                    phase: state.phase,
                                    tint: state.tint
                                )
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
                            .padding(.vertical, 4)
                            .background(Color.black, in: Capsule())

                            Text(state.label)
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
