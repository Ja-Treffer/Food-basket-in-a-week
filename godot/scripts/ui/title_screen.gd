extends Control
class_name TitleScreen

## 标题页：压一块深色板，避免白字直接落在米色墙上。
##
## 只负责「摆出来」和「把玩家的意图喊出去」：
##   start_pressed        开始这一周
##   link_pressed(kind)   怎么玩 / 参考资料 / 关于
##   lang_picked(idx)     0 简 / 1 繁 / 2 英
##
## 文案不写死在这里 —— 由 Presenter 通过 apply_texts() 灌进来，
## 所以切语言不用重建整页，只要再灌一次。

signal start_pressed
signal link_pressed(kind: String)
signal lang_picked(idx: int)

const PLATE := Vector2(620, 404)
const LANGS := ["简体", "繁體", "EN"]

var _font: Font
var _title: Label
var _sub: Label
var _start: Button
var _links: Dictionary = {}
var _lang_btns: Array = []
var _lang: int = 0


func setup(font: Font, texts: Dictionary, lang: int) -> void:
	_font = font
	_lang = lang
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.09, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var plate := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.11, 0.94)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.75, 0.70, 0.58, 0.35)
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 36
	sb.content_margin_bottom = 30
	plate.add_theme_stylebox_override("panel", sb)
	plate.size = PLATE
	plate.position = Vector2((1280 - PLATE.x) * 0.5, (720 - PLATE.y) * 0.5 - 12)
	add_child(plate)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.position = Vector2(56, 36)
	box.custom_minimum_size = Vector2(508, 0)
	plate.add_child(box)

	_title = _label("", 60, Color("#f6f2e6"))
	_sub = _label("", 20, Color(0.86, 0.84, 0.78, 1.0))
	box.add_child(_title)
	box.add_child(_sub)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 14)
	box.add_child(pad)

	_start = _button("")
	_start.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(_start)

	# 三条小链接：怎么玩 / 参考资料 / 关于。字号小、样式弱，不抢「开始」。
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 10)
	box.add_child(links)
	for kind in ["rules", "refs", "about"]:
		var b := _link("", kind)
		_links[kind] = b
		links.add_child(b)

	# 语言：放在标题页最显眼的位置，先选语言再开始。
	var langrow := HBoxContainer.new()
	langrow.alignment = BoxContainer.ALIGNMENT_CENTER
	langrow.add_theme_constant_override("separation", 6)
	box.add_child(langrow)
	for i in LANGS.size():
		var b := _lang_button(LANGS[i], i)
		_lang_btns.append(b)
		langrow.add_child(b)

	apply_texts(texts)
	_paint_lang()


## 切语言时只重灌文字，不重建节点。
func apply_texts(t: Dictionary) -> void:
	_title.text = String(t.get("title", ""))
	_sub.text = String(t.get("sub", ""))
	_start.text = String(t.get("start", ""))
	var links: Dictionary = t.get("links", {})
	for kind in _links.keys():
		(_links[kind] as Button).text = String(links.get(kind, kind))


func set_lang(idx: int) -> void:
	_lang = idx
	_paint_lang()


func _paint_lang() -> void:
	for i in _lang_btns.size():
		var b := _lang_btns[i] as Button
		var on := i == _lang
		b.add_theme_color_override(
			"font_color",
			Color(1.0, 0.95, 0.82, 1.0) if on else Color(0.62, 0.60, 0.55, 1.0)
		)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(260, 54)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.93, 0.88, 0.74, 1.0)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12

	var lit := normal.duplicate() as StyleBoxFlat
	lit.bg_color = Color(1.0, 0.95, 0.82, 1.0)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", lit)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, Palette.INK)
	return b


func _link(text: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 15)
	b.flat = true
	b.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 1.0))
	b.pressed.connect(func() -> void: link_pressed.emit(kind))
	return b


func _lang_button(text: String, idx: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(56, 26)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 1.0))
	b.pressed.connect(func() -> void: lang_picked.emit(idx))
	return b
