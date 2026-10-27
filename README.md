# AIusage

AIusage 是一个 macOS 菜单栏应用，用来看 Codex、Claude Code 和 Cursor 的额度和 Token 用量。

## 功能

- Codex：读取 app-server 的实时额度、重置倒计时和账号累计 Token
- Claude Code：读取本机 `~/.claude/projects` 的会话记录，按模型统计今日 / 7 天 / 30 天 / 累计 Token，并显示每日活动热力图
- Cursor：读取本机已登录的 Cursor 账号，显示当前周期剩余额度、Auto / API 占用，以及按模型汇总的 Token 用量
- 支持详细条和圆形磨砂悬浮窗
- Codex 低额度通知、断线重连和本地缓存
- 根据剩余额度自动切换绿、黄、红状态色

Claude 的会话文件按大小和修改时间缓存，刷新只重读有变化的会话。Cursor 的用量记录会缓存在本机，之后只补拉新记录。

## 运行要求

- macOS 14 或更高版本
- Codex 页签：已安装 ChatGPT 桌面端或 Codex CLI，且 Codex 已登录
- Claude 页签：本机有 Claude Code 会话目录 `~/.claude/projects`
- Cursor 页签：已安装并登录 Cursor

Codex 可执行文件按这个顺序查找：

1. `/Applications/ChatGPT.app/Contents/Resources/codex`
2. `/opt/homebrew/bin/codex`
3. `/usr/local/bin/codex`
4. 登录 Shell 的 `PATH`

## 本地构建

```bash
xcodebuild \
  -project AIusage.xcodeproj \
  -scheme AIusage \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

构建结果位于：

```text
build/DerivedData/Build/Products/Release/AIusage.app
```

## 只有 Command Line Tools 时构建

没有安装 Xcode.app 时，`xcodebuild` 不可用，可以用脚本直接调 `swiftc` 打包：

```bash
./scripts/build-clt.sh
```

输出在 `build/clt/AIusage.app`。图标资源需要 actool，没有 Xcode 时脚本会复用之前构建产物里的 `Assets.car`。

## 生成 DMG

```bash
./scripts/package-dmg.sh
```

输出文件位于 `dist/AIusage-<版本号>.dmg`。DMG 内包含 App 和 Applications 文件夹快捷方式，可直接拖拽安装。

未使用 Apple Developer ID 签名和公证的 DMG，在其他 Mac 上首次打开时会触发 Gatekeeper 提示。完整公开分发需要：

1. Apple Developer Program 账号
2. `Developer ID Application` 证书
3. `notarytool` 钥匙串凭据

配置好以后执行：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="codex-meter" \
./scripts/package-dmg.sh
```

脚本会执行 Hardened Runtime 签名、提交 Apple 公证并装订公证票据。
