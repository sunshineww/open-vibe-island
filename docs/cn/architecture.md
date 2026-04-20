# 技术方案

本文档介绍 Open Island 的整体架构、数据流、关键模块和技术选型，面向希望快速理解项目内部机制或参与贡献的开发者。

## 1. 代码结构

Open Island 是一个 **Swift Package**，最低要求 macOS 14 / Swift 6.2，包含 **4 个 target**：

| Target | 类型 | 职责 |
|--------|------|------|
| **OpenIslandApp** | Executable | SwiftUI + AppKit 壳：菜单栏图标、刘海 / 顶栏 Overlay 面板、控制中心窗口、设置窗口。入口为 `OpenIslandApp.swift`，中枢状态由 `AppModel`（`@Observable`）持有。 |
| **OpenIslandCore** | Library | 共享核心库：模型（`AgentSession` / `AgentEvent` / `SessionState`）、Bridge 传输协议（Unix socket + 行分隔 JSON）、各 Agent 的 Hook 模型 / 安装器、transcript 发现、会话持久化。 |
| **OpenIslandHooks** | Executable CLI | 轻量 Hook 辅助进程。从 stdin 读取 Agent 的 Hook payload，通过 Unix socket 转发给 App；只在需要（比如阻止一次 `PreToolUse`）时才往 stdout 写回指令。 |
| **OpenIslandSetup** | Executable CLI | 安装器 CLI，负责管理 `~/.codex/config.toml`、`hooks.json` 等配置。 |

外部依赖只有两个：

- **swift-markdown-ui** —— 渲染 Agent 发来的 Markdown 内容
- **Sparkle** —— 自动更新

## 2. 数据流总览

### 2.1 基于 Hook 的 Agent（Codex / Claude Code / Gemini CLI 及其 fork）

```
┌──────────────┐
│    Agent     │   （Claude Code / Codex / Gemini / Cursor …）
└──────┬───────┘
       │ stdin: JSON payload
       ▼
┌─────────────────────────────┐
│      OpenIslandHooks CLI    │   --source codex|claude|gemini|cursor
└──────┬──────────────────────┘
       │ Unix Domain Socket
       ▼
┌─────────────────────────────┐
│  BridgeServer (App 进程内)  │
└──────┬──────────────────────┘
       │  AgentEvent
       ▼
┌─────────────────────────────┐
│  AppModel / SessionState    │ ──► SwiftUI 小岛 / 控制中心
└──────┬──────────────────────┘
       │ BridgeResponse (可选)
       ▼
┌─────────────────────────────┐
│      OpenIslandHooks CLI    │
└──────┬──────────────────────┘
       │ stdout: 指令 JSON（仅在需要时）
       ▼
┌──────────────┐
│    Agent     │
└──────────────┘
```

### 2.2 基于插件的 Agent（OpenCode）

```
OpenCode
   └─► ~/.config/opencode/plugins/ 下的 JS 插件
          └─► Unix socket ──► BridgeServer ──► AppModel ──► UI
```

### 2.3 启动时的会话发现流程

1. 从本地 **会话注册表**（`ClaudeSessionRegistry` 等）恢复上次记录的 Session
2. 扫描 `~/.claude/projects/` 下最近的 **JSONL transcript** 文件，发现休眠中的会话
3. 通过 `ps` / `lsof` 的 `ActiveAgentProcessDiscovery` **核对**哪些 Agent 进程现在真的活着
4. 启动 BridgeServer，接入后续实时事件

### 2.4 失败不打扰（Fail-open）

如果 App / Bridge 没在运行，`OpenIslandHooks` 进程会**静默退出**、不往 stdout 写任何东西。对 Agent 来说，就像这个 Hook 不存在一样，Agent 会继续正常运行。这一原则保证：**装了 Open Island 不会拖慢或阻塞你的 Agent**。

## 3. 事件模型

所有状态变更由共享的 `AgentEvent` 枚举驱动（定义在 `Sources/OpenIslandCore/AgentEvent.swift`）：

- 会话开始 / 更新 / 结束
- 权限请求（Permission Requested）
- 提问（Question Asked）
- 工具调用前 / 后（PreToolUse / PostToolUse）
- 子 Agent 生命周期（SubagentStart / SubagentStop）
- 跳回目标更新（Jump target updated）

