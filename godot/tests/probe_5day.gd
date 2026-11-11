## 五天版冒烟：把 cfg.days 改成 5，从头玩到收尾，确认不卡中途、账本长度对得上。
##   & $GODOT --headless --path godot --script res://tests/probe_5day.gd
extends SceneTree


func _init() -> void:
	var raw := FileAccess.get_file_as_string("res://data/game.json")
	var data: Dictionary = JSON.parse_string(raw)
	var cfg: Dictionary = data.get("cfg", {})
	cfg["days"] = 5
	var s := TradeoffSession.new({
		"cfg": cfg,
		"tasks": data.get("tasks", []),
		"long": data.get("long", []),
		"events": data.get("events", []),
		"refs": data.get("refs", {}),
	})
	s.new_game(2026)

	var guard := 0
	while not s.is_last_day() and guard < 12:
		guard += 1
		_play_day(s)
		if not s.advance_day():
			break
	# 最后一天单独跑：advance_day 在末日返回 false，但这一天的账还没结。
	_play_day(s)

	print("[5day] day=%d book=%d last=%s sum=%s" % [
		s.day, s.book.size(), str(s.is_last_day()), str(s.summary())
	])
	var ok: bool = s.day == 5 and s.book.size() == 5 and s.is_last_day()
	print("[5day] pass" if ok else "[5day] FAIL")
	quit(0 if ok else 1)


func _play_day(s) -> void:
	for t in s.today.duplicate():
		var steps: int = int(t.get("steps", []).size())
		for i in steps:
			s.choose(String(t.get("id", "")), i, i % 3)
	s.settle_day()
