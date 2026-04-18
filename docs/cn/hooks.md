# Hook 协议（中文速览）

本文是 [../hooks.md](../hooks.md) 的中文摘要版。完整字段表与权威定义以英文原文 + 对应源码为准。

## 总体架构

```
Agent (Codex / Claude Code / Gemini CLI …)
  │  stdin: JSON payload
  ▼
OpenIslandHooks CLI  (--source codex | --source claude | --source gemini | --source cursor)
  │  Unix socket
  ▼
BridgeServer ──► AppModel ──► UI
  │  BridgeResponse
  ▼
OpenIslandHooks CLI
  │  stdout: JSON 指令（仅在需要时）
  ▼
Agent
```

**Fail-open 原则**：Bridge 不可用时，Hook 进程**静默退出**、不写 stdout。对 Agent 而言无感。

入口源码：[`Sources/OpenIslandHooks/OpenIslandHooksCLI.swift`](../../Sources/OpenIslandHooks/OpenIslandHooksCLI.swift)

## Codex Hook（`--source codex`）

| 事件 | 触发时机 | 是否可响应 |
|------|----------|------------|
| `SessionStart` | 会话开始或 resume | 否 |
| `PreToolUse` | Shell 命令执行前 | ✅ 可 block |
| `PostToolUse` | Shell 命令执行后 | 否 |
| `UserPromptSubmit` | 用户提交新 Prompt | 否 |
| `Stop` | 一轮结束 | 否 |

`PreToolUse` 可通过写回以下 JSON 阻止命令：

```json
{"decision": "block", "reason": "Blocked by Open Island"}
```

## Claude Code Hook（`--source claude`）

| 事件 | 可响应 | 说明 |
|------|--------|------|
| `SessionStart` | 否 | `startup` / `resume` / `clear` / `compact` |
| `SessionEnd` | 否 | |
| `UserPromptSubmit` | 否 | |
| `PreToolUse` | ✅ | allow / deny / ask / 替换输入 |
| `PostToolUse` | 否 | |
| `PostToolUseFailure` | 否 | |
| **`PermissionRequest`** | ✅ | **24 小时超时**，等待用户在 UI 中审批 |
| `PermissionDenied` | 否 | |
| `Notification` | 否 | |
| `Stop` / `StopFailure` | 否 | |
| `SubagentStart` / `SubagentStop` | 否 | |
| `PreCompact` | 否 | |

**PreToolUse 指令**：

```json
{
  "continue": true,
  "suppressOutput": true,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow | deny | ask",
    "permissionDecisionReason": "给 Agent 看的原因",
    "updatedInput": { /* 可选：替换工具入参 */ },
    "additionalContext": "可选：注入额外上下文"
  }
}
```

**PermissionRequest 指令**（Allow 示例）：

```json
{
  "continue": true,
  "suppressOutput": true,
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow",
      "updatedInput": { ... },
      "updatedPermissions": [ ... ]
    }
  }
}
```

Deny 时可以带 `"interrupt": true` 立刻终止当前 turn。

## Gemini CLI Hook（`--source gemini`）

| 事件 | 当前行为 |
|------|----------|
| `SessionStart` | 创建 / 恢复 Gemini 会话，写入 title、跳回目标、transcript 元信息 |
| `BeforeAgent` | 标记会话 Running，刷新 Prompt 与终端元数据 |
| `AfterAgent` | 标记 turn 结束，发出完成卡片 |
| `SessionEnd` | 标记会话终结 |
| `Notification` | 更新 Session 摘要 / 活动文本 |

**当前限制**：Gemini Hook 在 Open Island 里是 fire-and-forget，**不**往 stdout 写回指令。

## 超时策略

| 来源 | 事件 | 超时 |
|------|------|------|
| Codex | 全部 | Bridge 默认 |
| Claude Code | `PermissionRequest` | **24 小时** |
| Claude Code | 其他 | **45 秒** |
| Gemini CLI | 全部 | Bridge 默认 |

## 终端自动识别

Hook 进程在运行时读取环境变量推断终端：

| 环境变量 | 推断结果 |
|----------|----------|
| `ITERM_SESSION_ID` 或 `LC_TERMINAL=iTerm2` | `iTerm` |
| `CMUX_WORKSPACE_ID` / `CMUX_SOCKET_PATH` | `cmux` |
| `GHOSTTY_RESOURCES_DIR` | `Ghostty` |
| `WARP_IS_LOCAL_SHELL_SESSION` | `Warp` |
| `TERM_PROGRAM=Apple_Terminal` | `Terminal` |
| `TERM_PROGRAM=WezTerm` | `WezTerm` |

对 iTerm、Terminal、Ghostty，Hook 进程还会额外执行 AppleScript 查询拿到 session ID、TTY、窗口标题，用于支撑「跳回终端」能力；cmux 则使用 `CMUX_SURFACE_ID`。

## 相关源文件

| 文件 | 职责 |
|------|------|
| `Sources/OpenIslandHooks/OpenIslandHooksCLI.swift` | Hook CLI 入口，分发到 Codex / Claude / Gemini / Cursor 路径 |
| `Sources/OpenIslandCore/CodexHooks.swift` | Codex payload 模型、输出编码、终端识别 |
| `Sources/OpenIslandCore/ClaudeHooks.swift` | Claude Code payload 模型、指令类型、输出编码 |
| `Sources/OpenIslandCore/GeminiHooks.swift` | Gemini CLI payload 模型、终端识别、元数据辅助 |
| `Sources/OpenIslandCore/BridgeServer.swift` | Unix socket 服务端，处理入站 Hook payload |
| `Sources/OpenIslandCore/BridgeTransport.swift` | 协议编解码与 envelope 类型 |
