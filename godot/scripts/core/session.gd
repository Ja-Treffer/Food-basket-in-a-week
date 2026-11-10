extends RefCounted
class_name TradeoffSession

## 纯逻辑层：不碰任何节点。整局状态、抽值、结算都在这里。
## 七日：第 1–3 日每日 2 个普通任务；第 4–5 日 1 普通 + 1 中期；
## 第 6–7 日 2 个中期。中期任务当天只花成本，两三天后才回报。

const AXES := ["p", "s", "c", "m"]

var cfg: Dictionary = {}
var tasks: Array = []
var long_tasks: Array = []
var events: Array = []
var refs: Dictionary = {}
var rng := RandomNumberGenerator.new()

var day: int = 1
var v: Dictionary = {}
var deck: Array = []
var long_deck: Array = []
var today: Array = []
var today_event: Dictionary = {}
var done: Dictionary = {}
var pending: Array = []
var book: Array = []
var burnouts: int = 0
var pick_count: int = 0


func _init(data: Dictionary) -> void:
	cfg = data.get("cfg", {})
	tasks = data.get("tasks", [])
	long_tasks = data.get("long", [])
	events = data.get("events", [])
	refs = data.get("refs", {})


# ---------------------------------------------------------------- 开局

func new_game(seed_value: int) -> void:
	rng.seed = seed_value
	var st: Dictionary = cfg.get("start", {})
	v = {
		"p": int(st.get("p", 68)),
		"s": int(st.get("s", 58)),
		"c": int(st.get("c", 62)),
		"m": int(st.get("m", 55)),
	}
	day = 1
	book = []
	pending = []
	burnouts = 0
	pick_count = 0
	deck = _shuffled(tasks.duplicate())
	long_deck = long_tasks.duplicate()
	start_day()


## 当天的排班表：普通任务与中期任务各取几个
func slot_plan(for_day: int) -> Array:
	if for_day <= 3:
		return ["normal", "normal"]
	if for_day <= 5:
		return ["normal", "long"]
	return ["long", "long"]


func start_day() -> void:
	done = {}
	today = []
	for kind in slot_plan(day):
		if kind == "normal":
			if deck.is_empty():
				deck = _shuffled(tasks.duplicate())
			if not deck.is_empty():
				today.append(deck.pop_back())
		else:
			if long_deck.is_empty():
				long_deck = long_tasks.duplicate()
			if not long_deck.is_empty():
				today.append(long_deck.pop_front())
	# 情景：从没出现过的里抽一张
	var ev_pool: Array = []
	for e in events:
		var seen := false
		for b in book:
			if String(b.get("event", "")) == String(e.get("text", "")):
				seen = true
		if not seen:
			ev_pool.append(e)
	if ev_pool.is_empty():
		ev_pool = events.duplicate()
	_shuffle(ev_pool)
	today_event = ev_pool[0] if not ev_pool.is_empty() else {}


func task_by_id(tid: String) -> Dictionary:
	for t in today:
		if String(t.get("id", "")) == tid:
			return t
	return {}


func picks_of(tid: String) -> Array:
	return done.get(tid, [])


func is_task_done(tid: String) -> bool:
	var t := task_by_id(tid)
	var n: int = (t.get("steps", []) as Array).size()
	return (done.get(tid, []) as Array).size() >= n


func done_count() -> int:
	var n := 0
	for t in today:
		if is_task_done(String(t.get("id", ""))):
			n += 1
	return n


func all_done() -> bool:
	for t in today:
		if not is_task_done(String(t.get("id", ""))):
			return false
	return true


func is_long_task(t: Dictionary) -> bool:
	for x in long_tasks:
		if String(x.get("id", "")) == String(t.get("id", "")):
			return true
	return false


# ---------------------------------------------------------------- 选择

