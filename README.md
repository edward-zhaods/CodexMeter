# Codex Meter

Codex Meter 是一个 macOS 菜单栏应用，用来显示 Codex 额度、重置倒计时和账号累计 Token 用量。

## 功能

- 读取 Codex app-server 的实时额度数据
- 显示额度剩余百分比和重置倒计时
- 显示账号累计 Token 用量
- 支持详细条和圆形磨砂悬浮窗
- 低额度通知、断线重连和本地缓存
- 根据剩余额度自动切换绿、黄、红状态色

## 运行要求

- macOS 14 或更高版本
- 已安装 ChatGPT 桌面端或 Codex CLI
- Codex 已登录可用账号

应用优先查找：

1. `/Applications/ChatGPT.app/Contents/Resources/codex`
2. `/opt/homebrew/bin/codex`
3. `/usr/local/bin/codex`
4. 登录 Shell 的 `PATH`

## 本地构建

```bash
xcodebuild \
  -project CodexMeter.xcodeproj \
  -scheme "Codex Meter" \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

构建结果位于：

```text
build/DerivedData/Build/Products/Release/Codex Meter.app
```

## 生成 DMG

```bash
./scripts/package-dmg.sh
```

输出文件位于 `dist/CodexMeter-<版本号>.dmg`。DMG 内包含 App 和 Applications 文件夹快捷方式，可直接拖拽安装。

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
