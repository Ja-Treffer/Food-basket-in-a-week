# 一周菜篮 · 待办与交接

项目：`E:\godot_workplace\E-tech\tradeoff-sim`（只动本目录）
更新：2026-11-10 21:3x

---

## 1. 现状

| 产物 | 状态 |
|---|---|
| `game.html` | 七日、14 任务、三语、依据卡片、四卡分色、5 分钟课堂时钟 —— 已实测 |
| `review.html` | 15 题抽 6、3 分钟计时、三语 —— `check_review.cjs` exit 0 |
| `live/` | 主持端 / 学生端 / SSE 后端 —— 端到端测试通过，三语已接 |
| `godot/` | 视觉小说式像素版，15 条断言全绿，三语已接 |
| `docs/` | 9 份文档（架构 / 数据 / 构建 / 三语 / 决策 / 术语 / 依据 / 机制） |

## 2. 待办

### 2.1 Godot 收尾

1. ~~导出 Windows exe~~ **已完成**：`godot/build/win/One-Week-Basket.exe`（45.8 MB，pck 内嵌）。
2. ~~导出 Web~~ **已完成**：`godot/build/web/`，另压了 `one-week-basket-web.zip`（9.9 MB）。部署必须走 http 服务。
3. ~~I18N 漏翻~~ **已修**：结算行是「题 + 选项」拼出来的，整句查不到词典；改成分开翻再拼。守门测试见 `tests/i18n_audit.gd` 与 `shot.gd --cjkcheck`，当前都是 0 条。
4. **DIY 真输入框**：现在 `_ask_text()` 直接返回「（自己写的做法）」，是个占位；要接 `LineEdit` 并落进 `choose_diy()`。
5. **美术素材后补**：目前全是 `draw_rect` 程序化图元；换真素材只改 `stage.gd` 的绘制函数。
6. **繁体残留检查**：`i18n_audit` 只查「词典有没有这条」，查不出「繁体里混了简体字」；要另写一个字表比对。

### 2.2 前端

1. `review.html` 的 PDF 没有语言标记。
2. `game.html` 175 KB（词典内联），若嫌大可以把词典拆出来按需加载 —— 但这会破坏「单文件离线」。

### 2.3 依据待核（答辩前必须补）

| 编号 | 缺什么 | 影响 |
|---|---|---|
| `H4` | Poore & Nemecek 各食品具体 kgCO₂eq/kg | 白肉 / 红肉 / 豆腐只给方向，不给数 |
| `F1` | 布料生命周期无一手数据 | 制衣任务的区间只能放宽 |
| `E1` | 教育局课程范畴名称待查 `TL_CAGuide_c_2015.pdf` | 课程衔接只能写到课程名 |
| `R7` / `R8` / `R9` | 回弹、Wynes & Nicholas、碳足迹批评 | 回弹系数与倡导概率是设计参数，不是文献结论 |

明细见 `docs/08-sources.md`。

### 2.4 课堂实测

- 七日是否真的够 10 分钟：14 个任务里普通任务 3 步、中期任务 1 步，实测一次再定。
- 如果超时，先降 `CFG.days`，不要砍步数（步数一少就退回「点卡片」）。

## 3. 怎么改

| 想改什么 | 改哪 | 之后跑什么 |
|---|---|---|
| 题目 / 任务 / 情景 | `src/game.template.html` | `node tools/patch_game_i18n.cjs && node tools/sync_godot_data.cjs` |
| 三语文案 | `data/game-i18n.json` | `node tools/patch_game_i18n.cjs`（幂等） |
| 考核题目 | `review.html` 里的 `var Q` | `node tools/check_review.cjs` |
| Godot 逻辑 | `godot/scripts/core/session.gd` | `--headless --script res://tests/selftest.gd` |
| Godot 画面 | `godot/scripts/ui/stage.gd` | `res://tests/shot.gd -- --out=... --frames=300` |

**别手改**：`game.html`、`godot/data/game.json`、`godot/data/game-i18n.json` 都是生成物。