func choose(tid: String, step_idx: int, opt_idx: int) -> Dictionary:
	var t := task_by_id(tid)
	if t.is_empty():
		return {}
	var steps: Array = t.get("steps", [])
	if step_idx < 0 or step_idx >= steps.size():
		return {}
	var step: Dictionary = steps[step_idx]
	var opts: Array = step.get("opts", [])
	if opt_idx < 0 or opt_idx >= opts.size():
		return {}
	var opt: Dictionary = opts[opt_idx]
	var rec := {
		"step": String(step.get("q", "")),
		"text": String(opt.get("text", opt.get("t", ""))),
		"fx": opt.get("fx", {}),
		"ref": opt.get("ref", []),
		"why": opt.get("why", ""),
		"diy": bool(opt.get("diy", false)),
		"delay": opt.get("delay", null),
		"adv": bool(opt.get("adv", false)),
		"task": tid,
	}
	var arr: Array = done.get(tid, [])
	arr.append(rec)
	done[tid] = arr
	pick_count += 1
	return rec


func choose_diy(tid: String, step_idx: int, text: String) -> Dictionary:
	var t := task_by_id(tid)
	if t.is_empty():
		return {}
	var steps: Array = t.get("steps", [])
	if step_idx < 0 or step_idx >= steps.size():
		return {}
	var step: Dictionary = steps[step_idx]
	var rec := {
		"step": String(step.get("q", "")),
		"text": text,
		"fx": {},
		"ref": ["D7"],
		"why": "",
		"diy": true,
		"delay": null,
		"adv": false,
		"task": tid,
	}
	var arr: Array = done.get(tid, [])
	arr.append(rec)
	done[tid] = arr
	pick_count += 1
	return rec


# ---------------------------------------------------------------- 结算

