import Foundation

/// Identifies a Claude session whose JSONL transcript we want to tail for
/// user-interrupt markers. Claude Code 2.1.x writes one of two sentinels
/// *synchronously* on Esc at a point where no hook fires (query.ts
/// bails with `aborted_tools` / `aborted_streaming`), so the file is
/// the only low-latency signal we have:
///
/// - `[Request interrupted by user for tool use]` — Esc while a tool
///   is executing (utils/messages.ts: `INTERRUPT_MESSAGE_FOR_TOOL_USE`).
/// - `[Request interrupted by user]` — Esc while the model is
///   streaming a response (utils/messages.ts: `INTERRUPT_MESSAGE`).
///
/// We match the common prefix `[Request interrupted by user` to cover
/// both without missing either variant.
public struct ClaudeTranscriptInterruptTarget: Equatable, Sendable {
    public let sessionID: String
    public let transcriptPath: String

    public init(sessionID: String, transcriptPath: String) {
        self.sessionID = sessionID
        self.transcriptPath = transcriptPath
    }
}

/// Tails Claude JSONL transcripts via `DispatchSource.fileSystemObject`
/// and fires `onInterrupt(sessionID)` when the interrupt sentinel lands
/// on disk. Intentionally narrow: we do not reconstruct the full
/// transcript, only scan appended bytes for the marker.
public final class ClaudeTranscriptInterruptWatcher: @unchecked Sendable {
    /// Shared prefix of both `INTERRUPT_MESSAGE` and
    /// `INTERRUPT_MESSAGE_FOR_TOOL_USE`. Matching the prefix keeps the
    /// watcher working across the streaming-abort and tool-abort paths,
    /// and is resilient to Claude Code appending new suffixes later.
    public static let interruptMarker = "[Request interrupted by user"

    public var onInterrupt: (@Sendable (String) -> Void)?

    private struct Observation {
        let sessionID: String
        /// The path advertised by the caller (typically from the hook
        /// payload's `transcript_path`). Used for equality checks when
        /// `sync()` is called again, so we don't rebuild the observer
        /// every tick just because the resolved path differs from the
        /// path Claude Code originally reported (see worktree caveat in
        /// `resolveTranscriptPath`).
        let preferredPath: String
        /// The path actually being tailed — may differ from
        /// `preferredPath` when the fallback resolver had to hunt for
        /// the canonical JSONL location.
        let resolvedPath: String
        var offset: UInt64
        var pendingBuffer: Data
        let source: DispatchSourceFileSystemObject
    }

    private let queue = DispatchQueue(label: "app.openisland.claude.interrupt-watcher")
    private var observations: [String: Observation] = [:]

    public init() {}

    deinit {
        stop()
    }

    public func sync(targets: [ClaudeTranscriptInterruptTarget]) {
        queue.sync {
            syncLocked(targets: targets)
        }
    }

    public func stop() {
        queue.sync {
            for observation in observations.values {
                observation.source.cancel()
            }
            observations.removeAll()
        }
    }

    private func syncLocked(targets: [ClaudeTranscriptInterruptTarget]) {
        let targetMap = Dictionary(uniqueKeysWithValues: targets.map { ($0.sessionID, $0) })

        // Drop observations whose preferred path changed (caller is
        // pointing at a different transcript) or whose session went
        // away. Compare against `preferredPath` — not `resolvedPath` —
        // so the fallback-resolved path doesn't trick us into tearing
        // down and rebuilding the same watcher every sync tick.
        for (sessionID, observation) in observations {
            if let target = targetMap[sessionID], target.transcriptPath == observation.preferredPath {
                continue
            }
            observation.source.cancel()
            observations.removeValue(forKey: sessionID)
        }

        for target in targets where observations[target.sessionID] == nil {
            if let created = makeObservation(for: target) {
                observations[target.sessionID] = created
            }
        }
    }

    private func makeObservation(for target: ClaudeTranscriptInterruptTarget) -> Observation? {
        // Claude Code 2.1.114 reports `transcript_path` in hook payloads
        // using the CWD-derived flattened directory (including worktree
        // suffix like `--claude-worktrees-<branch>`), but *actually*
        // writes the JSONL to the canonical project directory. Resolve
        // to whichever file exists on disk — prefer the reported path,
        // then fall back to globbing `~/.claude/projects/*/<uuid>.jsonl`.
        let resolvedPath = resolveTranscriptPath(preferred: target.transcriptPath, sessionID: target.sessionID)
        let fd = open(resolvedPath, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else {
            return nil
        }

        // Ignore everything already on disk — we only care about what
        // Claude Code writes from this moment forward.
        let initialOffset = UInt64(max(0, lseek(fd, 0, SEEK_END)))

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )

        let sessionID = target.sessionID
        source.setEventHandler { [weak self] in
            self?.handleFileEvent(sessionID: sessionID)
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()

        return Observation(
            sessionID: sessionID,
            preferredPath: target.transcriptPath,
            resolvedPath: resolvedPath,
            offset: initialOffset,
            pendingBuffer: Data(),
            source: source
        )
    }

    private func resolveTranscriptPath(preferred: String, sessionID: String) -> String {
        if FileManager.default.fileExists(atPath: preferred) {
            return preferred
        }

        // Honour user-customised Claude config directories (UserDefaults
        // / CLAUDE_CONFIG_DIR) — otherwise a user with a relocated
        // `.claude` would see interrupt detection silently stop working.
        let projectsRoot = ClaudeConfigDirectory.resolved()
            .appendingPathComponent("projects", isDirectory: true)
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: projectsRoot.path) else {
            return preferred
        }

        let filename = "\(sessionID).jsonl"
        for entry in entries {
            let candidate = projectsRoot
                .appendingPathComponent(entry, isDirectory: true)
                .appendingPathComponent(filename)
                .path
            if fileManager.fileExists(atPath: candidate) {
                return candidate
            }
        }

        return preferred
    }

    private func handleFileEvent(sessionID: String) {
        guard var observation = observations[sessionID] else {
            return
        }

        // If the file was deleted/renamed, drop the observation.
        let events = observation.source.data
        if events.contains(.delete) || events.contains(.rename) {
            observation.source.cancel()
            observations.removeValue(forKey: sessionID)
            return
        }

        let fileURL = URL(fileURLWithPath: observation.resolvedPath)
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return
        }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            return
        }

        // File got truncated — reset from the top.
        if fileSize < observation.offset {
            observation.offset = 0
            observation.pendingBuffer.removeAll(keepingCapacity: false)
        }

        do {
            try handle.seek(toOffset: observation.offset)
        } catch {
            return
        }

        let data: Data
        do {
            data = try handle.readToEnd() ?? Data()
        } catch {
            return
        }

        guard !data.isEmpty else {
            return
        }

        observation.offset += UInt64(data.count)
        observation.pendingBuffer.append(data)

        let detected = extractAndScan(buffer: &observation.pendingBuffer)
        observations[sessionID] = observation

        if detected {
            onInterrupt?(sessionID)
        }
    }

    /// Pull complete (`\n`-terminated) lines off the buffer. Return true
    /// if any line contains the interrupt marker. Leaves the trailing
    /// partial line in place so the next read can complete it.
    private func extractAndScan(buffer: inout Data) -> Bool {
        let newline: UInt8 = 0x0a
        var detected = false

        while let newlineIndex = buffer.firstIndex(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineIndex)
            buffer.removeSubrange(buffer.startIndex...newlineIndex)

            guard let line = String(data: lineData, encoding: .utf8) else {
                continue
            }

            if line.contains(Self.interruptMarker) {
                detected = true
            }
        }

        return detected
    }
}
