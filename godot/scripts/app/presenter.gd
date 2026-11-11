extends Node
class_name Presenter

## MVP 里的 P。
##
## 只干一件事：决定「下一步给玩家看什么」，然后把话说给 View 听。
## 它不知道像素怎么画、字怎么排、对话框几像素高；
## View 也不知道 Model 里有个 v["p"] 在动 —— 两边都只认 Presenter。

const ANCHOR_ME := 150.0
const ANCHOR_NPC := 236.0

const PLACE_KEY := {
	"home": "家中厨房",
	"market": "街市",
	"lab": "家政室",
	"fabric": "布店",
}

var model: TradeoffSession
var i18n: I18nBox
var stage: Node2D
var hud: Hud
var box: DialogueBox
var card: ModalCard
var curtain: Curtain
var info: InfoPanel
var title: TitleScreen

var seed_value: int = 2026
var lang: int = 0


func bind(p_model: TradeoffSession, p_i18n: I18nBox, views: Dictionary) -> void:
	model = p_model
	i18n = p_i18n
	stage = views["stage"]
	hud = views["hud"]
	box = views["box"]
	card = views["card"]
	curtain = views["curtain"]
	info = views["info"]


## 开场：摆好厨房，等标题页被按下。
func boot() -> void:
	stage.set_place("home")
	stage.set_night(false)
	stage.set_npc(_t("母亲"), ANCHOR_NPC)
	stage.walk_to(120.0)
	_paint_hud()


## 标题页按下之后，走完一整周。
func start() -> void:
	box.open()
	await _run_week()


func set_lang(idx: int) -> void:
	lang = idx
	i18n.set_lang(idx)
	hud.set_lang_index(idx)
	if title != null:
		title.apply_texts(title_texts())
		title.set_lang(idx)
	_paint_hud()


## 标题页要显示什么，也由这里决定 —— 文案不进 View。
func title_texts() -> Dictionary:
	return {
		"title": _t("一周菜篮"),
		"sub": _sub_title(),
		"start": _t("开始这一周"),
		"links": {
			"rules": _t("怎么玩"),
			"refs": _t("参考资料"),
			"about": _t("关于"),
		},
	}


## 副标题跟着局的长短走：五天包别写「七日」。
func _sub_title() -> String:
	var d := int(model.cfg.get("days", 7))
	if d == 5:
		return _t("五日 · 一天两件事 · 结账才看见数字")
	if d == 7:
		return _t("七日 · 一天两件事 · 结账才看见数字")
	return _t("共 %d 日 · 一天两件事 · 结账才看见数字") % d


# ---------------------------------------------------------------- 资料

## 三个静态页共用一个面板，内容在这里拼。
func show_info(kind: String) -> void:
	var close := _t("关闭")
	match kind:
		"rules":
			info.open(_t("怎么玩"), _rules_body(), close)
		"refs":
			info.open(_t("参考资料"), _refs_body(), close)
		"about":
			info.open(_t("关于"), _about_body(), close)


func _rules_body() -> String:
	var lines := [
		_t("一天两件事，一周七件事。做完（或不做）就按结算日结账。"),
		_t("选择的时候不显示任何数字、区间、推荐或禁用 —— 所有影响都等到结账那天才出现在右上角。"),
		_t("四条读数是相对的 0–100：环境负荷越低越好，营养、口味、可用钱越高越好。它们互相拉扯，没有「全赢」的一手。"),
		_t("每一笔账后面都有一个依据编号，点「资料」可以翻到对应那一条。"),
		_t("「自己写一个做法」不计入读数 —— 没核过的数不由系统代填。"),
		_t("有些选择当天不生效，要过两三天才回来看你。"),
	]
	var out := ""
	for l in lines:
		out += "· " + l + "\n\n"
	return out


func _refs_body() -> String:
	var teaching: Array = []
	var design: Array = []
	for c in model.refs.keys():
		if String(c).begins_with("D"):
			design.append(c)
		else:
			teaching.append(c)
	teaching.sort()
	design.sort()
	var out := _t("摘录为原文或来源说明；编号在结算页每一笔后面。") + "\n\n"
	out += "[b]" + _t("教学依据") + "[/b]\n\n"
	for c in teaching:
		out += "[b]" + String(c) + "[/b]  " + _t(String(model.refs[c])) + "\n\n"
	out += "\n[b]" + _t("设计参数") + "[/b]  " + _t("（不是文献结论，是本教具自己的刻度与规则）") + "\n\n"
	for c in design:
		out += "[b]" + String(c) + "[/b]  " + _t(String(model.refs[c])) + "\n\n"
	return out