每个事件都携带稳定的 **Session ID**、Agent 类型、时间戳，以及**足够的元数据**（TTY、终端 App、窗口标题、tool_use_id 等）来支持后续的审批回传和终端定位。

## 4. 状态管理

- **单一真相源**：`SessionState.apply(_:)` 是所有 Session 变更的**唯一纯函数 reducer**。任何事件 → 任何状态变化，都必须经过它。
- **AppModel**：持有所有实时状态和 Bridge 生命周期，是 SwiftUI 视图的 `@Observable` 数据源。
- **Sendable & Codable**：所有模型都满足这两个协议，既支持 Swift 6 并发安全，又能原生序列化用于持久化 / IPC。

## 5. 传输层（Bridge）

| 维度 | 设计 |
|------|------|
| 协议 | **Unix Domain Socket**（本地 App ↔ Hook CLI） |
| 编解码 | **行分隔 JSON 信封**（`BridgeCodec`），一行一个 envelope，便于调试与 tail |
| 服务端位置 | `BridgeServer` 运行在 **App 进程内**，随 App 启动 / 关闭 |
| 客户端 | `OpenIslandHooks`、`BridgeCommandClient`、`LocalBridgeClient` 等 |

选择 Unix Socket + 行分隔 JSON 的原因：

- 纯本地通信，不走网络，**零端口占用、零防火墙麻烦**
- 行分隔 JSON 易于人眼读和命令行调试（`nc -U` + `jq`）
- 为未来的 adapter（比如给其他 Agent 写 Hook）保留最简单的接入形式

## 6. 终端精准跳回（Jump-back）

不同终端提供的定位能力差异很大，因此每种终端都有专门的策略：

| 终端 | 跳回策略 |
|------|----------|
| Terminal.app | 通过 AppleScript 按 **TTY** 匹配 Tab |
| Ghostty | 按 **Window ID** 匹配 |
| cmux | 通过 **Unix socket API** 切换 pane |
| Kaku | **CLI pane targeting** |
| WezTerm | **CLI pane targeting** |
| iTerm2 | AppleScript 按 **Session ID / TTY** 探测 |
| tmux（多路复用器） | `switch-client` → `select-window` → `select-pane` |
| VS Code / Cursor / Windsurf / Trae / JetBrains 系 | 通过 IDE 自带的 URL Scheme / CLI 打开 workspace |

**元数据从哪来？** Hook CLI 在被 Agent 调用的**那一刻**，会读取当时的环境变量（如 `ITERM_SESSION_ID`、`GHOSTTY_RESOURCES_DIR`、`TERM_PROGRAM`、`TMUX`、`CMUX_SURFACE_ID` 等）并附加到 payload，App 之后就能凭这些 hint 精确跳回。

## 7. Hook 支持的 Agent 差异

| Agent | 事件覆盖 | 是否支持双向指令 | 超时 |
|-------|----------|------------------|------|
| Codex | SessionStart / PreToolUse / PostToolUse / UserPromptSubmit / Stop | ✅（PreToolUse 可 block） | Bridge 默认 |
| Claude Code | SessionStart / SessionEnd / UserPromptSubmit / PreToolUse / PostToolUse / PostToolUseFailure / **PermissionRequest** / PermissionDenied / Notification / Stop / StopFailure / SubagentStart / SubagentStop / PreCompact | ✅（PreToolUse + PermissionRequest） | PermissionRequest **24 小时**，其他 **45 秒** |
| Gemini CLI | SessionStart / BeforeAgent / AfterAgent / SessionEnd / Notification | ❌（fire-and-forget） | Bridge 默认 |

Claude 的 fork（Qoder / Qwen Code / Factory / CodeBuddy）共用 Claude 的 payload schema，只是配置文件落在各自的 `~/.xxx/settings.json`。

更详细的字段说明见 [hooks.md](./hooks.md) 和英文原文 [../hooks.md](../hooks.md)。

## 8. UI 层

| 组件 | 职责 |
|------|------|
| `OverlayPanelController` | 刘海 / 顶栏位置的 `NSPanel`，常驻顶层、避开物理摄像头 |
| `IslandSurface` / `IslandPanelView` | 小岛的形状与内部视图 |
| `ScoutBadgeView` | 右侧的动态徽章（展示当前 Agent 状态） |
| `ControlCenterWindowController` / `ControlCenterView` | 控制中心主窗口 |
| `SettingsView` 及 Pane | 通用 / 显示 / 声音 / 快捷键 / 实验室 / 关于 |

