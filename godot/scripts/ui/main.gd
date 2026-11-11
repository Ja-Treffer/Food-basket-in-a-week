extends Control

## 组合根（composition root）。
##
## 只做四件事：读数据 → 造 View → 造 Presenter → 连线。
## 一条业务规则都不许写在这里 —— 那都在 session.gd（Model）和
## presenter.gd（Presenter）里。这个文件长过 150 行就说明又跑偏了。

const DATA_PATH := "res://data/game.json"
const I18N_PATH := "res://data/game-i18n.json"
## 打包时写入的构建参数：{"days":5,"lang":2}。没有这个文件就用游戏自带的七天与系统语言。
const BUILD_PATH := "res://data/build.json"

var presenter: Presenter
var _font: Font


func _ready() -> void:
	_font = Palette.font()

	var data := _load(DATA_PATH)
	if data.is_empty():
		push_error("读不到 " + DATA_PATH)
		return
	var i18n := I18nBox.load_from(I18N_PATH)
	# 打包时烘进去的构建参数（五天版 / 默认英文都在这里），没有就不改。
	var build := _load(BUILD_PATH)
	var cfg: Dictionary = data.get("cfg", {})
	if build.has("days"):
		cfg["days"] = int(build["days"])
	var model := TradeoffSession.new({
		"cfg": cfg,
		"tasks": data.get("tasks", []),
		"long": data.get("long", []),
		"events": data.get("events", []),
		"refs": data.get("refs", {}),
	})

	var q := _query()
	var seed_value := int(q.get("seed", 2026))
	var lang := _default_lang(q, build)
	i18n.set_lang(lang)
	model.new_game(seed_value)

	var views := _build_views(q, lang)
	presenter = Presenter.new()
	presenter.seed_value = seed_value
	presenter.lang = lang
	presenter.bind(model, i18n, views)
	add_child(presenter)

	# 反向连线：View 只发意图，Presenter 决定后果。
	views["hud"].lang_changed.connect(presenter.set_lang)
	views["hud"].info_pressed.connect(presenter.show_info.bind("refs"))

	presenter.boot()
	if q.has("bare"):
		return
	_show_title()


## 造 View。View 自己知道自己长什么样，这里只负责把它们挂上来。
func _build_views(q: Dictionary, lang: int) -> Dictionary:
	# 像素舞台直接画在主视口里，整体 ×4。
	# 不走 SubViewport：Compatibility 下 ViewportTexture 会被当成线性色再转一次，
	# 整幅压暗成 (c/255)^2.2（实测 #c4bba6 → #908a7e）。全是 draw_rect 图元，
	# 放大 4 倍照样落在整数像素上。
	var stage := Node2D.new()
	stage.set_script(load("res://scripts/ui/stage.gd"))
	stage.scale = Vector2(4, 4)
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(stage)

	var hud := Hud.new()
	hud.setup(_font, lang)
	add_child(hud)

	var box := DialogueBox.new()
	add_child(box)
	box.close()

	var card := ModalCard.new()
	card.setup(_font)
	add_child(card)

	var curtain := Curtain.new()
	curtain.setup(q.has("nocurtain"))
	add_child(curtain)

	var info := InfoPanel.new()
	info.setup(_font)
	add_child(info)

	return {"stage": stage, "hud": hud, "box": box, "card": card, "curtain": curtain, "info": info}


func _show_title() -> void:
	var title := TitleScreen.new()
	title.setup(_font, presenter.title_texts(), presenter.lang)
	title.start_pressed.connect(_on_start.bind(title))
	title.link_pressed.connect(presenter.show_info)
	title.lang_picked.connect(presenter.set_lang)
	presenter.title = title
	add_child(title)


func _on_start(title: TitleScreen) -> void:
	presenter.title = null
	title.queue_free()
	presenter.start()


func _load(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	if raw == "":
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _query() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var body := a.substr(2)
		var eq := body.find("=")
		if eq > 0:
			out[body.substr(0, eq)] = body.substr(eq + 1)
		else:
			out[body] = "1"
	return out


## 语言优先级：命令行 --lang= > 构建烘进去的默认 > 浏览器固定英文 > 系统语言。
func _default_lang(q: Dictionary, build: Dictionary) -> int:
	if q.has("lang"):
		return _lang_id(str(q["lang"]))
	if build.has("lang"):
		# JSON 的数字是 float，str(2.0) 会变成 "2.0"，先取整。
		return _lang_id(str(int(build["lang"])))
	# 网页版默认英文：浏览器里的系统语言不可靠，课堂投影也常是英文环境。
	if OS.has_feature("web"):
		return 2
	return _lang_id("")


func _lang_id(v: String) -> int:
	match v.to_lower():
		"1", "tw", "zh-tw", "zh-hant", "繁":
			return 1
		"2", "en":
			return 2
		"0", "zh", "zh-hans", "cn", "简":
			return 0
		_:
			# 没指定就看系统语言：中文系统给中文，其余默认英文。
			var loc := OS.get_locale().to_lower()
			if loc.begins_with("zh"):
				if loc.contains("hant") or loc.contains("tw") or loc.contains("hk"):
					return 1
				return 0
			return 2
