# CLAUDE.md

## What is this project?

Open Island is a native macOS companion app for AI coding agents. It sits in the notch/top-bar area and monitors local agent sessions, surfaces permission requests, answers questions, and provides "jump back" to the correct terminal context. Local-first, no server dependency.

## References

- **Target product**: https://vibeisland.app/ — the commercial product we are building toward feature parity with
- **Reference OSS repo**: https://github.com/farouqaldori/claude-island — open-source implementation we can study for design patterns and ideas

## Architecture

Four targets in one Swift package (`OpenIsland`):

1. **OpenIslandApp** — SwiftUI + AppKit shell. Menu bar extra, overlay panel (notch/top-bar), and control center window. Entry point: `OpenIslandApp.swift` with `AppModel` as the central `@Observable` state owner.
2. **OpenIslandCore** — Shared library. Models (`AgentSession`, `AgentEvent`, `SessionState`), bridge transport (Unix socket IPC with JSON line protocol), hook models/installers for both Codex and Claude Code, transcript discovery, session persistence/registry.
3. **OpenIslandHooks** — Lightweight CLI executable invoked by agent hooks. Reads hook payload from stdin, forwards to app bridge via Unix socket, writes blocking JSON to stdout only when island denies a `PreToolUse`.
4. **OpenIslandSetup** — Installer CLI for managing `~/.codex/config.toml` and `hooks.json`.

## Key data flow

### Codex path
Codex → hooks.json → OpenIslandHooks (stdin/stdout) → Unix socket → BridgeServer → AppModel → UI

### Claude Code path
Claude Code → settings.json hooks → OpenIslandHooks (stdin/stdout) → Unix socket → BridgeServer.handleClaudeHook → AppModel → UI

### Session discovery (on launch)
Restore cached sessions from registry → discover recent JSONL transcripts (`~/.claude/projects/`) → reconcile with active terminal processes → start live bridge.

## Supported scope (narrow by design)

- **Agents**: Claude Code, Codex, OpenCode, Cursor, Qoder, Qwen Code, Factory, CodeBuddy
- **Terminals**: Terminal.app, Ghostty, iTerm2, WezTerm, cmux, Kaku, Zellij; tmux (multiplexer)
- **IDE workspace jump**: VS Code, Cursor, Windsurf, Trae, JetBrains IDEs
- Do NOT expand scope unless explicitly asked

## Build & test

```bash
swift build
swift test
swift run OpenIslandApp                            # run the app
swift build -c release --product OpenIslandHooks   # build hook binary
```

Open `Package.swift` in Xcode for the app target. Requires macOS 14+, Swift 6.2.

## Required Workflow

> **⚠️ NEVER edit files directly in the main worktree.** Use `EnterWorktree` or `git worktree` to work in an isolated copy.

1. Start each round by checking the current repository state with `git status -sb`.
2. **Enter a worktree** before making any edits — use `EnterWorktree` (preferred) or `git worktree add` to create an isolated working copy based on `main`.
3. Read the relevant files before editing. Do not guess repository structure or behavior.
4. Keep each round focused on a single coherent change.
5. After making changes, run the most relevant verification available for that round.
6. Summarize what changed, including any verification gaps.
7. Commit, push to remote, exit the worktree (`ExitWorktree`), and create a PR to merge into `main`.

## Commit Policy