**关键技术选型**：
- **SwiftUI** 承担大部分视图组合
- **AppKit** 负责面板层级、状态栏 Item、激活策略等 SwiftUI 触达不到的边角
- 所有形状采用自定义 `Shape`（如 `NotchShape`），保证与物理刘海像素级贴合

## 9. 配置安装流程

`OpenIslandSetup` CLI 及 App 内置的 `HookInstallationCoordinator` 负责向各 Agent 注入 Hook：

- **Codex**：写入 `~/.codex/config.toml` 的 `hooks.json`
- **Claude Code / 各 fork**：写入 `~/.claude/settings.json`（或 fork 对应路径）的 `hooks` 配置
- **Gemini CLI**：写入 `~/.gemini/settings.json`
- **Cursor**：写入 `~/.cursor/hooks.json`
- **OpenCode**：把 JS 插件放到 `~/.config/opencode/plugins/`

所有写入都是**可逆的**：App 提供一键卸载，且不会污染用户已有的其他 Hook 配置。

## 10. 打包与发布

- **Dev 运行**：`swift run OpenIslandApp`（或 Xcode）是开发期的标准运行方式
- **Dev 本地 bundle**：`~/Applications/Open Island Dev.app` 包裹仓库里构建出的二进制，由 `scripts/launch-dev-app.sh` 刷新
- **自签身份**：`scripts/setup-dev-signing.sh` 一次性创建本地自签证书，避免每次 rebuild 都让 macOS 的 TCC 授权（辅助功能、自动化）失效
- **Release**：向 `main` 推 `v*` tag 后触发 GitHub Actions，自动完成 **构建 → 签名 → 公证 → 发布 DMG**
- **自动更新**：基于 Sparkle 的 appcast

## 11. 工程约定

- 倾向**小而完整**的端到端切片，而不是铺垫性质的脚手架
- 优先使用**原生 macOS API**，不引入跨平台抽象
- **Fail open**：任何 Hook 故障都不能影响 Agent 本身
- `SessionState.apply(_:)` 是 Session 变更的**唯一入口**
- Bridge 协议使用**行分隔 JSON**，利于调试与适配
- 所有模型满足 `Sendable` + `Codable`
- 主分支（`main`）受保护：**一律通过 PR 合入，禁止直推**
- 每次改动都在 **git worktree** 中进行，并通过 feature 分支 → PR → 合并

## 12. 关键源文件速查

| 文件 | 职责 |
|------|------|
| `Sources/OpenIslandApp/AppModel.swift` | App 中枢状态、会话管理、Bridge 生命周期 |
| `Sources/OpenIslandApp/TerminalSessionAttachmentProbe.swift` | Ghostty / Terminal 的终端归属匹配 |
| `Sources/OpenIslandApp/ActiveAgentProcessDiscovery.swift` | 通过 `ps` / `lsof` 发现活跃进程 |
| `Sources/OpenIslandCore/SessionState.swift` | Session 状态的纯函数 reducer |
| `Sources/OpenIslandCore/AgentSession.swift` | Session 模型 |
| `Sources/OpenIslandCore/AgentEvent.swift` | 驱动所有状态变更的事件枚举 |
| `Sources/OpenIslandCore/BridgeTransport.swift` | Unix socket 协议、codec、envelope 类型 |
| `Sources/OpenIslandCore/BridgeServer.swift` | Bridge 服务端，负责接收 Hook payload |
| `Sources/OpenIslandCore/ClaudeHooks.swift` | Claude Code Hook payload 模型 |
| `Sources/OpenIslandCore/ClaudeTranscriptDiscovery.swift` | 从 JSONL transcript 发现会话 |
| `Sources/OpenIslandCore/ClaudeSessionRegistry.swift` | 跨启动持久化 Claude 会话 |
| `Sources/OpenIslandCore/CodexHooks.swift` | Codex Hook payload 模型 |
| `Sources/OpenIslandHooks/OpenIslandHooksCLI.swift` | Hook CLI 入口点 |
| `Sources/OpenIslandApp/OverlayPanelController.swift` | 刘海 / 顶栏 Overlay 面板 |
