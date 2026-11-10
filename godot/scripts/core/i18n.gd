extends RefCounted
class_name I18nBox

## 复用前端同一份词典（data/game-i18n.json，456 条 {zh,tw,en}）。
## 查不到就原样返回中文原文，前端与 Godot 版共用一套译文。

const LANGS := ["zh", "tw", "en"]

var lang: int = 0
var _map: Dictionary = {}

static func load_from(path: String) -> I18nBox:
	var box := I18nBox.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("i18n 词典打不开：" + path)
		return box
	var raw := f.get_as_text()
	f.close()
	var data = JSON.parse_string(raw)
	if data is Array:
		for row in data:
			if row is Dictionary and row.has("zh"):
				box._map[String(row["zh"])] = [
					String(row.get("zh", "")),
					String(row.get("tw", row.get("zh", ""))),
					String(row.get("en", row.get("zh", ""))),
				]
	return box


func size() -> int:
	return _map.size()


func set_lang(idx: int) -> void:
	lang = clampi(idx, 0, 2)


func t(s: String) -> String:
	if s == "":
		return s
	var row = _map.get(s, null)
	if row == null:
		return s
	var out := String(row[lang])
	return out if out != "" else s


func has(s: String) -> bool:
	return _map.has(s)


func ref_text(r) -> String:
	var arr: Array = []
	if r is Array:
		arr = r
	elif r is String and r != "":
		arr = r.split(" / ")
	var parts: PackedStringArray = []
	for x in arr:
		parts.append(t(String(x)))
	return " / ".join(parts)
