import Foundation
import OpenIslandCore

@main
struct OpenIslandHooksCLI {
    private static let interactiveHookTimeout = TimeInterval(CodexHookInstaller.interactiveManagedTimeout)
    private static let standardHookTimeout = TimeInterval(CodexHookInstaller.managedTimeout)

    private enum HookSource: String {
        case codex
        case claude
        case qoder
        case qwen
        case factory
        case droid
        case codebuddy
        case cursor
        case gemini
        case kimi

        var isClaudeFormat: Bool {
            switch self {
            case .claude, .qoder, .qwen, .factory, .droid, .codebuddy, .kimi:
                return true
            case .codex, .cursor, .gemini:
                return false
            }
        }
    }

    static func main() {
        do {
            let input = FileHandle.standardInput.readDataToEndOfFile()
            guard !input.isEmpty else {
                return
            }

            let arguments = Array(CommandLine.arguments.dropFirst())
            let source = hookSource(arguments: arguments)
            let sourceString = rawSourceString(arguments: arguments)
            let decoder = JSONDecoder()
            let client = BridgeCommandClient(socketURL: BridgeSocketLocation.currentURL())

            switch source {
            case .codex:
                let payload = try decoder
                    .decode(CodexHookPayload.self, from: input)
                    .withRuntimeContext(environment: ProcessInfo.processInfo.environment)

                let timeout: TimeInterval
                switch payload.hookEventName {
                case .preToolUse, .permissionRequest:
                    timeout = Self.interactiveHookTimeout
                case .sessionStart, .userPromptSubmit, .postToolUse, .stop:
                    timeout = Self.standardHookTimeout
                }
                let startedAt = Date()

                traceCodexHook(
                    stage: "cli.receive",
                    payload: payload,
                    extraFields: [
                        "timeoutSeconds": String(Int(timeout)),
                    ]
                )

                do {
                    let response = try client.send(.processCodexHook(payload), timeout: timeout)
                    let elapsedMilliseconds = String(Int(Date().timeIntervalSince(startedAt) * 1000))

                    if let response {
                        traceCodexHook(
                            stage: "cli.response",
                            payload: payload,
                            extraFields: [
                                "elapsedMs": elapsedMilliseconds,
                                "response": bridgeResponseSummary(response),
                                "timeoutSeconds": String(Int(timeout)),
                            ]
                        )

                        if let output = try CodexHookOutputEncoder.standardOutput(
                            for: response,
                            hookEventName: payload.hookEventName
                        ) {
                            FileHandle.standardOutput.write(output)
                        }
                    } else {
                        traceCodexHook(
                            stage: "cli.responseEOF",
                            payload: payload,
                            extraFields: [
                                "elapsedMs": elapsedMilliseconds,
                                "timeoutSeconds": String(Int(timeout)),
                            ]
                        )
                    }
                } catch {
                    traceCodexHook(
                        stage: "cli.bridgeUnavailable",
                        payload: payload,
                        extraFields: [
                            "elapsedMs": String(Int(Date().timeIntervalSince(startedAt) * 1000)),
                            "error": String(describing: error),
                            "timeoutSeconds": String(Int(timeout)),
                        ]
                    )
                    logStderr("bridge unavailable for codex hook (\(payload.hookEventName.rawValue))")
                    return
                }
            case .claude, .qoder, .qwen, .factory, .droid, .codebuddy, .kimi:
                var payload = try decoder
                    .decode(ClaudeHookPayload.self, from: input)
                    .withRuntimeContext(environment: ProcessInfo.processInfo.environment)
                payload.hookSource = sourceString

                let timeout = payload.hookEventName == .permissionRequest
                    ? Self.interactiveHookTimeout
                    : Self.standardHookTimeout

                guard let response = try? client.send(.processClaudeHook(payload), timeout: timeout) else {
                    logStderr("bridge unavailable for claude hook (\(payload.hookEventName.rawValue))")
                    return
                }

                if let output = try ClaudeHookOutputEncoder.standardOutput(for: response) {
                    FileHandle.standardOutput.write(output)
                }
            case .cursor:
                let payload = try decoder.decode(CursorHookPayload.self, from: input)

                let timeout: TimeInterval = payload.isBlockingHook
                    ? Self.interactiveHookTimeout
                    : Self.standardHookTimeout

                guard let response = try? client.send(.processCursorHook(payload), timeout: timeout) else {
                    return
                }

                if case let .cursorHookDirective(directive) = response {
                    let encoder = JSONEncoder()
                    let output = try encoder.encode(directive)
                    FileHandle.standardOutput.write(output)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                }
            case .gemini:
                let payload = try decoder
                    .decode(GeminiHookPayload.self, from: input)
                    .withRuntimeContext(environment: ProcessInfo.processInfo.environment)

                _ = try? client.send(.processGeminiHook(payload), timeout: Self.standardHookTimeout)
            }
        } catch {
            // Hooks should fail open so the CLI continues working even if the bridge is unavailable.
            logStderr("hook failed: \(error)")
        }
    }

    private static func logStderr(_ message: String) {
        guard let data = "[OpenIslandHooks] \(message)\n".data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }

    private static func traceCodexHook(
        stage: String,
        payload: CodexHookPayload,
        extraFields: [String: String?] = [:]
    ) {
        var fields = CodexHookTraceLogger.payloadFields(for: payload)
        for (key, value) in extraFields {
            fields[key] = value
        }

        CodexHookTraceLogger.log(
            process: "OpenIslandHooks",
            stage: stage,
            fields: fields
        )
    }

    private static func bridgeResponseSummary(_ response: BridgeResponse) -> String {
        switch response {
        case .acknowledged:
            "acknowledged"
        case let .codexHookDirective(directive):
            switch directive {
            case .deny:
                "codexHookDirective.deny"
            }
        case .claudeHookDirective:
            "claudeHookDirective"
        case .openCodeHookDirective:
            "openCodeHookDirective"
        case .cursorHookDirective:
            "cursorHookDirective"
        }
    }

    private static func hookSource(arguments: [String]) -> HookSource {
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--source", index + 1 < arguments.count {
                return HookSource(rawValue: arguments[index + 1]) ?? .codex
            }

            index += 1
        }

        return .codex
    }

    private static func rawSourceString(arguments: [String]) -> String? {
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--source", index + 1 < arguments.count {
                return arguments[index + 1]
            }

            index += 1
        }

        return nil
    }
}
