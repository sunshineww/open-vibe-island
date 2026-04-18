# 项目概览

## Open Island 是什么

**Open Island** 是一款原生 macOS 伴随应用，为终端里的 AI 编码 Agent（Claude Code、Codex、Cursor、Gemini CLI、OpenCode 等）提供一个常驻在「刘海 / 顶栏」区域的轻量控制面板。

它对标商业产品 [Vibe Island](https://vibeisland.app/)，但完全开源（GPL v3）、完全本地化、不依赖任何服务器，也不收集任何遥测数据。

一句话定位：**CLI Agent 的原生 macOS 控制中心**。

## 要解决什么问题

当开发者日常使用终端里的 AI Agent 时，会遇到这些痛点：

1. **注意力被拉扯**：Agent 在后台跑任务，但用户必须不停切回终端才能看到状态、审批权限请求、回答 Agent 的提问。
2. **多会话难以管理**：同时开了好几个终端窗口、每个窗口里跑着不同的 Agent，很难一眼看清"谁在干什么"。
3. **回跳定位成本高**：Agent 弹出一个需要人工介入的问题，但用户不一定记得是哪个终端、哪个 Tab、哪个 tmux pane 在等自己。
4. **闭源方案不可控**：市场上类似体验的商业产品是闭源付费的，对开发者不够透明。

Open Island 把 Agent 的关键生命周期事件 —— 会话开始/结束、权限请求、工具调用、子 Agent、问题提问等 —— 通过 Hook 机制转发到刘海上的小岛 UI，让用户在不切换焦点的前提下完成监控和审批；当需要进一步介入时，点一下小岛就能**精准跳回对应的终端会话**。

## 目标用户

- 每天使用终端 CLI Agent 的 macOS 开发者
- 同时运行多个 Agent 或多个终端会话的用户
- 关心低延迟、原生体验、开源透明度的用户

## 产品原则

| 原则 | 含义 |
|------|------|
| **开源（Open source）** | 所有代码公开，以 GPL v3 授权 |
| **本地优先（Local first）** | 不依赖任何服务器、不收集遥测、不需要账号 |
| **原生 macOS（Native macOS）** | SwiftUI + AppKit，不使用 Electron / 网页壳 |
| **终端原生（Terminal-native）** | 增强终端工作流，不是取代终端 |
| **失败不打扰（Fail open）** | App 或 Bridge 不可用时，Hook 进程静默退出，Agent 本身不受影响 |

## 支持的 Agent

| Agent | 状态 | 说明 |
|-------|------|------|
| **Claude Code** | 已支持 | Hook 集成、JSONL 会话发现、状态栏桥接、用量统计 |
| **Codex** | 已支持 | 完整 Hook 集成（SessionStart / UserPromptSubmit / Stop），用量统计 |
| **OpenCode** | 已支持 | JS 插件集成，权限与提问流程，进程检测 |
| **Cursor** | 已支持 | 通过 `~/.cursor/hooks.json` 集成，工作区跳回 |
| **Gemini CLI** | 已支持 | Hook 集成（SessionStart / BeforeAgent / AfterAgent / SessionEnd / Notification） |
| **Qoder / Qwen Code / Factory / CodeBuddy** | 已支持 | Claude Code fork，Hook 格式一致，只是配置路径不同 |

## 支持的终端 / IDE

- **终端类**：Terminal.app、Ghostty、iTerm2、WezTerm、cmux、Kaku、tmux（多路复用器）、Zellij
- **IDE 工作区跳回**：VS Code、Cursor、Windsurf、Trae、JetBrains 全家桶（IDEA / WebStorm / PyCharm / GoLand / CLion / RubyMine / PhpStorm / Rider / RustRover）
- **规划中**：Warp（目前仅 fallback 检测）

## 核心功能

1. **刘海小岛 Overlay**
   - 有刘海的 Mac：小岛正好坐落在刘海区域
   - 无刘海或外接屏：退化为顶部居中的紧凑条
   - 实时展示当前活跃 Agent 会话的状态

2. **控制中心（Control Center）**
   - Hook 安装 / 卸载状态一览
   - 用量仪表板（Claude / Codex）
   - 快速管理所有会话

3. **通知模式（Notification Mode）**
   - 权限请求弹窗（Claude Code 的 `PermissionRequest` 支持 24 小时超时）
   - 可配置系统通知音
   - 支持静音

4. **会话发现与持久化**
   - 从 `~/.claude/projects/` 下的 JSONL transcript 自动发现会话
   - 通过 `ps` / `lsof` 匹配实际活跃的 Agent 进程
   - 跨 App 重启保持会话注册表（registry）

5. **终端精准跳回（Jump-back）**
   - 根据终端类型选择最合适的定位策略（TTY / Window ID / AppleScript / tmux switch-client 等）
   - 一键把焦点拉回到**发出该 Agent 事件的那个终端窗口 / Tab / Pane**

6. **国际化**
   - 英文 / 简体中文

7. **分发 & 更新**
   - DMG 打包、代码签名、公证（notarization）
   - GitHub Actions 自动化 Release 流水线
   - Sparkle 自动更新 + appcast

## 成功标准

- Agent 事件在小岛里低延迟显示
- 用户的审批 / 回答动作能可靠送回到 Agent 进程
- 能稳定地把焦点还原到事件源终端窗口
- 空闲资源占用足够低，可以全天后台运行
