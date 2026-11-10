extends SceneTree

## 无窗口自测：--headless --script res://tests/selftest.gd
## 每条断言带 AC 编号，改逻辑先改这里。

var _pass := 0
var _fail := 0
var _ran := false

const DATA_PATH := "res://data/game.json"
const I18N_PATH := "res://data/game-i18n.json"


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_all()
	print("[selftest] pass=%d fail=%d" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
	return true


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("ok   " + label)
	else:
		_fail += 1
		print("FAIL " + label)


func _check(label: String, actual, expected) -> void:
	_ok("%s (got %s, want %s)" % [label, str(actual), str(expected)], actual == expected)


func _load() -> Dictionary:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("打不开 " + DATA_PATH)
		return {}
	var raw := f.get_as_text()
	f.close()
	return JSON.parse_string(raw)


const DAYS := 7


func _play(s: TradeoffSession, opt: int) -> void:
	for d in DAYS:
		for t in s.today:
			var tid := String(t.get("id", ""))
			var steps: Array = t.get("steps", [])
			for i in steps.size():
				var step: Dictionary = steps[i]
				var n: int = (step.get("opts", []) as Array).size()
				s.choose(tid, i, clampi(opt, 0, n - 1))
		s.settle_day()
		if d < DAYS - 1:
			s.advance_day()


func _run_all() -> void:
	var data := _load()
	_ok("AC-00 数据能读出来", not data.is_empty())

	# ---- AC-01 七日排班：前三天全普通，四到五天掺中期，六到七天全中期
	var s := TradeoffSession.new(data)
	s.new_game(2026)
	var ids: Array = []
	var kinds: Array = []
	for d in DAYS:
		var plan := s.slot_plan(s.day)
		kinds.append(plan)
		for t in s.today:
			ids.append(String(t.get("id", "")))
		if d < DAYS - 1:
			s.settle_day()
			s.advance_day()
	_ok("AC-01 七日共 14 个任务", ids.size() == 14)
	_ok("AC-01 十四个任务互不重复", _unique(ids).size() == ids.size())
	_ok("AC-01 首三日都是普通任务", kinds[0] == ["normal", "normal"] and kinds[2] == ["normal", "normal"])
	_ok("AC-01 第四五日一个普通一个中期", kinds[3] == ["normal", "long"] and kinds[4] == ["normal", "long"])
	_ok("AC-01 末两日都是中期任务", kinds[5] == ["long", "long"] and kinds[6] == ["long", "long"])

	# ---- AC-02 起值 + 每笔之和 = 止值（按 clamp 语义）
	var s2 := TradeoffSession.new(data)
	s2.new_game(2026)
	var start_v: Dictionary = s2.v.duplicate()
	_play(s2, 0)
	var sum := {"p": 0, "s": 0, "c": 0, "m": 0}
	for b in s2.book:
		for r in b.get("rows", []):
			var d: Dictionary = r.get("d", {})
			for k in sum.keys():
				sum[k] += int(d.get(k, 0))
	var ok2 := true
	for k in sum.keys():
		var want := clampi(int(start_v[k]) + int(sum[k]), 0, 100)
		if int(s2.v[k]) != want:
			ok2 = false
			print("   偏差 %s：止值 %d，起值+Σ %d" % [k, int(s2.v[k]), want])
	_ok("AC-02 起值 + Σ 每笔 = 止值", ok2)

	# ---- AC-03 崩盘最多 2 次（把接受度压到最低的选项连打）
	var s3 := TradeoffSession.new(data)
	s3.new_game(7)
	for d in DAYS:
		for t in s3.today:
			var tid := String(t.get("id", ""))
			var steps: Array = t.get("steps", [])
			for i in steps.size():
				var opts: Array = steps[i].get("opts", [])
				var worst := 0
				var worst_c := 999
				for k in opts.size():
					var fx: Dictionary = opts[k].get("fx", {})
					var cr: Array = fx.get("c", [0, 0])
					var mid := (int(cr[0]) + int(cr[1])) / 2
					if mid < worst_c:
						worst_c = mid
						worst = k
				s3.choose(tid, i, worst)
		s3.settle_day()
		if d < 2:
			s3.advance_day()
	_ok("AC-03 崩盘次数 ≤ 上限", s3.burnouts <= int(data["cfg"].get("burnMax", 2)))

	# ---- AC-05 DIY 不计入读数
	var s4 := TradeoffSession.new(data)
	s4.new_game(2026)
	var t0: Dictionary = s4.today[0]
	var tid0 := String(t0.get("id", ""))
	s4.choose_diy(tid0, 0, "把剩菜做成炒饭")
	var rec := s4.settle_day()
	var diy_zero := true
	for r in rec.get("rows", []):
		if String(r.get("kind", "")) == "diy":
			var d: Dictionary = r.get("d", {})
			for k in ["p", "s", "c", "m"]:
				if int(d.get(k, 0)) != 0:
					diy_zero = false
	_ok("AC-05 自定做法四项读数全为 0", diy_zero)

	# ---- AC-06 同种子同结果
	var a := TradeoffSession.new(data)
	a.new_game(4242)
	var b := TradeoffSession.new(data)
	b.new_game(4242)
	_play(a, 1)
	_play(b, 1)
	var same := a.v == b.v
	for i in mini(a.book.size(), b.book.size()):
		var ra: Array = a.book[i].get("rows", [])
		var rb: Array = b.book[i].get("rows", [])
		if ra.size() != rb.size():
			same = false
			break
		for j in ra.size():
			if (ra[j].get("d", {}) as Dictionary) != (rb[j].get("d", {}) as Dictionary):
				same = false
	_ok("AC-06 同种子逐笔一致", same)

	# ---- AC-07 词典三语齐全
	var box := I18nBox.load_from(I18N_PATH)
	_ok("AC-07 词典条数 ≥ 400", box.size() >= 400)
	var probe := "环境负荷"
	box.set_lang(0)
	var zh := box.t(probe)
	box.set_lang(1)
	var tw := box.t(probe)
	box.set_lang(2)
	var en := box.t(probe)
	_ok("AC-07 同一词条三语不同", zh != tw and zh != en and en != "")

	# ---- AC-08 未接的任务记接受度 −5
	var s5 := TradeoffSession.new(data)
	s5.new_game(99)
	var rec5 := s5.settle_day()
	var skip_found := false
	for r in rec5.get("rows", []):
		if String(r.get("kind", "")) == "skip":
			skip_found = true
			_check("AC-08 跳过任务的 c 变化", int((r.get("d", {}) as Dictionary).get("c", 0)), -5)
	_ok("AC-08 未接的任务产生 skip 记录", skip_found)


func _unique(arr: Array) -> Array:
	var seen := {}
	for x in arr:
		seen[x] = true
	return seen.keys()
