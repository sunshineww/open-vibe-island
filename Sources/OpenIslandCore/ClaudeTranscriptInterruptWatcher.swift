import Foundation

/// Identifies a Claude session whose JSONL transcript we want to tail for
/// user-interrupt markers (`[Request interrupted by user for tool use]`).
/// Claude Code 2.1.x writes this sentinel *synchronously* on Esc at a
/// point where no hook fires (query.ts bails with `aborted_tools`), so
/// the file is the only low-latency signal we have.
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
    public static let interruptMarker = "[Request interrupted by user for tool use]"

    public var onInterrupt: (@Sendable (String) -> Void)?

    private struct Observation {
        let sessionID: String
        let path: String
        var offset: UInt64
        var pendingBuffer: Data
        let fd: Int32
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

        // Drop observations whose path changed or whose session went away.
        for (sessionID, observation) in observations {
            if let target = targetMap[sessionID], target.transcriptPath == observation.path {
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
        let fd = open(target.transcriptPath, O_RDONLY | O_EVTONLY)
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
            path: target.transcriptPath,
            offset: initialOffset,
            pendingBuffer: Data(),
            fd: fd,
            source: source
        )
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

        let fileURL = URL(fileURLWithPath: observation.path)
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
