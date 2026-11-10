extends SceneTree

## I18N 覆盖审计：把数据里所有会显示给玩家的字符串，按目标语言翻一遍，
## 翻完仍含汉字的，就是「漏翻」——列出来，一条一条补进 data/game-i18n.json。
##
##   --headless --script res://tests/i18n_audit.gd

const DATA := "res://data/game.json"
const I18N := "res://data/game-i18n.json"

var _miss: Dictionary = {}


func _init() -> void:
	var raw := FileAccess.get_file_as_string(DATA)
	var data: Dictionary = JSON.parse_string(raw)
	var box := I18nBox.load_from(I18N)

	for lang in [1, 2]:
		box.set_lang(lang)
		_miss.clear()
		_scan(data.get("tasks", []), box)
		_scan(data.get("long", []), box)
		_scan(data.get("events", []), box)
		_scan(data.get("cfg", {}), box)
		print("--- lang=", lang, " 漏翻 ", _miss.size(), " 条 ---")
		for s in _miss.keys():
			print("  ", JSON.stringify(s))

	quit()


func _scan(node: Variant, box: I18nBox) -> void:
	if node is String:
		_check(String(node), box)
		return
	if node is Array:
		for x in node:
			_scan(x, box)
		return
	if node is Dictionary:
		for k in node.keys():
			# refs 里的原文就是中文，故意不译
			if String(k) == "refs":
				continue
			_scan(node[k], box)
		return


func _check(s: String, box: I18nBox) -> void:
	if s.strip_edges() == "":
		return
	var han := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			han += 1
	if han < 2:
		return
	var out := box.t(s)
	# 有没有收进词典，用 has() 判，别拿译文和原文比 —— 繁体的「妹妹」本来就一样。
	if not box.has(s):
		_miss[s] = true
		return
	if box.lang == 1:
		return
	var left := 0
	for i in out.length():
		var c2 := out.unicode_at(i)
		if c2 >= 0x4E00 and c2 <= 0x9FFF:
			left += 1
	if left >= 2:
		_miss[s] = true
