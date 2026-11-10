# 04 · 构建：每份产物怎么生成

全部脚本**零依赖**，只要有 Node 18+ 就能跑。没有 `npm install`。

## 命令表

| 想做什么 | 命令 |
|---|---|
| 改完模板，重新生成浏览器版 | `node tools/patch_game_i18n.cjs` |
| 改完模板，重新生成 Godot 数据 | `node tools/extract_game_data.cjs` |
| 两个一起（推荐） | `node tools/sync_godot_data.cjs` |
| 校验轻考核题库 | `node tools/check_review.cjs` |
| 从 review.html 抽题给 live/ 用 | `node tools/extract_quiz.cjs` |
| 起现场答题服务 | `node live/server.mjs 8788` |
| 端到端测后端 | `node tools/test_live.mjs` |
| Godot 自测 | 见下 |
| 导出 exe / web | 见「导出」一节 |

## 生成链

```
src/game.template.html
   ├─(patch_game_i18n.cjs)──→ game.html          内联 567 条词典，单文件离线
   └─(extract_game_data.cjs)─→ godot/data/game.json
data/game-i18n.json
   └─(sync)─────────────────→ godot/data/game-i18n.json   副本
review.html
   └─(extract_quiz.cjs)─────→ data/quiz.json     给 live/ 用
```

**不要手改 `game.html` / `godot/data/*.json`**：它们是生成物，下一次生成就被覆盖。

## Godot 命令

```powershell
$g = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$p = "E:\godot_workplace\E-tech\tradeoff-sim\godot"

# 第一次（或加了新脚本）必须 import，否则 class_name 找不到
& $g --headless --path $p --import

# 15 条断言
& $g --headless --path $p --script "res://tests/selftest.gd"

# 截图（无头环境看不到窗口，用它验证画面）
& $g --path $p --script "res://tests/shot.gd" -- --out=C:\tmp\a.png --frames=300 --auto=1
```

`selftest.gd` 的坑：**`SCRIPT ERROR` 不影响退出码**，必须额外 grep 一遍。

## 导出：一份 exe，一份 web

一条命令就够（Godot 导出到 `godot/build/`，脚本再收进 `dist/`）：

```powershell
powershell -File tools/package.ps1            # 导出 + 压缩 + 摆进 dist/（pwsh 也行）
powershell -File tools/package.ps1 -SkipExport  # 只重新压缩，不碰 Godot
```

产出：

| 文件 | 说明 |
|---|---|
| `dist/win/One-Week-Basket.exe` | Windows 单文件，pck 已内嵌，双击即跑 |
| `dist/one-week-basket-web.zip` | 解压到任意静态站；**必须走 http(s)**，双击 `index.html` 打不开（wasm 要同源） |

`dist/` 不进仓库（`.gitignore` 挡着），发布走 GitHub Releases。

要手动跑，`godot/export_presets.cfg` 里两个 preset 的输出路径是 `godot/build/`：

```powershell
$g = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$p = "E:\godot_workplace\E-tech\tradeoff-sim\godot"

# Windows：单文件，pck 已内嵌，拷走就能跑
& $g --headless --path $p --export-release "Windows Desktop" "$p\build\win\One-Week-Basket.exe"

# Web：一个目录，必须走 http 服务
& $g --headless --path $p --export-release "Web" "$p\build\web\index.html"
```

实测体积：exe **45.8 MB**（内嵌 pck）；web **wasm 38.6 MB + pck 226 KB + js 273 KB**，zip 后 **9.9 MB**。

Web 侧的两个开关：`variant/thread_support=false`（不开线程，就不需要 COOP/COEP 响应头）、
`variant/extensions_support=false`（不依赖 SharedArrayBuffer，静态托管即可）。
如果部署到需要跨域隔离的站点，再开线程并补齐 `Cross-Origin-Opener-Policy: same-origin` /
`Cross-Origin-Embedder-Policy: require-corp`。

导出前必须装 4.7.2 的 export templates（`%APPDATA%\Godot\export_templates\4.7.2.stable\`）；
缺模板时 `--export-release` 会直接报错退出。

## shot.gd 的参数

| 参数 | 作用 |
|---|---|
| `--out=` | 存的绝对路径 |
| `--frames=` | 跑多少帧后截图 |
| `--auto=1` | 第 3 帧点「开始这一周」，之后每 N 帧点一次对话 |
| `--every=` | 自动点击的间隔（默认 26 帧） |
| `--stopask=1` | 碰到选项就停手，用来截选项态 |
| `--nocurtain=1` | 关掉换场黑幕（黑幕淡入没走完会截到半灰画面） |
| `--lang=0\|1\|2` | 语言 |
| `--bare=1` | 只画舞台，不建 UI 层 |
| `--dump=1` | 打印整棵 UI 树（名字/类型/颜色），排查「为什么这层是灰的」用 |

## 两个 i18n 守门测试

| 测试 | 命令 | 查什么 |
|---|---|---|
| 数据覆盖 | `& $g --headless --path godot --script "res://tests/i18n_audit.gd"` | 把 `game.json` 里所有会显示的字符串按繁 / 英各翻一遍，凡「词典里没有」或「英文里还剩汉字」就列出来，最后打印 `--- lang=N 漏翻 M 条 ---`。**必须是 0 条才导出** |
| 运行时残留 | `& $g --path godot --script "res://tests/shot.gd" -- --auto=1 --lang=2 --cjkcheck ...` | 真跑一局，凡进入对话框的句子还带汉字的，打 `[cjk] …` |

两个都要跑：前者查数据，后者查「拼接出来的句子」——
比如结算行是 `「题」+ 选项` 拼的，整句查词典永远查不到，只能分开翻再拼。

## 校验器 `check_review.cjs` 会查什么

1. 题数 15、每次抽 6、四组各至少一题；
2. 每题三元数组齐全，正确项三语必须空白；
3. 中文选项 12–22 字，同题最长/最短 ≤ 1.5；
4. 正确项不得是唯一最长或唯一最短；
5. 英文每项 ≥ 5 词，词数比 ≤ 2.2；繁体与简体字数漂移 ≤ 3；
6. 正确项位置每档 ≥ 2；
7. `drawSet()` 真源码跑 2000 次抽样：5 题不重复、四组齐全；
8. 结构项：无前置说明段、无开放题、进度显示 `/ 6`、有换一套按钮、不显示答对数、无外链；
9. 禁用词（数值后置、通关、排名、评分…）。

不合格 `process.exit(2)`，并打印哪一条、哪一题。
