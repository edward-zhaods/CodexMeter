# MenuBar Pets

独立的 macOS 菜单栏应用。Codex、Cursor、Gemini、Claude 四只像素宠物并排站在菜单栏里。它不改额度应用 AIusage。

点菜单栏可以看每个人是工作中、闲着还是休假中。图鉴用 `Art` 里的透明 PNG，同名 SVG 是源文件。

最近三分钟内本机对应目录有写入，就显示工作中。Claude 可以手动休假。

## 编译

在 Mac 上安装 Command Line Tools 后，进入这个目录：

```bash
./scripts/build-clt.sh
open build/clt/MenuBarPets.app
```

需要 macOS 14 或更高版本。
