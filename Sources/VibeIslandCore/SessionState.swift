import Foundation

public struct SessionState: Equatable, Sendable {
    public private(set) var sessionsByID: [String: AgentSession]

    public init(sessions: [AgentSession] = []) {
        self.sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    public var sessions: [AgentSession] {
        sessionsByID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }

            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public var activeActionableSession: AgentSession? {
        sessions.first(where: { $0.phase.requiresAttention })
    }

    public var runningCount: Int {
        sessionsByID.values.filter { $0.phase == .running }.count
    }

    public var attentionCount: Int {
        sessionsByID.values.filter { $0.phase.requiresAttention }.count
    }

    public var completedCount: Int {
        sessionsByID.values.filter { $0.phase == .completed }.count
    }

    public func session(id: String?) -> AgentSession? {
        guard let id else {
            return nil
        }

        return sessionsByID[id]
    }

    public mutating func apply(_ event: AgentEvent) {
        switch event {
        case let .sessionStarted(payload):
            let session = AgentSession(
                id: payload.sessionID,
                title: payload.title,
                tool: payload.tool,
                phase: .running,
                summary: payload.summary,
                updatedAt: payload.timestamp,
                jumpTarget: payload.jumpTarget,
                codexMetadata: payload.codexMetadata?.isEmpty == true ? nil : payload.codexMetadata
            )
            upsert(session)

        case let .activityUpdated(payload):
            guard var session = sessionsByID[payload.sessionID] else {
                return
            }

            session.phase = payload.phase
            session.summary = payload.summary
            session.updatedAt = payload.timestamp
            if payload.phase != .waitingForApproval {
                session.permissionRequest = nil
            }
            if payload.phase != .waitingForAnswer {
                session.questionPrompt = nil
            }
            upsert(session)

        case let .permissionRequested(payload):
            guard var session = sessionsByID[payload.sessionID] else {
                return
            }

            session.phase = .waitingForApproval
            session.summary = payload.request.summary
            session.permissionRequest = payload.request
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            upsert(session)

        case let .questionAsked(payload):
            guard var session = sessionsByID[payload.sessionID] else {
                return
            }

            session.phase = .waitingForAnswer
            session.summary = payload.prompt.title
            session.questionPrompt = payload.prompt
            session.permissionRequest = nil
            session.updatedAt = payload.timestamp
            upsert(session)

        case let .sessionCompleted(payload):
            guard var session = sessionsByID[payload.sessionID] else {
                return
            }

            session.phase = .completed
            session.summary = payload.summary
            session.permissionRequest = nil
            session.questionPrompt = nil
            session.updatedAt = payload.timestamp
            upsert(session)

        case let .jumpTargetUpdated(payload):
            guard var session = sessionsByID[payload.sessionID] else {
                return
            }

            session.jumpTarget = payload.jumpTarget
            session.updatedAt = payload.timestamp
            upsert(session)

        case let .sessionMetadataUpdated(payload):
            guard var session = sessionsByID[payload.sessionID] else {
                return
            }

            session.codexMetadata = payload.codexMetadata.isEmpty ? nil : payload.codexMetadata
            session.updatedAt = payload.timestamp
            upsert(session)
        }
    }

    public mutating func resolvePermission(
        sessionID: String,
        approved: Bool,
        at timestamp: Date = .now
    ) {
        guard var session = sessionsByID[sessionID] else {
            return
        }

        session.permissionRequest = nil
        session.updatedAt = timestamp

        if approved {
            session.phase = .running
            session.summary = "Permission approved. Agent resumed work."
        } else {
            session.phase = .completed
            session.summary = "Permission denied. Review the session in the terminal."
        }

        upsert(session)
    }

    public mutating func answerQuestion(
        sessionID: String,
        answer: String,
        at timestamp: Date = .now
    ) {
        guard var session = sessionsByID[sessionID] else {
            return
        }

        session.questionPrompt = nil
        session.phase = .running
        session.summary = "Answered: \(answer)"
        session.updatedAt = timestamp
        upsert(session)
    }

    private mutating func upsert(_ session: AgentSession) {
        sessionsByID[session.id] = session
    }
}
