import Foundation
import Testing
@testable import OpenIslandCore

struct CodexHooksTests {
    @Test
    func codexDefaultJumpTargetForwardsWarpPaneUUID() {
        var payload = CodexHookPayload(
            cwd: "/tmp/demo",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        )
        payload.terminalApp = "Warp"
        payload.warpPaneUUID = "D1A5DF3027E44FC080FE2656FAF2BA2E"
        #expect(payload.defaultJumpTarget.warpPaneUUID == "D1A5DF3027E44FC080FE2656FAF2BA2E")
    }

    @Test
    func codexWithRuntimeContextPopulatesWarpPaneUUIDFromResolver() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/demo",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["WARP_IS_LOCAL_SHELL_SESSION": "1"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { cwd in
                cwd == "/Users/u/demo" ? "DEADBEEFDEADBEEFDEADBEEFDEADBEEF" : nil
            }
        )

        #expect(payload.terminalApp == "Warp")
        #expect(payload.warpPaneUUID == "DEADBEEFDEADBEEFDEADBEEFDEADBEEF")
        #expect(payload.defaultJumpTarget.warpPaneUUID == "DEADBEEFDEADBEEFDEADBEEFDEADBEEF")
    }

    @Test
    func codexWithRuntimeContextSkipsWarpResolverForNonWarpTerminal() {
        var resolverCalls = 0
        let payload = CodexHookPayload(
            cwd: "/Users/u/demo",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["TERM_PROGRAM": "ghostty"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { _ in
                resolverCalls += 1
                return "SHOULD-NOT-BE-USED"
            }
        )

        #expect(payload.terminalApp == "Ghostty")
        #expect(payload.warpPaneUUID == nil)
        #expect(resolverCalls == 0)
    }

    @Test
    func codexWithRuntimeContextDetectsCodexDesktopApp() {
        let payload = CodexHookPayload(
            cwd: "/Users/u/project",
            hookEventName: .sessionStart,
            model: "gpt-4o",
            permissionMode: .default,
            sessionID: "s1",
            transcriptPath: nil
        ).withRuntimeContext(
            environment: ["__CFBundleIdentifier": "com.openai.codex"],
            currentTTYProvider: { nil },
            terminalLocatorProvider: { _ in (sessionID: nil, tty: nil, title: nil) },
            warpPaneResolver: { _ in nil }
        )

        #expect(payload.terminalApp == "Codex.app")
        #expect(payload.warpPaneUUID == nil)
    }

    // MARK: - CodexHookOutputEncoder schemas

    @Test
    func encoderEmitsAllowSchemaForPermissionRequestAck() throws {
        let data = try CodexHookOutputEncoder.standardOutput(
            for: .acknowledged,
            hookEventName: .permissionRequest
        )
        let line = try #require(data)
        let json = try JSONSerialization.jsonObject(with: line) as? [String: Any]
        let output = json?["hookSpecificOutput"] as? [String: Any]
        let decision = output?["decision"] as? [String: Any]
        #expect(output?["hookEventName"] as? String == "PermissionRequest")
        #expect(decision?["behavior"] as? String == "allow")
    }

    @Test
    func encoderEmitsDenySchemaForPermissionRequestDeny() throws {
        let data = try CodexHookOutputEncoder.standardOutput(
            for: .codexHookDirective(.deny(reason: "Denied in Open Island.")),
            hookEventName: .permissionRequest
        )
        let line = try #require(data)
        let json = try JSONSerialization.jsonObject(with: line) as? [String: Any]
        let output = json?["hookSpecificOutput"] as? [String: Any]
        let decision = output?["decision"] as? [String: Any]
        #expect(output?["hookEventName"] as? String == "PermissionRequest")
        #expect(decision?["behavior"] as? String == "deny")
        #expect(decision?["message"] as? String == "Denied in Open Island.")
    }

    @Test
    func encoderStaysSilentForSessionStartAck() throws {
        // Regression: a previous cleanup unconditionally emitted the
        // PermissionRequest envelope for every ack, which caused codex to
        // reject SessionStart / UserPromptSubmit / Stop hooks with
        // "hook returned invalid <event> JSON output". Non-approval events
        // must emit no stdout so codex falls back to its pass-through.
        #expect(try CodexHookOutputEncoder.standardOutput(
            for: .acknowledged,
            hookEventName: .sessionStart
        ) == nil)
        #expect(try CodexHookOutputEncoder.standardOutput(
            for: .acknowledged,
            hookEventName: .userPromptSubmit
        ) == nil)
        #expect(try CodexHookOutputEncoder.standardOutput(
            for: .acknowledged,
            hookEventName: .stop
        ) == nil)
    }
}
