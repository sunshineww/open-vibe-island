import Foundation
import Testing
@testable import OpenIslandCore

struct CodexHookTraceLoggerTests {
    @Test
    func logWritesJSONLineWhenEnabledViaEnvironment() throws {
        let rootURL = temporaryTraceRootURL(named: "env-enabled")
        let logURL = rootURL.appendingPathComponent("trace.log")

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        CodexHookTraceLogger.log(
            process: "OpenIslandHooks",
            stage: "cli.receive",
            fields: [
                "sessionID": "session-1",
                "event": "PreToolUse",
                "command": "echo hello",
            ],
            environment: [
                CodexHookTraceLogger.enabledEnvironmentKey: "1",
                CodexHookTraceLogger.pathEnvironmentKey: logURL.path,
            ],
            now: Date(timeIntervalSince1970: 0)
        )

        let contents = try String(contentsOf: logURL, encoding: .utf8)
        #expect(contents.contains("\"process\":\"OpenIslandHooks\""))
        #expect(contents.contains("\"stage\":\"cli.receive\""))
        #expect(contents.contains("\"sessionID\":\"session-1\""))
        #expect(contents.contains("\"event\":\"PreToolUse\""))
    }

    @Test
    func logWritesWhenSentinelFileExists() throws {
        let rootURL = temporaryTraceRootURL(named: "sentinel-enabled")

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let enableURL = rootURL.appendingPathComponent(CodexHookTraceLogger.enableFileName)
        FileManager.default.createFile(atPath: enableURL.path, contents: Data())

        CodexHookTraceLogger.log(
            process: "BridgeServer",
            stage: "bridge.receive",
            fields: [
                "sessionID": "session-2",
                "event": "Stop",
            ],
            environment: [
                CodexHookTraceLogger.directoryEnvironmentKey: rootURL.path,
            ],
            now: Date(timeIntervalSince1970: 1)
        )

        let logURL = rootURL.appendingPathComponent(CodexHookTraceLogger.logFileName)
        let contents = try String(contentsOf: logURL, encoding: .utf8)
        #expect(contents.contains("\"process\":\"BridgeServer\""))
        #expect(contents.contains("\"event\":\"Stop\""))
        #expect(contents.contains("\"sessionID\":\"session-2\""))
    }

    @Test
    func logSkipsWritesWhenTraceIsDisabled() throws {
        let rootURL = temporaryTraceRootURL(named: "disabled")
        let logURL = rootURL.appendingPathComponent("trace.log")

        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        CodexHookTraceLogger.log(
            process: "OpenIslandHooks",
            stage: "cli.receive",
            fields: [
                "sessionID": "session-3",
            ],
            environment: [
                CodexHookTraceLogger.pathEnvironmentKey: logURL.path,
            ]
        )

        #expect(FileManager.default.fileExists(atPath: logURL.path) == false)
    }
}

private func temporaryTraceRootURL(named name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("open-island-codex-hook-trace-\(name)-\(UUID().uuidString)", isDirectory: true)
}