func settle_day() -> Dictionary:
	var before := v.duplicate()
	var rows: Array = []

	# 1. 今日情景
	if not today_event.is_empty():
		var fx: Dictionary = today_event.get("fx", {})
		var d := _draw(fx)
		rows.append({
			"kind": "event",
			"label": String(today_event.get("text", "")),
			"npc": String(today_event.get("npc", "")),
			"d": d, "range": fx,
			"ref": today_event.get("ref", []),
			"why": String(today_event.get("why", "")),
		})

	# 2. 每个任务逐笔
	for t in today:
		var tid := String(t.get("id", ""))
		var picks: Array = done.get(tid, [])
		if picks.is_empty():
			var d0 := {"p": 0, "s": 0, "c": -5, "m": 0}
			rows.append({
				"kind": "skip",
				"label": String(t.get("theme", "")),
				"d": d0, "range": null, "ref": ["D3"], "why": "",
			})
			continue
		for pk in picks:
			if bool(pk.get("diy", false)):
				rows.append({
					"kind": "diy", "label": String(pk.get("text", "")),
					"d": {"p": 0, "s": 0, "c": 0, "m": 0}, "range": null,
					"ref": ["D7"], "why": "",
				})
				continue
			var fx2: Dictionary = pk.get("fx", {})
			var d2 := _draw(fx2)
			rows.append({
				"kind": "pick",
				"label": "「%s」%s" % [String(pk.get("step", "")), String(pk.get("text", ""))],
				"step": String(pk.get("step", "")),
				"text": String(pk.get("text", "")),
				"d": d2, "range": fx2,
				"ref": pk.get("ref", []), "why": String(pk.get("why", "")),
			})
			if pk.get("delay", null) != null:
				var dl: Dictionary = pk["delay"]
				var at := int(cfg.get("days", 7))
				if dl.has("after"):
					at = day + int(dl["after"])
				elif dl.has("day"):
					at = int(dl["day"])
				pending.append({
					"day": mini(int(cfg.get("days", 7)), at),
					"kind": "delay",
					"label": String(dl.get("label", "")),
					"fx": dl.get("fx", {}),
					"ref": dl.get("ref", []),
					"why": String(dl.get("why", "")),
				})
			if bool(pk.get("adv", false)):
				pending.append({"day": int(cfg.get("days", 7)), "kind": "adv", "label": ""})

	# 3. 延迟后果
	var keep: Array = []
	for q in pending:
		if int(q.get("day", 0)) == day and String(q.get("kind", "")) == "delay":
			var fx3: Dictionary = q.get("fx", {})
			rows.append({
				"kind": "delay",
				"label": String(q.get("label", "")),
				"d": _draw(fx3), "range": fx3,
				"ref": q.get("ref", []), "why": String(q.get("why", "")),
			})
		else:
			keep.append(q)
	pending = keep

	# 4. 接受度崩盘
	var burn_below := int(cfg.get("burnBelow", 25))
	var burn_max := int(cfg.get("burnMax", 2))
	if int(v["c"]) < burn_below and burnouts < burn_max and not rows.is_empty():
		var give := 0
		var tail: Array = rows.slice(maxi(0, rows.size() - 3))
		for r in tail:
			var dp := int((r.get("d", {}) as Dictionary).get("p", 0))
			if dp < 0:
				give += absi(dp)
		var back := int(round(float(give) * float(cfg.get("burnGiveback", 0.55))))
		var c_gain := int(cfg.get("burnRecover", 32)) - int(v["c"])
		rows.append({
			"kind": "burn",
			"label": "",
			"d": {"p": back, "s": 0, "c": c_gain, "m": 0},
			"range": null, "ref": ["D3", "H1"], "why": "",
			"back": back,
		})
		burnouts += 1

	# 5. 末日：倡导 + 回弹
	if day == int(cfg.get("days", 7)):
		for q in pending:
			if String(q.get("kind", "")) != "adv":
				continue
			var adv: Dictionary = cfg.get("advocacy", {})
			var chance := float(adv.get("base", 0.35))
			if int(v["c"]) >= int(adv.get("highAt", 60)):
				chance += float(adv.get("high", 0.15))
			if int(v["c"]) < int(adv.get("lowAt", 25)):
				chance += float(adv.get("low", -0.15))
			if rng.randf() < chance:
				var win: Array = adv.get("win", [8, 14])
				var cut := rng.randi_range(int(win[0]), int(win[1]))
				rows.append({
					"kind": "adv_ok", "label": "",
					"d": {"p": -cut, "s": 0, "c": 0, "m": 0},
					"range": null, "ref": ["D5", "R9"], "why": "", "cut": cut,
				})
			else:
				rows.append({
					"kind": "adv_no", "label": "",
					"d": {"p": 0, "s": 0, "c": 0, "m": 0},
					"range": null, "ref": ["D5", "R9"], "why": "",
				})
		pending = []

	# 6. 汇总
	var total := {"p": 0, "s": 0, "c": 0, "m": 0}
	for r in rows:
		var d: Dictionary = r.get("d", {})
		for k in AXES:
			total[k] += int(d.get(k, 0))
	for k in AXES:
		v[k] = clampi(int(v[k]) + int(total[k]), 0, 100)

	var day_rec := {
		"day": day,
		"event": String(today_event.get("text", "")),
		"rows": rows,
		"before": before,
		"after": v.duplicate(),
		"total": total,
	}
	book.append(day_rec)
	return day_rec


func advance_day() -> bool:
	if day >= int(cfg.get("days", 7)):
		return false
	day += 1
	start_day()
	return true


func is_last_day() -> bool:
	return day >= int(cfg.get("days", 7))


func all_rows() -> Array:
	var out: Array = []
	for b in book:
		out.append_array(b.get("rows", []))
	return out


func summary() -> Dictionary:
	return {"v": v.duplicate(), "burnouts": burnouts, "days": book.size(), "picks": pick_count}


# ---------------------------------------------------------------- 内部

func _draw(fx: Dictionary) -> Dictionary:
	var out := {"p": 0, "s": 0, "c": 0, "m": 0}
	for k in AXES:
		if not fx.has(k):
			continue
		var r: Array = fx[k]
		if r.size() < 2:
			continue
		var lo := int(minf(float(r[0]), float(r[1])))
		var hi := int(maxf(float(r[0]), float(r[1])))
		out[k] = rng.randi_range(lo, hi)
	return out


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _shuffled(arr: Array) -> Array:
	var out := arr.duplicate()
	_shuffle(out)
	return out