func _about_body() -> String:
	var lines := [
		_t("《一周菜篮》是一个七天情景模拟器，给香港家政 / 科技与生活课堂用，一局大约十分钟。"),
		_t("它不评分，不排名，不算碳足迹。四条读数只是把「这件事代价落在哪里」摆出来。"),
		_t("数值是教学映射，不是排放因子、营养素含量或港币。方向取自参考资料，刻度由课程目标决定。"),
		_t("浏览器版、现场答题版与本像素版共用同一份题与同一份依据表。"),
		_t("Godot 4.7.2 · 320×180 像素舞台 ×4 · 三语。"),
	]
	var out := ""
	for l in lines:
		out += l + "\n\n"
	return out


# ---------------------------------------------------------------- 一周

func _run_week() -> void:
	while true:
		_paint_hud()
		await _day_open()
		for t in model.today:
			await _play_task(t)
		await _settle()
		if model.is_last_day():
			await _summary()
			return
		model.advance_day()


func _day_open() -> void:
	stage.set_night(false)
	await _go_to("home")
	stage.clear_npc()
	stage.walk_to(ANCHOR_ME)
	_paint_hud()
	await _say("", _t("第 %d 日。") % model.day)
	var ev: Dictionary = model.today_event
	if not ev.is_empty():
		await _say("", _t(String(ev.get("text", ""))))
		var who := String(ev.get("npc", ""))
		if who != "":
			stage.set_npc(_t(who), ANCHOR_NPC)
			await _say(who, _t(String(ev.get("say", ""))))
	await _say("", _t("今天有两件事要做。"))
	stage.clear_npc()


func _play_task(t: Dictionary) -> void:
	var tid := String(t.get("id", ""))
	var npc := String(t.get("npc", ""))
	await _go_to(String(t.get("place", "home")))
	stage.set_npc(_t(npc), ANCHOR_NPC)
	stage.walk_to(ANCHOR_ME)
	await _beat(0.3)
	await _say(npc, _t(String(t.get("say", ""))))

	var steps: Array = t.get("steps", [])
	for i in steps.size():
		var st: Dictionary = steps[i]
		var opts: Array = st.get("opts", [])
		var labels: Array = []
		for o in opts:
			var od := o as Dictionary
			labels.append(_t(String(od.get("text", od.get("t", "")))))

		box.ask(_t(npc), _t(String(st.get("q", ""))), labels)
		var pick: int = await box.option_picked
		var opt: Dictionary = opts[pick]

		if bool(opt.get("diy", false)):
			card.open(
				_t("写下你打算怎么做（不计入读数，结账时也不替你算）："),
				_t("就这样")
			)
			await card.closed
			model.choose_diy(tid, i, _t("（自己写的做法）"))
			await _say(npc, _t("记下了。这一条我不会替你打分 —— 没核过的数就不算数。"))
			continue

		model.choose(tid, i, pick)
		var why := String(opt.get("why", ""))
		if why != "":
			await _say(npc, _t(why))
	await _say("", _t("（这件事先放这儿。）"))
	stage.clear_npc()


func _settle() -> void:
	# 结账回厨房：灯下对账，不在街市站着算。
	await _go_to("home")
	stage.set_night(true)
	stage.clear_npc()
	stage.walk_to(ANCHOR_ME)
	await _beat(0.5)
	await _say("", _t("灯亮着。把今天的花费摊开看。"))

	var rec := model.settle_day()
	for r in rec.get("rows", []):
		var row := r as Dictionary
		await _say("", _row_line(String(row.get("kind", "")), row))
		# 每一笔后面接一句「为什么」—— 这才是这套东西要教的部分。
		var why := _t(String(row.get("why", "")))
		if why != "":
			await _say("", why)
		await hud.animate_to(model.v)
	await _day_total(rec)
	_paint_hud()


