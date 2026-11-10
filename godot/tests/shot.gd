extends SceneTree

## 截图工具：跑 N 帧后把窗口画面存成 PNG。
## 用法：& $GODOT --path <工程> --script res://tests/shot.gd -- --out=abs.png --frames=240 --auto=1 --lang=0
## --auto=1 会自动开标题、并每 22 帧点一次对话，便于截到中段画面。

var _frames := 0
var _out := "user://shot.png"
var _limit := 20
var _auto := false
var _lang := "0"
var _dump := false
var _every := 26
var _open := ""
var _switchlang := -1
var _stopask := false
var _booted := false
var _scene = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--frames="):
			_limit = int(a.substr(9))
		elif a.begins_with("--auto="):
			_auto = a.substr(7) == "1"
		elif a.begins_with("--lang="):
			_lang = a.substr(7)
		elif a.begins_with("--switchlang="):
			_switchlang = int(a.substr(13))
		elif a.begins_with("--open="):
			_open = a.substr(7)
		elif a.begins_with("--every="):
			_every = int(a.substr(8))
		elif a.begins_with("--stopask="):
			_stopask = a.substr(10) == "1"
		elif a.begins_with("--dump="):
			_dump = a.substr(7) == "1"


func _dump_tree(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if n is CanvasItem:
		extra += " visible=%s" % str(n.visible)
	if n is ColorRect:
		extra += " color=%s" % str(n.color)
	if n is Panel:
		var sb = n.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			extra += " bg=%s" % str(sb.bg_color)
	print(pad + n.name + " <" + n.get_class() + ">" + extra)
	for c in n.get_children():
		_dump_tree(c, depth + 1)


func _process(_delta: float) -> bool:
	if not _booted:
		_booted = true
		_scene = load("res://main.tscn")
		if _scene != null:
			var inst = _scene.instantiate()
			get_root().add_child(inst)
	_frames += 1

	if _switchlang >= 0 and _frames == 45:
		for n in get_root().find_children("*", "Node", true, false):
			if n is Presenter:
				n.set_lang(_switchlang)
				break
	if _open != "" and _frames == 40:
		for n in get_root().find_children("*", "Node", true, false):
			if n is Presenter:
				n.show_info(_open)
				break
	if _auto and _frames == 3:
		# 不去猜标题页按钮的坐标：直接让标题页喊一声「开始了」。
		var started := false
		for n in get_root().find_children("*", "Control", true, false):
			if n is TitleScreen:
				n.start_pressed.emit()
				started = true
				break
		if not started:
			_click({"x": 640, "y": 330})
	if _auto and _frames > 30 and _frames % _every == 0:
		var asking := false
		for n in get_root().find_children("*", "Control", true, false):
			if n is DialogueBox and int(n.get("_opt_count")) > 0:
				asking = true
				break
		if asking:
			# 停在选项上便于截图；不想要就按 1 选第一条继续往下跑。
			if not _stopask:
				_key(KEY_1)
		else:
			_click({"x": 640, "y": 520})

	if _frames < _limit:
		return false
	var img := get_root().get_texture().get_image()
	if _dump:
		_dump_tree(get_root(), 0)
	if img != null:
		var err := img.save_png(_out)
		print("[shot] saved=%s err=%d size=%s" % [_out, err, str(img.get_size())])
	else:
		print("[shot] no image")
	quit(0)
	return true


func _key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _click(pos: Dictionary) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(pos["x"], pos["y"])
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = ev.position
	up.global_position = ev.position
	Input.parse_input_event(up)
