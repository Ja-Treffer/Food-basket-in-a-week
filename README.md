# One-Week Basket · 一周菜篮

**A seven-day scenario simulator for Hong Kong home-economics / technology-and-living classes.**
An NPC hands you a task → you make a few choices that show no numbers → the day settles, and every line tells you where the cost landed.

Seven days, two things a day. Ships with a three-minute quick check, an optional live-quiz backend, and a pixel-art Godot build.

[中文说明](README_CH.md)

![Title screen](docs/images/title.png)

---

## Download

Grab both files from [**Releases**](https://github.com/Ja-Treffer/Food-basket-in-a-week/releases/latest):

| File | Use | Size |
|---|---|---|
| `One-Week-Basket.exe` | Windows, single file, double-click to play (pck embedded) | 46.4 MB |
| `one-week-basket-web.zip` | Unzip onto any static host; **must be served over http(s)** — opening `index.html` from disk will not work | 10.5 MB |

No build artifacts live in this repository: `dist/` and `godot/build/` are both in `.gitignore`, publishing goes through Releases only.

## Live, right now

| What | URL |
|---|---|
| Hub | <https://ja-treffer.github.io/Food-basket-in-a-week/> |
| Simulator | <https://ja-treffer.github.io/Food-basket-in-a-week/html_demo/> |
| Quick check | `html_review/` | 10 derivation items, 6 per run, scored |

Checksums (`sha256`):

```
One-Week-Basket.exe       4e2c464b716e195e2ab2363fce9f510a654f55f78297d8a34a2ccda3db52b6b6
one-week-basket-web.zip   3c69ceba72702365a2ebedcfb8017e5c29fcd29af381e2e437115f19b985a363
```

## Or just open it in a browser

| I want to… | Do this |
|---|---|
| Play the simulator | open `game.html` (or `game.html?seed=2026&lang=zh`) |
| Take the quick check | open `review.html` — 6 questions, 3 minutes |
| Give the whole class the same set | `review.html?seed=2026` |
| Run a live quiz | `node live/server.mjs 8788` → host at `http://localhost:8788/`, students at `http://<lan-ip>:8788/play` |

`game.html` and `review.html` are single files with zero dependencies and zero network access — they work over `file://`, including `?lang=`. Only `live/` needs a Node server.

## What it looks like

| Choosing | Settling the day |
|---|---|
| ![options inside the dialogue box](docs/images/ask.png) | ![the ledger under a desk lamp](docs/images/night.png) |

- **No numbers while you choose.** No readings, ranges, recommendations or bans.
- **No score.** Settlement opens four ledgers — environmental load, nutrition, acceptance, money — and explains every line.
- **No free lunch.** The four ledgers pull against each other; most questions have no option that wins on all four.
- **Grounded.** Every line carries a source code (H1 / R5 / F1…), and the “Info” panel shows the excerpt.

## Languages

Simplified Chinese · Traditional Chinese · English. Pick on the title screen, or switch any time from the top-right corner.
All copy lives in `data/game-i18n.json` (594 entries of `{zh,tw,en}`) and is shared by the browser build, the live quiz and the Godot build.

Default language is **English**; switch with the dropdown or `?lang=zh|tw|en` (the choice is remembered).

## Layout

```
tradeoff-sim/
├─ game.html                 simulator (generated, double-click to run)
├─ review.html               quick check (single file, printable)
├─ src/game.template.html    the real source of the simulator — edit this one
├─ data/                     trilingual dictionary + exported quiz bank
├─ tools/                    build, check and packaging scripts (node / pwsh, no deps)
├─ live/                     live quiz: server + host screen + player screen
├─ godot/                    Godot 4.7.2 pixel build (MVP layering)
├─ site/                     static site published on GitHub Pages
├─ docs/                     nine documents
└─ dist/                     build output (not tracked)
```

Commands:

```bash
node tools/patch_game_i18n.cjs    # template → game.html
node tools/sync_godot_data.cjs    # template → Godot data
node tools/check_review.cjs       # question-bank self check (3 languages, lengths, sampling)
node tools/publish_site.cjs       # game.html / review.html → site/
powershell -File tools/package.ps1  # export exe + web into dist/
```

## Docs

Start at [`docs/README.md`](docs/README.md): overview, architecture, data model, build, i18n, decision records (ADR), glossary, sources, mechanics.

## Boundaries

The four readings are a **teaching mapping**, not emission factors, nutrient values or HKD. Direction comes from the sources; the scale comes from the curriculum.
Nothing is graded, ranked, or turned into a carbon footprint. Food is written to Hong Kong reality — there is almost no local agriculture; nearly everything is imported.

## Licence

Code under [MIT](LICENSE). Quoted references (Centre for Health Protection, Agriculture, Fisheries and Conservation Department, IPCC, …) remain the property of their authors; this project only excerpts them.
