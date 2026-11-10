# 02 · 结构：有哪几块，谁依赖谁

## 目录

```
tradeoff-sim/
├─ src/game.template.html      ← 浏览器版的手改源（不是 game.html！）
├─ game.html                   ← 生成物：模板 + 内联三语词典
├─ review.html                 ← 轻考核，手改，单文件
├─ data/
│  ├─ game-i18n.json           ← 三语词典（唯一真源，567 条）
│  └─ quiz.json                ← 从 review.html 抽出，给 live/ 和 Godot 用
├─ tools/                      ← 全部生成与校验脚本（node，零依赖）
├─ live/                       ← 现场答题：server.mjs + host.html + play.html
└─ godot/                      ← 像素版
   ├─ data/game.json           ← 从 src/game.template.html 抽出（生成物）
   ├─ data/game-i18n.json      ← 上面那份词典的副本（生成物）
   ├─ scripts/core/            ← 纯逻辑，无 Node 依赖
   ├─ scripts/ui/              ← 表现层
   └─ tests/                   ← selftest.gd（断言）+ shot.gd（截图）
```

## 数据流

```
src/game.template.html ─┬─→ tools/patch_game_i18n.cjs ─→ game.html
                        │        ↑ data/game-i18n.json
                        └─→ tools/extract_game_data.cjs ─→ godot/data/game.json

review.html ──→ tools/extract_quiz.cjs ─→ data/quiz.json ─→ live/server.mjs
                                                          └→ godot/（题库未接）
```

**一条铁律**：`game.html` 是生成物，手改会被下一次 `patch` 覆盖。要改就改 `src/game.template.html`，然后重新生成。

## 浏览器版（`game.html`）内部分区

源文件 `src/game.template.html` 按 §0–§7 分段：

| 段 | 内容 |
|---|---|
| §0 | `CFG`：days=7、经济参数、时间预算 |
| §1 | `REF`：依据表（H1/R2/F1…），供结算页弹卡片 |
| §2 | `TASKS` / `LONG` / `EVENTS`：任务、中期任务、每日情景 |
| §3 | 状态机：`g`（day/pool/longPool/done/pending/book）+ `choose()` |
| §4 | `settleDay()`：抽值、迟延后果、崩盘、回弹、夹 0–100 |
| §5 | 总结算 / 逐日复盘 / 规则页 / 导出 |
| §6 | `render()`：全部 DOM 拼接 |
| §7 | 启动：读 `?seed=` `?lang=` `?demo=` `?minutes=` |

## Godot 版分层（MVP）

严格按 Model–View–Presenter 切，三边互不认识：

| 角色 | 在哪 | 认识谁 | 不认识谁 |
|---|---|---|---|
| **Model** | `scripts/core/session.gd`、`i18n.gd` | 只有数据 | 不知道有节点、有像素、有对话框 |
| **View** | `scripts/ui/stage.gd`、`hud.gd`、`dialogue.gd`、`title_screen.gd`、`modal_card.gd`、`curtain.gd` | 只认自己的子节点 | 不知道 `model.v["p"]` 是什么，不知道下一步该干嘛 |
| **Presenter** | `scripts/app/presenter.gd` | model + 一组 view 引用 | 不画一个像素，不拼一句 HTML |
| **组合根** | `scripts/ui/main.gd` | 造 model、造 view、连线 | 一条业务规则都不许写 |

```
scripts/core/            纯逻辑，RefCounted，不碰节点
├─ session.gd            TradeoffSession：一局的状态与结算（与 §3/§4 同构）
└─ i18n.gd               I18nBox：读 data/game-i18n.json，t(s) 查词

scripts/app/
└─ presenter.gd          Presenter：时间线、结算念账、换场时序

scripts/ui/              表现层，一个文件一件事
├─ palette.gd            Palette：全站配色 + 字体工厂
├─ stage.gd              320×180 像素舞台，四套布景 + 人物 + 夜色
├─ dialogue.gd           DialogueBox：名字牌 + 打字机 + 内嵌选项
├─ hud.gd                Hud：日期 / 地点 / 四条读数 / 语言下拉
├─ title_screen.gd       TitleScreen：标题板
├─ modal_card.gd         ModalCard：遮罩 + 纸卡（再来一周 / DIY 提示）
├─ info_panel.gd         InfoPanel：怎么玩 / 参考资料 / 关于，一块能滚的纸板
├─ curtain.gd            Curtain：换场黑幕，只负责「变黑/变亮」这一段动画
└─ main.gd               组合根：读数据 → 造 View → 造 Presenter → 连线

tests/
├─ selftest.gd           15 条断言，--headless 跑
└─ shot.gd               跑 N 帧截图，供无头环境验证画面
```

**三条不许越界**：

1. View 不许 `await` 业务结果再 `return`。要用户做选择，就 `emit`（`line_done` / `option_picked` / `closed`），由 Presenter 接。
2. Presenter 不许直接 `new` 一个 `Button` 或改 `Label.text` —— 它只说「摆一句什么话」，怎么摆是 View 的事。
3. Model 不许 `import` 任何 `Node`。

`main.gd` 的调用链只有一条：

```
_ready → _build_stage → _build_ui → _show_title
  └─ 按下开始 → _run_week
        loop: _day_open → for t in today: _play_task(t) → _settle
              → 末日? _summary : advance_day
```

## 为什么不用 SubViewport

Compatibility 渲染器下 `ViewportTexture` 会被当线性色再转一次，整幅压暗成 `(c/255)^2.2`（实测 `#c4bba6 → #908a7e`）。
现在把 `Node2D` 直接挂主视口、`scale = 4`、`texture_filter = NEAREST`；全部是 `draw_rect` 图元，放大 4 倍仍是整数像素。

## 现场答题（`live/`）

```
server.mjs   ← 零依赖 Node，内存房间，SSE 推状态
host.html    ← 投影端：加入码 + 题干 + 柱状分布 + 讲评
play.html    ← 学生端：A/B/C/D 大按钮 + 逐项人数 + 我的对错
```

状态机：`lobby → question → reveal → … → done`，每题 20 秒，全答完或到点自动揭示。
不做积分榜 / 连击 / 排名 —— 与「不排名不评级」的既定要求冲突，改成全班分布条。
