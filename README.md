# 一周菜篮 · One-Week Basket

一台情景驱动的家政课堂模拟器：**NPC 派任务 → 连续几步不带数字的选择 → 结算日才结账并逐笔解释**。
七天、每天两件事；另有配套的三分钟轻考核与一个可选的现场答题小后端。

> 详细文档在 [`docs/`](docs/README.md)。这份 README 只回答「是什么、怎么跑、东西在哪」。

## 不想装任何东西？

到 [Releases](https://github.com/Ja-Treffer/Food-basket-in-a-week/releases/latest) 下：

| 文件 | 用法 |
|---|---|
| `One-Week-Basket.exe` | Windows 单文件，双击即玩（约 46 MB，pck 已内嵌） |
| `one-week-basket-web.zip` | 解压丢到任意静态站，**必须走 http(s)**，双击 `index.html` 打不开 |

构建产物不进仓库（`.gitignore` 里挡着 `godot/build/`），要自己出新版见 [`docs/04-build.md`](docs/04-build.md)。

## 怎么跑

| 想做什么 | 命令 |
|---|---|
| 玩模拟器 | 双击 `game.html`，或 `game.html?seed=2026&lang=tw` |
| 做轻考核 | 双击 `review.html`，3 分钟 6 题 |
| 全班同一套题 | `review.html?seed=2026` |
| 现场答题 | `node live/server.mjs 8788` → 主持 `http://localhost:8788/`，学生 `http://<内网IP>:8788/play` |
| Godot 像素版 | 用 Godot 4.7.2 打开 `godot/` |
| 改完模板重新生成 | `node tools/patch_game_i18n.cjs && node tools/sync_godot_data.cjs` |
| 改完题库自检 | `node tools/check_review.cjs` |

`game.html` 与 `review.html` 零依赖、零联网，`file://` 下功能完整（含 `?lang=`）。只有 `live/` 需要 Node 起服务。

## 目录

```
tradeoff-sim/
├─ game.html                 模拟器（生成物，双击即开）
├─ review.html               轻考核（单文件，可打印）
├─ src/game.template.html    模拟器源码模板（手改这一份）
├─ data/                     三语词典 + 题库导出
├─ tools/                    生成与校验脚本（node，零依赖）
├─ live/                     现场答题：server.mjs / host.html / play.html
├─ godot/                    像素版（视觉小说式，Godot 4.7.2）
├─ docs/                     架构 / 数据 / 构建 / 三语 / 决策 / 术语
└─ .tmp/                     垃圾箱（已 gitignore）
```

## 用语与前提

- 界面与说明统一使用规范书面中文，不用粤语口语。保留香港专有名词（港铁、街市、渔护署、卫生防护中心、八号风球、冰鲜、当季）。
- 文献引句保留繁体原文，不改写。
- **香港几乎没有本地农牧业**：题目里一律按外来食材处理 —— 广东的冰鲜白羽鸡、邻近产区当季菜、进口冷冻牛肉。比的是运距、冷藏与当季，不是「本地」。

## 刻意没有的东西

无口号、无立场表态题、无身份议题、无组织宣传、无外链跳转、无二维码、无追踪、无网络请求、无徽章 / 等级 / 连击 / 分享、无道德评分、无胜利结算。

选项阶段没有推荐、没有禁用、没有对错、没有数值预告。

## 已知边界

1. `H4` 各品项具体排放数值未读到 → 不写 kg 数，白肉 / 红肉只给方向。
2. `F1` 布料生命周期缺一手数据 → 相关选项给方向并放宽区间。
3. `R7` / `R8` / `R9` 只作方向判断，未冒充已核数值。
4. 「可用钱」是相对刻度，未接真实票价与街市价；做校本版应换成当地实测价差。
5. 营养条把蛋白质 / B12 / 铁 / 钙压成一格，是教学简化。
6. 七天的长度是为课堂压缩的，不代表行为改变的真实周期。

## 文档导航

- 第一次来 → [docs/01-overview.md](docs/01-overview.md)
- 找代码在哪 → [docs/02-architecture.md](docs/02-architecture.md)
- 改任务 / 改题目 → [docs/03-data-model.md](docs/03-data-model.md)
- 改完要重新生成 → [docs/04-build.md](docs/04-build.md)
- 加一句中文 → [docs/05-i18n.md](docs/05-i18n.md)
- 想推翻某个设计 → [docs/06-decisions.md](docs/06-decisions.md)
- 看到不认识的词 → [docs/07-glossary.md](docs/07-glossary.md)
- 查依据 → [docs/08-sources.md](docs/08-sources.md)
- 结算怎么算的 → [docs/09-mechanics.md](docs/09-mechanics.md)
