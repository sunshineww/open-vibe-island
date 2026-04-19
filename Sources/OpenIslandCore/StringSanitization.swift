import Foundation

public extension String {
    /// Strip Claude-internal pseudo-tags and normalise image placeholders
    /// before the text hits the island UI.
    ///
    /// Claude Code (and its forks) inject wrapper tags like
    /// `<local-command-caveat>…</local-command-caveat>`,
    /// `<system-reminder>…</system-reminder>` and
    /// `<user-prompt-submit-hook>…</user-prompt-submit-hook>` into the
    /// transcript. Those are meant to be consumed by the LLM, not shown
    /// to humans — letting them through makes the island cards look
    /// broken. Likewise the transcript uses `[Image #N]` placeholders
    /// for pasted images; surfacing the raw token confuses users, so we
    /// swap it for a readable 🖼️ marker.
    ///
    /// All UI entry points that used to call `trimmingCharacters` now
    /// route through this single method so the cleanup is consistent.
    var sanitizedForIslandDisplay: String {
        var sanitized = self

        // Matched tag blocks — content between open and close tag is dropped.
        sanitized = sanitized.replacingOccurrences(
            of: Self.pairedPseudoTagPattern,
            with: "",
            options: .regularExpression
        )
        // Stand-alone open / close tags (the other half got truncated).
        sanitized = sanitized.replacingOccurrences(
            of: Self.lonePseudoTagPattern,
            with: "",
            options: .regularExpression
        )

        // Image placeholders: `[Image #2]`, `[Image #12]`, `[image #1]` → 🖼️
        sanitized = sanitized.replacingOccurrences(
            of: #"\[[Ii]mage\s*#?\s*\d+\]"#,
            with: "🖼️",
            options: .regularExpression
        )

        // Collapse stretches of blank lines the stripping may have left.
        sanitized = sanitized.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tags we know Claude Code (and its forks) inject into transcripts
    /// but do not want to show to end users. Keep this list conservative
    /// — over-matching risks stripping legitimate inline XML/HTML that
    /// shows up in real agent answers (e.g. an assistant quoting an SVG
    /// snippet). Everything listed here is documented Claude-internal.
    private static let pseudoTagNames: [String] = [
        "local-command-[a-z0-9_-]+",
        "system-reminder",
        "user-prompt-submit-hook",
        "command-name",
        "command-message",
        "command-args",
        "command-stdout",
        "command-stderr",
        "bash-input",
        "bash-output",
        "bash-stdout",
        "bash-stderr",
    ]

    private static var pairedPseudoTagPattern: String {
        let names = pseudoTagNames.joined(separator: "|")
        return #"<("# + names + #")>[\s\S]*?</\1>"#
    }

    private static var lonePseudoTagPattern: String {
        let names = pseudoTagNames.joined(separator: "|")
        return #"</?("# + names + #")\s*/?>"#
    }
}
