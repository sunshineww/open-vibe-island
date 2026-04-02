import Foundation
import Testing
@testable import VibeIslandCore

struct CodexSessionTrackingTests {
    @Test
    func codexSessionStoreRoundTripsTrackedSessions() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe-island-tracking-\(UUID().uuidString)", isDirectory: true)
        let fileURL = rootURL.appendingPathComponent("session-terminals.json")
        let store = CodexSessionStore(fileURL: fileURL)

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let records = [
            CodexTrackedSessionRecord(
                sessionID: "codex-session-1",
                title: "Codex · vibe-island",
                summary: "Inspecting rollout watcher.",
                phase: .running,
                updatedAt: Date(timeIntervalSince1970: 1_000),
                jumpTarget: JumpTarget(
                    terminalApp: "Ghostty",
                    workspaceName: "vibe-island",
                    paneTitle: "codex ~/Personal/vibe-island"
                ),
                codexMetadata: CodexSessionMetadata(
                    transcriptPath: "/tmp/rollout.jsonl",
                    lastAssistantMessage: "Inspecting rollout watcher.",
                    currentTool: "exec_command"
                )
            )
        ]

        try store.save(records)
        let reloaded = try store.load()

        #expect(reloaded == records)
        #expect(reloaded.first?.session.codexMetadata?.transcriptPath == "/tmp/rollout.jsonl")
    }

    @Test
    func codexRolloutReducerPromotesAssistantMessagesAndCompletion() {
        let initialLines = [
            rolloutLine(
                timestamp: "2026-04-02T04:03:44.894Z",
                type: "response_item",
                payload: [
                    "type": "function_call",
                    "name": "exec_command",
                ]
            ),
            rolloutLine(
                timestamp: "2026-04-02T04:03:45.000Z",
                type: "event_msg",
                payload: [
                    "type": "agent_message",
                    "message": "Inspecting README and current hooks config.",
                ]
            ),
        ]
        let initialSnapshot = CodexRolloutReducer.snapshot(for: initialLines)
        let initialEvents = CodexRolloutReducer.events(
            from: nil,
            to: initialSnapshot,
            sessionID: "codex-session-1",
            transcriptPath: "/tmp/rollout.jsonl"
        )

        #expect(initialSnapshot.currentTool == "exec_command")
        #expect(initialSnapshot.lastAssistantMessage == "Inspecting README and current hooks config.")
        #expect(initialEvents.contains(where: { $0.trackedMetadataUpdate?.codexMetadata.currentTool == "exec_command" }))
        #expect(initialEvents.contains(where: { $0.trackedActivityUpdate?.summary == "Inspecting README and current hooks config." }))

        let finalSnapshot = CodexRolloutReducer.snapshot(
            for: initialLines + [
                rolloutLine(
                    timestamp: "2026-04-02T04:03:46.000Z",
                    type: "event_msg",
                    payload: [
                        "type": "task_complete",
                        "last_agent_message": "Rollout watcher is wired and verified.",
                    ]
                ),
            ]
        )
        let finalEvents = CodexRolloutReducer.events(
            from: initialSnapshot,
            to: finalSnapshot,
            sessionID: "codex-session-1",
            transcriptPath: "/tmp/rollout.jsonl"
        )

        #expect(finalSnapshot.phase == .completed)
        #expect(finalSnapshot.currentTool == nil)
        #expect(finalEvents.contains(where: { $0.trackedSessionCompletion?.summary == "Rollout watcher is wired and verified." }))
        #expect(finalEvents.contains(where: { $0.trackedMetadataUpdate?.codexMetadata.currentTool == nil }))
    }

    @Test
    func codexRolloutWatcherTracksAppendedLines() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibe-island-rollout-\(UUID().uuidString)", isDirectory: true)
        let rolloutURL = rootURL.appendingPathComponent("rollout.jsonl")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try Data().write(to: rolloutURL)

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let recorder = EventRecorder()
        let watcher = CodexRolloutWatcher(pollInterval: 0.05)
        watcher.eventHandler = { event in
            Task {
                await recorder.append(event)
            }
        }
        watcher.sync(targets: [
            CodexRolloutWatchTarget(
                sessionID: "codex-session-1",
                transcriptPath: rolloutURL.path
            )
        ])

        try appendRolloutLine(
            rolloutLine(
                timestamp: "2026-04-02T04:03:44.894Z",
                type: "response_item",
                payload: [
                    "type": "function_call",
                    "name": "exec_command",
                ]
            ),
            to: rolloutURL
        )
        try appendRolloutLine(
            rolloutLine(
                timestamp: "2026-04-02T04:03:45.000Z",
                type: "event_msg",
                payload: [
                    "type": "agent_message",
                    "message": "Inspecting README.",
                ]
            ),
            to: rolloutURL
        )

        try await Task.sleep(for: .milliseconds(200))

        try appendRolloutLine(
            rolloutLine(
                timestamp: "2026-04-02T04:03:46.000Z",
                type: "event_msg",
                payload: [
                    "type": "task_complete",
                    "last_agent_message": "Finished the rollout tracking slice.",
                ]
            ),
            to: rolloutURL
        )

        try await Task.sleep(for: .milliseconds(200))
        watcher.stop()

        let events = await recorder.snapshot()
        #expect(events.contains(where: { $0.trackedMetadataUpdate?.codexMetadata.currentTool == "exec_command" }))
        #expect(events.contains(where: { $0.trackedActivityUpdate?.summary == "Inspecting README." }))
        #expect(events.contains(where: { $0.trackedSessionCompletion?.summary == "Finished the rollout tracking slice." }))
    }
}

private actor EventRecorder {
    private var events: [AgentEvent] = []

    func append(_ event: AgentEvent) {
        events.append(event)
    }

    func snapshot() -> [AgentEvent] {
        events
    }
}

private func appendRolloutLine(_ line: String, to fileURL: URL) throws {
    guard let data = "\(line)\n".data(using: .utf8) else {
        return
    }

    let handle = try FileHandle(forWritingTo: fileURL)
    defer {
        try? handle.close()
    }

    try handle.seekToEnd()
    try handle.write(contentsOf: data)
}

private func rolloutLine(
    timestamp: String,
    type: String,
    payload: [String: Any]
) -> String {
    let object: [String: Any] = [
        "timestamp": timestamp,
        "type": type,
        "payload": payload,
    ]
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

private extension AgentEvent {
    var trackedActivityUpdate: SessionActivityUpdated? {
        if case let .activityUpdated(payload) = self {
            payload
        } else {
            nil
        }
    }

    var trackedSessionCompletion: SessionCompleted? {
        if case let .sessionCompleted(payload) = self {
            payload
        } else {
            nil
        }
    }

    var trackedMetadataUpdate: SessionMetadataUpdated? {
        if case let .sessionMetadataUpdated(payload) = self {
            payload
        } else {
            nil
        }
    }
}
