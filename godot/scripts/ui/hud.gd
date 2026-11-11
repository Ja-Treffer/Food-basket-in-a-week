extends Control
class_name Hud

## 顶部状态条：日期 / 地点 / 四本账 / 语言下拉。
## 只管显示，不碰游戏状态 —— 数字由导演台喂进来。

signal lang_changed(idx: int)
signal info_pressed

const PAD_X := 40
const PAD_Y := 26
const BAR_W := 130

var _font: Font
var _day: Label
var _place: Label
var _bars: Dictionary = {}
var _nums: Dictionary = {}
var _tags: Dictionary = {}
var _lang: OptionButton
var _info_btn: Button


func setup(font: Font, lang: int) -> void:
	_font = font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim()
	_left()
	_right(lang)


## 两块半透明纸板垫在文字下面：整宽的一条会把布景洗白，垫块更干净。
func _scrim() -> void:
	_paper(Vector2(24, 12), Vector2(250, 76), 0.72)
	_paper(Vector2(1280 - 312, 12), Vector2(288, 176), 0.80)


func _paper(pos: Vector2, size: Vector2, alpha: float) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.90, alpha)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)


func _left() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(PAD_X, PAD_Y)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_day = _label(22, Palette.INK)
	col.add_child(_day)

	_place = _label(16, Palette.SOFT)
	col.add_child(_place)


func _right(lang: int) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.position = Vector2(-260, 22)
	col.custom_minimum_size = Vector2(220, 0)
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	for axis in Palette.AXIS_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)

		var tag := _label(13, Palette.SOFT)
		tag.custom_minimum_size = Vector2(38, 0)
		row.add_child(tag)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(BAR_W, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Palette.AXIS[axis]
		fill.set_corner_radius_all(2)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(Palette.LINE.r, Palette.LINE.g, Palette.LINE.b, 0.55)
		bg.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)

		var num := _label(14, Palette.INK)
		num.custom_minimum_size = Vector2(28, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(num)

		_tags[axis] = tag
		_bars[axis] = bar
		_nums[axis] = num

	# 语言下拉与「资料」按钮：贴在右侧纸板的底边，别再掉到屏幕外去。
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.position = Vector2(-312 + 18, 12 + 138)
	add_child(tools)

	_lang = OptionButton.new()
	_lang.add_theme_font_override("font", _font)
	_lang.add_theme_font_size_override("font_size", 14)
	_lang.add_item("简体", 0)
	_lang.add_item("繁體", 1)
	_lang.add_item("EN", 2)
	_lang.selected = lang
	_lang.custom_minimum_size = Vector2(92, 30)
	_lang.item_selected.connect(func(i: int) -> void: lang_changed.emit(i))
	tools.add_child(_lang)

	var info := Button.new()
	info.text = "资料"
	info.add_theme_font_override("font", _font)
	info.add_theme_font_size_override("font_size", 14)
	info.custom_minimum_size = Vector2(70, 30)
	info.pressed.connect(func() -> void: info_pressed.emit())
	tools.add_child(info)
	_info_btn = info


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## day_text / place_text 已经翻好，这里不再管语言。
func paint(day_text: String, place_text: String, values: Dictionary, names: Dictionary) -> void:
	_day.text = day_text
	_place.text = place_text
	for axis in Palette.AXIS_ORDER:
		var v := int(values.get(axis, 0))
		_bars[axis].value = v
		_nums[axis].text = str(v)
		# 环境负荷是「负担」，不是成就：条越长越糟，所以它不跟另外三条共用轴色，
		# 改成「低=绿、中=琥珀、高=锈红」的三段警示色，标签再挂个下箭头。
		if axis == "p":
			_set_fill(axis, _burden_color(v))
		var nm := String(names.get(axis, ""))
		_tags[axis].text = (nm + " ↓") if axis == "p" else nm


## 负担轴的三段色：和 HTML 版同一套阈值（75 / 50），两个端口径一致。
func _burden_color(v: int) -> Color:
	if v >= 75:
		return Color("#b8503f")
	if v >= 50:
		return Color("#b1792b")
	return Palette.AXIS["p"]


func _set_fill(axis: String, color: Color) -> void:
	var bar: ProgressBar = _bars[axis]
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", sb)


## 语言变了以后，下拉里显示的名字也得跟着换（否则切到英文还写着「简体」）。
func set_lang_index(idx: int) -> void:
	if _lang != null and _lang.selected != idx:
		_lang.selected = idx


func set_info_text(text: String) -> void:
	if _info_btn != null:
		_info_btn.text = text


## 结账时让四条格慢慢爬过去，不做瞬间跳变。
func animate_to(target: Dictionary, steps: int = 8) -> void:
	for i in steps:
		for axis in Palette.AXIS_ORDER:
			_bars[axis].value = lerpf(_bars[axis].value, clampi(int(target.get(axis, 0)), 0, 100), 0.35)
		await get_tree().create_timer(0.03).timeout
	for axis in Palette.AXIS_ORDER:
		_bars[axis].value = int(target.get(axis, 0))
		_nums[axis].text = str(int(target.get(axis, 0)))
