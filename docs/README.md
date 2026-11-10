# 一周菜篮 · 文档索引

给人和给检索用。**一个文件只讲一件事**，跨文件只靠术语和路径互相引用，不重复叙述。

| 文件 | 回答什么 | 什么时候来查 |
|---|---|---|
| [01-overview.md](01-overview.md) | 这是什么、给谁用、一局怎么走 | 第一次接触项目 |
| [02-architecture.md](02-architecture.md) | 有哪几块、谁依赖谁、数据从哪流到哪 | 要改结构、找代码在哪 |
| [03-data-model.md](03-data-model.md) | `game.json` / `quiz.json` / `game-i18n.json` 的字段字典 | 加任务、改题目、改文案 |
| [04-build.md](04-build.md) | 每份产物怎么生成、命令是什么 | 改完要重新生成 |
| [05-i18n.md](05-i18n.md) | 三语怎么落、词典怎么维护、踩过哪些坑 | 加一句中文、切语言出问题 |
| [06-decisions.md](06-decisions.md) | 为什么是现在这个样子（ADR） | 想推翻某个设计前先读 |
| [07-glossary.md](07-glossary.md) | 术语表：四本账、七日、中期任务、依据编号 | 看到不认识的词 |

根目录只留入口：`README.md`（怎么跑）、`PLAN.md`（分几段交付、验收条件）、`TODO_LIST.md`（没做的）。

## 一句话版本

> 香港家政 / 科技与生活课堂用的**七日情景模拟器**：一天两件事，做完才结账，结账时四条读数（环境负荷、营养均衡、口味接受度、可用钱）互相拉扯，教的是「为什么这么做」而不是「哪个选项对」。

## 三份产物，共用一套数据

- `game.html`：浏览器版，单文件离线，双击即开。
- `review.html`：三分钟轻考核，15 题随机抽 6 题。
- `godot/`：Godot 4.7.2 像素版，视觉小说式，中文 UI + 320×180 像素舞台。导出见下。
- `live/`：Kahoot 式现场答题（Node 后端 + 主持端 + 学生端）。

## 已导出的两份可直接部署

| 产物 | 路径 | 怎么用 |
|---|---|---|
| Windows 单文件 | `godot/build/win/One-Week-Basket.exe` | 双击。pck 已内嵌，45.8 MB，拷到哪都能跑 |
| Web | `godot/build/web/` + `godot/build/one-week-basket-web.zip` | 整目录丢到任意静态站。**必须走 http(s)**，双击 `index.html` 打不开（wasm 要同源） |

Web 版用的是不开线程的构建（`variant/thread_support=false`），所以不需要 COOP/COEP 响应头。
