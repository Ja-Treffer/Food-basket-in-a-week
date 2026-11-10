extends Control
class_name DialogueBox

## 底部对话框：名字牌 + 打字机正文 + 内嵌选项。
## 点击/空格先把整句吐完，再点才进下一句；有选项时只有按钮能点。
## 刻意不做成卡片列表 —— 选项是「这孩子能说出口的几句话」，贴着正文出现。

signal line_done
signal option_picked(index: int)

const TYPE_SPEED := 0.022

const PAPER := Color("#fdfbf3")
const INK := Color("#23221e")
const SOFT := Color("#6f6a5e")
const LINE := Color("#c9c2b2")
const GOLD := Color("#c58a3a")
const BLUE := Color("#3d6480")

var _box: Panel
var _name: Label
var _text: Label
var _opts: VBoxContainer
var _hint: Label
var _style: StyleBoxFlat

var _reveal: float = 0.0
var _typing: bool = false
var _waiting: bool = false
var _has_opts: bool = false
var _opt_count: int = 0
var hint_text: String = "点击继续"
var _full: String = ""
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_font = Palette.font()

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.965)
	_style.border_color = Color(0.16, 0.15, 0.13, 0.55)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)
	_style.shadow_color = Color(0.08, 0.07, 0.06, 0.28)
	_style.shadow_size = 10
	_style.content_margin_left = 30
	_style.content_margin_right = 30
	_style.content_margin_top = 22
	_style.content_margin_bottom = 18

	_box = Panel.new()
	_box.add_theme_stylebox_override("panel", _style)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	_name = Label.new()
	_name.add_theme_font_override("font", _font)
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", GOLD)
	_box.add_child(_name)

	_text = Label.new()
	_text.add_theme_font_override("font", _font)
	_text.add_theme_font_size_override("font_size", 24)
	_text.add_theme_color_override("font_color", INK)
	_text.add_theme_constant_override("line_spacing", 10)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_text)

	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 8)
	_box.add_child(_opts)

	_hint = Label.new()
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", SOFT)
	_hint.text = "点击继续"
	_box.add_child(_hint)

	resized.connect(_layout)
	call_deferred("_layout")


func _layout() -> void:
	if _box == null:
		return
	var s := get_viewport_rect().size
	var bw: float = minf(1120.0, s.x - 120.0)
	var pad := 30
	var bh: float = 186.0
	if _has_opts:
		# 问句 + N 个选项：高度按选项数长出来，不然按钮会顶出面板。
		bh = 76.0 + float(_opt_count) * 58.0 + 18.0
		bh = clampf(bh, 186.0, 380.0)
	_box.size = Vector2(bw, bh)
	_box.position = Vector2((s.x - bw) * 0.5, s.y - bh - 22.0)
	_name.position = Vector2(pad, 12)
	_name.size = Vector2(bw - pad * 2, 24)
	if _has_opts:
		_text.position = Vector2(pad, 40)
		_text.size = Vector2(bw - pad * 2, 34)
		_opts.position = Vector2(pad, 80)
		_opts.size = Vector2(bw - pad * 2, bh - 92)
	else:
		_text.position = Vector2(pad, 42)
		_text.size = Vector2(bw - pad * 2, bh - 70)
	_hint.position = Vector2(bw - pad - 90, bh - 28)
	_hint.size = Vector2(90, 20)


# ---------------------------------------------------------------- 对外

func open() -> void:
	show()
	_box.show()


func close() -> void:
	hide()


## 显示一句话，等玩家点完。who 为空则是旁白。
func say(who: String, text: String) -> void:
	_has_opts = false
	_opts.hide()
	_text.show()
	_hint.show()
	_name.text = who
	_name.visible = who != ""
	_full = text
	_text.text = text
	_text.visible_characters = 0
	_reveal = 0.0
	_typing = true
	_waiting = true
	_layout()


## 问一句。只负责摆出来，不等结果 —— 玩家选了就 emit option_picked，
## 由 Presenter 接。View 不替上层做决定。
func ask(who: String, text: String, options: Array) -> void:
	_has_opts = true
	_opt_count = options.size()
	_text.show()
	_hint.hide()
	_name.text = who
	_name.visible = who != ""
	_full = text
	_text.text = text
	_text.visible_characters = -1
	_typing = false
	_reveal = float(text.length())
	_build_opts(options)
	_waiting = true
	_layout()


func _build_opts(options: Array) -> void:
	for c in _opts.get_children():
		c.queue_free()
	_opts.show()
	for i in options.size():
		var b := Button.new()
		b.text = "%s  %s" % [_letter(i), String(options[i])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", BLUE)
		b.add_theme_color_override("font_pressed_color", BLUE)
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(6)
			sb.content_margin_left = 16
			sb.content_margin_right = 12
			sb.content_margin_top = 10
			sb.content_margin_bottom = 10
			if state == "normal":
				sb.bg_color = Color(0.93, 0.91, 0.86, 0.92)
				sb.border_color = Color(LINE.r, LINE.g, LINE.b, 0.9)
				sb.set_border_width_all(1)
			elif state == "hover":
				sb.bg_color = Color(0.88, 0.90, 0.88, 1.0)
				sb.border_color = BLUE
				sb.set_border_width_all(2)
			elif state == "pressed":
				sb.bg_color = Color(0.82, 0.85, 0.84, 1.0)
				sb.border_color = BLUE
				sb.set_border_width_all(2)
			else:
				sb.bg_color = Color(0, 0, 0, 0)
				sb.draw_center = false
			b.add_theme_stylebox_override(state, sb)
		var idx := i
		b.pressed.connect(func() -> void: _pick(idx))
		_opts.add_child(b)


func _letter(i: int) -> String:
	return ["A", "B", "C", "D", "E"][i] if i < 5 else str(i + 1)


func _pick(i: int) -> void:
	if not _has_opts:
		return
	_has_opts = false
	_opt_count = 0
	_waiting = false
	_opts.hide()
	_layout()
	option_picked.emit(i)


# ---------------------------------------------------------------- 输入

func _process(delta: float) -> void:
	if _hint != null and _hint.text != hint_text:
		_hint.text = hint_text
	if not _typing:
		return
	_reveal += delta / maxf(TYPE_SPEED, 0.001)
	var n := int(_reveal)
	if n >= _full.length():
		_text.visible_characters = -1
		_typing = false
	else:
		_text.visible_characters = n


func _input(event: InputEvent) -> void:
	if not visible or not _waiting:
		return
	# 选项在的时候，数字键 1–5 直接选（要在「空格/回车」判定之前处理，
	# 否则数字键会被当成「没按」，永远落不到 _pick）。
	if _has_opts and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_5:
			_pick(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and (
			event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
		)
	if not pressed:
		return
	if _has_opts:
		# 选项在按钮上，鼠标点按钮；键盘已经在上面处理过了。
		return
	if _typing:
		_text.visible_characters = -1
		_typing = false
		_reveal = float(_full.length())
		get_viewport().set_input_as_handled()
		return
	_waiting = false
	get_viewport().set_input_as_handled()
	line_done.emit()
