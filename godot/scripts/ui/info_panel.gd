extends Control
class_name InfoPanel

## 规则 / 参考资料 / 关于 —— 一个能滚的纸面板。
##
## View 只负责排版与关闭；写什么内容全由 Presenter 拼好传进来。

signal closed

const PANEL := Vector2(1000, 620)

var _font: SystemFont
var _title: Label
var _body: RichTextLabel
var _panel: Panel
var _close: Button


func setup(font: SystemFont) -> void:
	_font = font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.05, 0.06, 0.60)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.99)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.16, 0.15, 0.13, 0.45)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size = PANEL
	_panel.position = Vector2((1280 - PANEL.x) * 0.5, (720 - PANEL.y) * 0.5)
	add_child(_panel)

	_title = Label.new()
	_title.add_theme_font_override("font", _font)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Palette.INK)
	_title.position = Vector2(40, 28)
	_title.size = Vector2(PANEL.x - 80, 34)
	_panel.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.add_theme_font_override("normal_font", _font)
	_body.add_theme_font_override("bold_font", _font)
	_body.add_theme_font_size_override("normal_font_size", 18)
	_body.add_theme_font_size_override("bold_font_size", 18)
	_body.add_theme_color_override("default_color", Palette.INK)
	_body.position = Vector2(40, 74)
	_body.size = Vector2(PANEL.x - 80, PANEL.y - 154)
	_panel.add_child(_body)

	var close := Button.new()
	_close = close
	close.text = "关闭"
	close.add_theme_font_override("font", _font)
	close.add_theme_font_size_override("font_size", 20)
	close.custom_minimum_size = Vector2(180, 46)
	close.size = Vector2(180, 46)
	close.position = Vector2((PANEL.x - 180) * 0.5, PANEL.y - 66)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.93, 0.88, 0.74, 1.0)
	normal.set_corner_radius_all(8)
	close.add_theme_stylebox_override("normal", normal)
	close.add_theme_stylebox_override("hover", normal)
	close.add_theme_stylebox_override("pressed", normal)
	close.add_theme_color_override("font_color", Palette.INK)
	close.pressed.connect(_shut)
	_panel.add_child(close)


## title 与 body（BBCode）都由 Presenter 拼好。
func open(title: String, body: String, close_text: String = "关闭") -> void:
	_title.text = title
	_body.text = body
	_body.scroll_to_line(0)
	_close.text = close_text
	move_to_front()
	show()


func _shut() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_shut()
