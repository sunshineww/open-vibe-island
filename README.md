# Vibe Island OSS

An open-source macOS notch and top-bar companion for AI coding agents.

The goal is to build a native Swift app that can monitor local agent sessions, surface permission requests and questions, and jump back into the right terminal or editor context without leaving flow.

## Status

Bootstrap stage. The repository currently contains project direction, architecture notes, and repository conventions. App code has not been scaffolded yet.

## Product Direction

- Native macOS app built with SwiftUI and AppKit where needed.
- Local-first communication over Unix sockets or equivalent IPC.
- Support multiple coding agents over time, starting with one narrow integration.
- Focus on interaction, not just passive monitoring.

## Initial Milestones

1. `v0.1` Single-agent MVP with mocked events and overlay UI.
2. `v0.2` Real hook integration, approval flow, and question answering.
3. `v0.3` Terminal jump, multi-session state, and external display behavior.
4. `v0.4` Multi-agent adapters and install/setup automation.

## Repository Layout

- `docs/product.md` Product scope, MVP boundary, and roadmap.
- `docs/architecture.md` System shape, event flow, and engineering decisions.

## Principles

- Keep the app local-first. No server dependency for core behavior.
- Build narrow slices end to end before adding more integrations.
- Prefer native platform APIs over cross-platform abstractions.
- Treat hooks, IPC, and focus-switching behavior as first-class engineering concerns.

## Next Step

Scaffold the macOS app target and a mock bridge so the UI can be built against realistic session events.
