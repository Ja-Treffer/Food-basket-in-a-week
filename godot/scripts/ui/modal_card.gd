extends Control
class_name ModalCard

## 全屏遮罩 + 一张纸卡。两个用途：结算后的「再来一周」、DIY 的输入提示。
##
## View 只负责摆出来、在被按下时发 closed；什么时候弹、弹完做什么，归 Presenter。

signal closed

var _veil: ColorRect
var _card: Panel
var _text: Label
var _button: Button


func setup(font: SystemFont) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()

	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.05, 0.06, 0.62)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)

	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.16, 0.15, 0.13, 0.5)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 30
	sb.content_margin_bottom = 26
	_card.add_theme_stylebox_override("panel", sb)
	_veil.add_child(_card)

	_text = Label.new()
	_text.add_theme_font_override("font", font)
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", Palette.INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("line_spacing", 10)
	_card.add_child(_text)

	_button = Button.new()
	_button.add_theme_font_override("font", font)
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(_on_pressed)
	_card.add_child(_button)

	resized.connect(_layout)
	call_deferred("_layout")


func _layout() -> void:
	if _card == null:
		return
	var s := get_viewport_rect().size
	_card.size = Vector2(minf(760.0, s.x - 160.0), 300.0)
	_card.position = Vector2((s.x - _card.size.x) * 0.5, (s.y - _card.size.y) * 0.5 - 40.0)
	_text.position = Vector2(40, 34)
	_text.size = Vector2(_card.size.x - 80, 150)
	_button.size = Vector2(220, 46)
	_button.position = Vector2((_card.size.x - 220) * 0.5, _card.size.y - 70)


## 摆出来，等玩家按一下那颗按钮；按下就 emit closed。
func open(text: String, button_text: String) -> void:
	_text.text = text
	_button.text = button_text
	show()


func _on_pressed() -> void:
	hide()
	closed.emit()