## 收尾那句也跟着局的长短走。
func _closing_line() -> String:
	var d := int(model.cfg.get("days", 7))
	if d == 7:
		return _t("七天过完了。")
	if d == 5:
		return _t("五天过完了。")
	return _t("%d 天过完了。") % d


func _summary() -> void:
	stage.set_night(true)
	await _beat(0.4)
	await _say("", _closing_line())
	var names := _axis_names()
	var parts: Array = []
	for axis in Palette.AXIS_ORDER:
		parts.append("%s %d" % [names[axis], int(model.v[axis])])
	await _say("", _t("，").join(parts) + _t("。"))
	await _say("", _t("这不是分数。四本账本来就是互相拉扯的 —— 你只是把这一周过下来了。"))
	card.open(_t("再来一周？"), _t("重新开始"))
	await card.closed
	model.new_game(seed_value)
	box.open()
	await _run_week()


# ---------------------------------------------------------------- 行文

func _row_line(kind: String, row: Dictionary) -> String:
	# pick 行的 label 是「题 + 选项」拼出来的，整句查词典永远查不到 —— 分开翻再拼。
	var label := ""
	if kind == "pick" and row.has("step") and row.has("text"):
		label = _t("「%s」%s") % [_t(String(row["step"])), _t(String(row["text"]))]
	else:
		label = _t(String(row.get("label", "")))
	var line := label
	match kind:
		"skip":
			line = _t("这一件没有接。家人自行解决 —— ") + label
		"diy":
			line = _t("你自己写的做法：") + label + _t("（不计入读数）")
		"delay":
			line = _t("前几天那件事，今天有了下文：") + label
		"burn":
			line = _t("家里吃不下去了，出去补了一顿。省下的那点又还回去了。")
		"adv_ok":
			line = _t("学校回了话：这一条采纳了。")
		"adv_no":
			line = _t("学校没有回话。这一条到此为止。")
		_:
			line = label
	# 每一笔都挂上依据编号，学生可以按「资料」翻回原文。
	var codes: Array = row.get("ref", [])
	if not codes.is_empty():
		line += "　[" + _t("依据") + " " + " / ".join(codes) + "]"
	return line


func _day_total(rec: Dictionary) -> void:
	var t: Dictionary = rec.get("total", {})
	var names := _axis_names()
	var parts: Array = []
	for axis in Palette.AXIS_ORDER:
		parts.append("%s %+d" % [names[axis], int(t.get(axis, 0))])
	await _say("", _t("今天合计：") + _t("，").join(parts) + _t("。"))


# ---------------------------------------------------------------- 视图指令

func _say(who: String, text: String) -> void:
	# 回归用：带 --cjkcheck 跑一遍英文局，凡是还冒汉字的句子都打出来。
	if lang == 2 and OS.get_cmdline_user_args().has("--cjkcheck"):
		for i in text.length():
			var c := text.unicode_at(i)
			if c >= 0x4E00 and c <= 0x9FFF:
				print("[cjk] ", text)
				break
	box.say(_t(who), text)
	await box.line_done


func _go_to(place: String) -> void:
	if stage.place == place:
		return
	# 换场只走黑幕，不做镜头运动：观众坐在同一个位置，只是灯换了。
	await curtain.cover()
	stage.set_place(place)
	_paint_hud()
	await curtain.uncover()


func _paint_hud() -> void:
	if hud == null:
		return
	var days := int(model.cfg.get("days", 7))
	hud.paint(
		_t("第 %d 日 / 共 %d 日") % [model.day, days],
		_t(PLACE_KEY.get(stage.place, "家中厨房")),
		model.v,
		_axis_names(),
	)
	if box != null:
		box.hint_text = _t("点击继续")
	hud.set_lang_index(lang)
	hud.set_info_text(_t("资料"))


func _axis_names() -> Dictionary:
	return {
		"p": _t("环境"),
		"s": _t("营养"),
		"c": _t("口味"),
		"m": _t("钱"),
	}


func _t(s: String) -> String:
	return i18n.t(s) if i18n != null else s


## 给组合根用的公开别名（标题页要翻译，但那时还没有流程可跑）。
func t(s: String) -> String:
	return _t(s)


func _beat(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
