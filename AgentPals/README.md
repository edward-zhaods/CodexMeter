# AgentPals

AgentPals 是一个 macOS 菜单栏应用。状态栏里从左到右一直站着三个小人：Claude、Codex、Cursor。

谁在干活，谁就一直敲键盘。闲着的时候手放下，大约每 4 秒眨一下眼。三个角色各有一个只有干活时才动的小道具：Claude 的纸上会多出行，Codex 头顶的绿火花会轮流亮，Cursor 的指针旁边会闪点击痕迹。

点一下状态栏可以看到三行「工作中 / 闲着」，以及退出。系统打开「减少动态效果」时，小人停在静止姿势。这个应用不显示用量。

## 怎么判断在干活

只读本机已经写好的会话文件，不安装 hook，也不把正在运行的 Codex app-server 当成在干活。

- Claude Code：`~/.claude/projects` 里的 `.jsonl`，包括子代理。尾巴已经是 `cost-state` 或回合结束，就马上算闲着。
- Codex：今天和昨天的 `~/.codex/sessions/年/月/日/*.jsonl`。最近的任务事件是 `task_complete` 或 `turn_aborted` 就闲着；还在 `task_started`、工具调用或输出里就干活。
- Cursor：本机会话列表两分钟内有更新，或者云端代理的状态还是进行中，就算干活。会话记录在 `~/.cursor/projects/*/agent-transcripts/**/*.jsonl`，最后一条是 `turn_ended` 就闲着。Cursor 开着本身不算干活。

Claude 和 Codex 的文件超过 45 秒没有新内容，也回到闲着。这样一次长思考中间的短暂停顿不会闪回眨眼。Cursor 一轮经常很久不写记录，所以另看会话列表和云端代理状态。

## 构建并放进「应用程序」

需要 macOS 14 或更高版本，以及 Swift 命令行工具。在项目的 `AgentPals` 目录里运行一次：

```bash
./scripts/build-clt.sh
```

脚本会编译，并把它装到「应用程序」里的 `AgentPals.app`。图标是这三只小人。已经在跑的旧进程会被关掉。装好后如果还是空白图标，运行一次 `killall Finder`。

以后打开：打开「应用程序」文件夹（或聚焦搜索），双击 **AgentPals**。它没有 Dock 图标，打开后看菜单栏右侧。

关闭：点菜单栏里的小人，选「退出」。重启电脑之后不会自己打开，需要再双击一次。

如果系统提示无法打开，在图标上按住 Control 点一下，选「打开」。

三个小人大约四个图标那么宽。按住 Command 可以拖动它们的位置。只编译、不安装时用 `INSTALL=0 ./scripts/build-clt.sh`。
