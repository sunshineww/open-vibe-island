import Foundation
import Testing
@testable import OpenIslandCore

struct ClaudeTranscriptWatcherTests {
    // MARK: - Interrupt marker detection

    @Test
    func detectsInterruptForToolUseSentinel() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData("""
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}
        """)
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.interrupted)
        #expect(result.retries.isEmpty)
        #expect(buffer.isEmpty)
    }

    @Test
    func detectsInterruptForStreamingSentinel() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData("""
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
        """)
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.interrupted)
    }

    @Test
    func preservesTrailingPartialLine() throws {
        let watcher = ClaudeTranscriptWatcher()
        let complete = lineData("""
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}
        """)
        let partial = Data("""
        {"type":"user","message":{"role":"user","content":[{"type":"te
        """.utf8)
        var buffer = complete + partial
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.interrupted)
        // Partial line (no newline terminator) should remain in buffer
        // so the next read can complete it.
        #expect(!buffer.isEmpty)
    }

    // MARK: - API retry detection

    @Test
    func detectsRateLimitRetry() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData(Self.apiErrorLine(status: 429, attempt: 3, retryInMs: 2416.6))
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.retries.count == 1)
        let retry = try #require(result.retries.first)
        #expect(retry.errorClass == .rateLimit)
        #expect(retry.httpStatus == 429)
        #expect(retry.attempt == 3)
        #expect(retry.maxRetries == 10)
        #expect(retry.retryInMs == 2416.6)
    }

    @Test
    func classifiesHttpStatusFamilies() throws {
        #expect(ClaudeApiRetryStatus.classify(httpStatus: 429) == .rateLimit)
        #expect(ClaudeApiRetryStatus.classify(httpStatus: 502) == .serverError)
        #expect(ClaudeApiRetryStatus.classify(httpStatus: 504) == .serverError)
        #expect(ClaudeApiRetryStatus.classify(httpStatus: 500) == .serverError)
        #expect(ClaudeApiRetryStatus.classify(httpStatus: 401) == .clientError)
        #expect(ClaudeApiRetryStatus.classify(httpStatus: nil) == .network)
    }

    @Test
    func networkLevelRetryWhenStatusIsNull() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData("""
        {"type":"system","subtype":"api_error","level":"error","error":{"status":null,"headers":{},"requestID":null},"retryAttempt":2,"maxRetries":10,"retryInMs":1133.2,"timestamp":"2026-04-19T08:00:00.000Z","sessionId":"abc","uuid":"xyz"}
        """)
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        let retry = try #require(result.retries.first)
        #expect(retry.errorClass == .network)
        #expect(retry.httpStatus == nil)
    }

    @Test
    func retrySequenceStartedAtIsStickyAcrossAttempts() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData(Self.apiErrorLine(status: 502, attempt: 1, retryInMs: 582.5))
                   + lineData(Self.apiErrorLine(status: 502, attempt: 2, retryInMs: 1133.2))
                   + lineData(Self.apiErrorLine(status: 502, attempt: 3, retryInMs: 2416.6))
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.retries.count == 3)
        let attempts = result.retries.map { $0.attempt }
        #expect(attempts == [1, 2, 3])
        // All three retries should share the same startedAt (the
        // moment we first saw the sequence begin).
        let uniqueStarts = Set(result.retries.map { $0.startedAt })
        #expect(uniqueStarts.count == 1)
    }

    @Test
    func ignoresNonRetrySystemLines() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData("""
        {"type":"system","subtype":"stop_hook_summary","hookCount":2,"sessionId":"abc","uuid":"xyz"}
        """)
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(!result.interrupted)
        #expect(result.retries.isEmpty)
    }

    @Test
    func ignoresMalformedApiErrorPayload() throws {
        let watcher = ClaudeTranscriptWatcher()
        // Contains the hint but retryAttempt is a string, so JSON
        // decode fails. The watcher should swallow this silently
        // rather than crash or emit a bogus retry.
        var buffer = lineData("""
        {"type":"system","subtype":"api_error","error":{"status":502},"retryAttempt":"broken","maxRetries":10,"retryInMs":500}
        """)
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.retries.isEmpty)
    }

    // MARK: - Combined

    @Test
    func interruptAndRetryInSameRead() throws {
        let watcher = ClaudeTranscriptWatcher()
        var buffer = lineData(Self.apiErrorLine(status: 429, attempt: 1, retryInMs: 800))
                   + lineData("""
                   {"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
                   """)
        var start: Date?

        let result = watcher.extractAndScan(buffer: &buffer, retrySequenceStartedAt: &start)

        #expect(result.interrupted)
        #expect(result.retries.count == 1)
        #expect(result.retries.first?.errorClass == .rateLimit)
    }

    // MARK: - Helpers

    private static func apiErrorLine(status: Int, attempt: Int, retryInMs: Double) -> String {
        """
        {"type":"system","subtype":"api_error","level":"error","error":{"status":\(status),"headers":{},"requestID":null},"retryAttempt":\(attempt),"maxRetries":10,"retryInMs":\(retryInMs),"timestamp":"2026-04-19T08:00:00.000Z","sessionId":"abc","uuid":"xyz-\(attempt)"}
        """
    }

    private func lineData(_ string: String) -> Data {
        Data((string + "\n").utf8)
    }
}
