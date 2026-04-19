import Darwin
import Foundation

public enum CodexHookTraceLogger {
    public static let enabledEnvironmentKey = "OPEN_ISLAND_TRACE_CODEX_HOOKS"
    public static let pathEnvironmentKey = "OPEN_ISLAND_TRACE_CODEX_HOOKS_PATH"
    public static let directoryEnvironmentKey = "OPEN_ISLAND_TRACE_CODEX_HOOKS_DIR"
    public static let enableFileName = "enable-codex-hook-trace"
    public static let logFileName = "codex-hook-trace.log"

    private struct Record: Codable {
        let timestamp: String
        let process: String
        let stage: String
        let fields: [String: String]
    }

    public static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> Bool {
        if let rawValue = environment[enabledEnvironmentKey] {
            return isTruthy(rawValue)
        }

        return fileManager.fileExists(atPath: enableFileURL(environment: environment, fileManager: fileManager).path)
    }

    public static func log(
        process: String,
        stage: String,
        fields: [String: String?] = [:],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        now: Date = .now
    ) {
        guard isEnabled(environment: environment, fileManager: fileManager) else {
            return
        }

        let record = Record(
            timestamp: timestampString(from: now),
            process: process,
            stage: stage,
            fields: normalizedFields(fields)
        )

        guard let data = encode(record) else {
            return
        }

        append(data, to: logURL(environment: environment, fileManager: fileManager), fileManager: fileManager)
    }

    public static func payloadFields(for payload: CodexHookPayload) -> [String: String?] {
        [
            "event": payload.hookEventName.rawValue,
            "sessionID": payload.sessionID,
            "turnID": payload.turnID,
            "toolName": payload.toolName,
            "toolUseID": payload.toolUseID,
            "permissionMode": payload.permissionMode.rawValue,
            "terminalApp": payload.terminalApp,
            "terminalSessionID": payload.terminalSessionID,
            "terminalTTY": payload.terminalTTY,
            "transcriptPath": payload.transcriptPath,
            "cwd": payload.cwd,
            "command": payload.commandText ?? payload.commandPreview,
            "prompt": payload.prompt ?? payload.promptPreview,
            "assistantMessage": payload.lastAssistantMessage ?? payload.assistantMessagePreview,
        ]
    }

    private static func logURL(
        environment: [String: String],
        fileManager: FileManager
    ) -> URL {
        if let overridePath = environment[pathEnvironmentKey], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        return supportDirectoryURL(environment: environment, fileManager: fileManager)
            .appendingPathComponent(logFileName)
    }

    private static func enableFileURL(
        environment: [String: String],
        fileManager: FileManager
    ) -> URL {
        supportDirectoryURL(environment: environment, fileManager: fileManager)
            .appendingPathComponent(enableFileName)
    }

    private static func supportDirectoryURL(
        environment: [String: String],
        fileManager: FileManager
    ) -> URL {
        if let overridePath = environment[directoryEnvironmentKey], !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath, isDirectory: true)
        }

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("OpenIsland", isDirectory: true)
        }

        let homePath = environment["HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent("Library/Application Support/OpenIsland", isDirectory: true)
    }

    private static func encode(_ record: Record) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard var data = try? encoder.encode(record) else {
            return nil
        }

        data.append(UInt8(ascii: "\n"))
        return data
    }

    private static func append(
        _ data: Data,
        to url: URL,
        fileManager: FileManager
    ) {
        let parentURL = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        } catch {
            return
        }

        let fileDescriptor = open(url.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        guard fileDescriptor != -1 else {
            return
        }
        defer {
            close(fileDescriptor)
        }

        _ = data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            return write(fileDescriptor, baseAddress, buffer.count)
        }
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func normalizedFields(_ fields: [String: String?]) -> [String: String] {
        fields.reduce(into: [String: String]()) { result, entry in
            guard let rawValue = entry.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawValue.isEmpty else {
                return
            }

            result[entry.key] = normalizedValue(rawValue)
        }
    }

    private static func normalizedValue(_ value: String) -> String {
        let singleLine = value.replacingOccurrences(of: "\n", with: "\\n")
        let maxLength = 240
        guard singleLine.count > maxLength else {
            return singleLine
        }

        return String(singleLine.prefix(maxLength)) + "..."
    }

    private static func isTruthy(_ rawValue: String) -> Bool {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            true
        default:
            false
        }
    }
}
