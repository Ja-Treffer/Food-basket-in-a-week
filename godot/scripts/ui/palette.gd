extends RefCounted
class_name Palette

## 全 UI 层共用的一套颜色与字体。
## 之前颜色散在 main.gd / stage.gd / dialogue.gd 三处，改一个色要翻三个文件。

# 纸面
const PAPER := Color("#f5f3ed")
const PAPER2 := Color("#fffefb")
const PAGE := Color("#fdfbf3")   # 对话框面，略亮一点
const LINE := Color("#d9d4c8")
const INK := Color("#23221e")
const SOFT := Color("#6f6a5e")

# 四本账（和 stage 里的像素色同源，只是深一号便于在小字号下读）
const AXIS := {
	"p": Color("#3f7461"),
	"s": Color("#3d6480"),
	"c": Color("#c58a3a"),
	"m": Color("#8a5f3c"),
}
const AXIS_NAME := { "p": "环境", "s": "营养", "c": "口味", "m": "钱" }
const AXIS_ORDER := ["p", "s", "c", "m"]

const GOLD := Color("#c58a3a")
const BLUE := Color("#3d6480")

## 中文走系统字体：不打包字体文件，Windows / macOS / Linux 都能落一个。
static func font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Microsoft YaHei UI", "微软雅黑", "PingFang SC",
		"Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f