- Every round that modifies files must end with a commit.
- Do not batch unrelated changes into one commit.
- Use conventional-style commit messages: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`.
- Do not amend existing commits unless explicitly requested.
- Create a feature branch (e.g. `fix/<topic>`, `feat/<topic>`) for every independent change. Do not commit directly to `main`.

## Safety Rules

- Never revert or overwrite user changes unless explicitly requested.
- If unexpected changes appear, inspect them and work around them when possible.
- If a conflict makes the task ambiguous or risky, stop and ask before proceeding.
- Never use destructive Git commands such as `git reset --hard` without explicit approval.

## Active Branch: `feat/scout-minimal`

> **This is the working baseline. All new work branches from here, NOT from `main`.**

On 2026-04-20 we cut `feat/scout-minimal` as a **minimal downstream fork** over `upstream/main`. It re-homes the parts of our long-lived fork that are genuinely additive (pixel scout, Claude Esc detection, Chinese docs, terminal-jump pane title, notch layout fixes, approval-card bypass) and intentionally drops the parts that diverged from upstream's hook protocol (Codex PreToolUse→PermissionRequest rewrite, codex trace logging, codex bypassPermissions/dontAsk behavioral changes).

Why this branch exists: the old `main` had ~6500 lines of diff against upstream — half of it deep rewrites of the Codex hook layer that guaranteed merge conflicts on every `git fetch upstream`. `feat/scout-minimal` is ~1400 lines of mostly-additive delta; merging upstream changes into it will almost never conflict.

**Going forward:**
- Active branch: **`feat/scout-minimal`** (on origin). New features branch from here.
- Legacy `main`: **archive of the old full-fork state**. Do not base new work on it. Keep it around so any commit we decide to re-import (e.g. restoring the Codex PermissionRequest rewrite) can be cherry-picked directly.

## Branching Rules

- **Treat `feat/scout-minimal` as the de-facto trunk for now.** `main` is still the GitHub default / protected branch, but active development targets `feat/scout-minimal` until we decide whether (and when) to promote it to `main`.
- All feature branches must be created from the latest `feat/scout-minimal` (not `main`, not `upstream/main`).
  ```bash
  git fetch origin
  git checkout -b feat/<topic> origin/feat/scout-minimal
  ```
- Each agent or workstream should work on its own branch, named to match the topic (e.g. `feat/<topic>`, `fix/<topic>`).
- Standard flow: **EnterWorktree → develop → commit → push → ExitWorktree → create PR → merge**.
- For parallel Agent sub-tasks, use `Agent(isolation: "worktree")` to give each agent its own isolated copy.
- **All PRs MUST target `feat/scout-minimal` as base branch.** Never target another feature branch. Chain PRs (A → B → trunk) are prohibited — they cause silent change loss when merge order is wrong. If work depends on an unmerged branch, wait for it to merge to `feat/scout-minimal` first, then rebase.

## Upstream Sync

This repo is a **long-lived downstream fork**: `origin` (sunshineww/open-vibe-island) tracks `upstream` (Octane0411/open-vibe-island) as a **strict superset**. We pull upstream changes regularly but **never push back** to upstream.

- `feat/scout-minimal` always equals `upstream/main` + the minimal local delta (scout pixel characters, Claude Esc detection, Chinese docs, etc.). It is *supposed* to be ahead of upstream — do NOT try to remove local commits to "match upstream".
- New feature branches MUST branch from **local `feat/scout-minimal`**, not `upstream/main` and not `main`. Branching from upstream drops local customizations that new work may depend on; branching from `main` pulls in the archived full-fork state you probably don't want.
  ```bash
  git fetch upstream
  git fetch origin
  git checkout -b feat/<topic> origin/feat/scout-minimal
  ```
- To pull upstream changes into the active branch, use `merge` (not `rebase`, not `--ff-only`):
  ```bash
  git fetch upstream
  git checkout feat/scout-minimal
  git merge upstream/main --no-edit
  # resolve conflicts (local customization vs upstream change)
  git push origin feat/scout-minimal
  ```
  `--ff-only` will refuse because the branch is ahead by design.
- All PRs target `origin/feat/scout-minimal`. Never open PRs to `Octane0411/open-vibe-island` — we don't contribute back.
- When resolving sync conflicts: pure additions from upstream (new features they wrote) usually win; local customizations stay on lines they touched. When in doubt, ask.

### Re-importing something that was dropped

If you ever need a commit that `feat/scout-minimal` intentionally dropped (most likely a piece of the Codex改造), it still lives on the archived `origin/main`. Cherry-pick it:
```bash
git fetch origin
git log origin/main --oneline -- <file>   # locate the commit
git checkout -b feat/restore-<topic> origin/feat/scout-minimal
git cherry-pick <sha>
# resolve conflicts, build, commit, PR
```

## Release Policy

- **Bilingual required**: Every release MUST include both English and Chinese (Simplified) descriptions. Use the template in `.github/RELEASE_TEMPLATE.md`.
- Before creating a release, fetch remote `main` and review ALL merged PRs since the last tag to avoid missing changes.
- Each changelog entry follows the format: `- **Category**: English description (#PR)\n  中文描述 (#PR)`. For external contributors, append `— Thanks @username` to the English line.
- The release title follows: `Open Island vX.Y.Z — Short English Title`
- The Installation section must be bilingual.
- Release is triggered by pushing a `v*` tag to `main`. The GitHub Actions workflow builds, signs, notarizes, and publishes the DMG automatically.

## App Targets And Naming

- `OpenIslandApp` (via `swift run OpenIslandApp` or the Xcode target) is the canonical development runtime.
- `~/Applications/Open Island Dev.app` is a local bundle wrapper around the repo-built binary, not a separate product.
- When launching `Open Island Dev.app`, refresh the bundle first with `zsh scripts/launch-dev-app.sh` instead of only `open -na` (avoids stale binaries).
- **One-time setup**: run `zsh scripts/setup-dev-signing.sh` once to create a local self-signed code signing identity. Without it the dev bundle is ad-hoc signed, which changes cdhash every rebuild and silently invalidates any macOS TCC grant (Accessibility, Automation) you gave the previous build. Required when iterating on features that touch AX API (precision jump, keystroke/menu injection, etc.).
- Use `scripts/harness.sh smoke` or `scripts/smoke-dev-app.sh` only for deterministic harness runs.
- `/Applications/Vibe Island.app` and `https://vibeisland.app/` are closed-source reference baselines only — behavior benchmarks, not the development runtime.

## Reference Baselines

- Official product reference: `https://vibeisland.app/`
- On Macs with a built-in notch, the island sits in the notch area; on external displays or non-notch Macs, it falls back to a compact top-center bar.
- Community reference: `https://github.com/farouqaldori/claude-island` — useful for design patterns, not a product spec.
- Do NOT import from `claude-island` unless explicitly asked: analytics (Mixpanel etc.), window-manager scope (`yabai`), Claude-only assumptions that weaken the shared agent model, raising the support boundary beyond the surfaces already listed.

## Conventions

- Prefer small end-to-end slices over speculative scaffolding
- Native macOS APIs over cross-platform abstractions
- Hooks fail open — if app/bridge unavailable, agents keep running unchanged
- The `SessionState.apply(_:)` reducer is the single source of truth for session mutations
- Bridge protocol uses newline-delimited JSON envelopes (`BridgeCodec`)
- All models are `Sendable` and `Codable`

## Verification

- Run targeted checks that match the change (`swift build`, `swift test`, or manual verification).
- If no automated verification exists yet, state that explicitly in the summary and still commit.

## Important files

- `Sources/OpenIslandApp/AppModel.swift` — Central app state, session management, bridge lifecycle
- `Sources/OpenIslandApp/TerminalSessionAttachmentProbe.swift` — Ghostty/Terminal attachment matching
- `Sources/OpenIslandApp/ActiveAgentProcessDiscovery.swift` — Process discovery via ps/lsof
- `Sources/OpenIslandCore/SessionState.swift` — Pure state reducer for agent sessions
- `Sources/OpenIslandCore/AgentSession.swift` — Core session model and related types
- `Sources/OpenIslandCore/AgentEvent.swift` — Event enum driving all state transitions
- `Sources/OpenIslandCore/BridgeTransport.swift` — Unix socket protocol, codec, envelope types
- `Sources/OpenIslandCore/BridgeServer.swift` — Bridge server handling hook payloads
- `Sources/OpenIslandCore/ClaudeHooks.swift` — Claude Code hook payload model and terminal detection
- `Sources/OpenIslandCore/ClaudeTranscriptDiscovery.swift` — Discovers sessions from `~/.claude/projects/` JSONL files
- `Sources/OpenIslandCore/ClaudeSessionRegistry.swift` — Persists/restores Claude sessions across app launches
- `Sources/OpenIslandCore/CodexHooks.swift` — Codex hook payload model
- `Sources/OpenIslandHooks/main.swift` — Hook CLI entry point
- `Sources/OpenIslandApp/OverlayPanelController.swift` — Notch/top-bar overlay window
- `docs/product.md` — Product scope and MVP boundary
- `docs/architecture.md` — System design and engineering decisions
- `AGENTS.md` — Working agreement for agent workflow
