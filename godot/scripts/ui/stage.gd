extends Node2D

## 320×180 像素舞台。所有坐标都是整数像素。
## 机位固定：地面永远在 y=104，人物永远站在同一位置 —— 换的只是布景。
## 下方 104..180 会被对话框盖住，所以布景全部画在 0..104 这一段里。
##
## 画风三条规矩：
##   1. 每块家具都要有 1 像素深色边（不然像贴纸）；
##   2. 大块平色只留墙和地面，别的都加一层暗面；
##   3. 光从左上来，右下角统一压暗。

const W := 320
const H := 180
const GROUND := 104

const INK := Color("#1b1a17")
const DARK := Color("#2f2b25")
const WOOD := Color("#4a443a")
const WOOD2 := Color("#6b6353")
const WOOD3 := Color("#877c66")
const STONE := Color("#8d866f")
const STONE2 := Color("#b3ac93")
const PAPER := Color("#d9d4c8")
const PAPER2 := Color("#f0ece1")
const WHITE := Color("#fffefb")
const BLUE := Color("#3d6480")
const BLUE2 := Color("#5a86a2")
const GREEN := Color("#3f7461")
const GREEN2 := Color("#7fae8f")
const OCHRE := Color("#c58a3a")
const RED := Color("#b8503f")
const GOLD := Color("#e8c86a")
const PLUM := Color("#5a4a6b")
const SKIN := Color("#e8c6a0")

var place: String = "home"
var figure_x: float = 160.0
var figure_target: float = 160.0
var walk_t: float = 0.0
var blink_t: float = 0.0

## 夜：结算时才开，整幅压暗 + 桌上一盏灯
var night: bool = false
var night_t: float = 0.0
## NPC 站位；空串表示这场没人
var npc_name: String = ""
var npc_x: float = 236.0
var npc_t: float = 0.0


func set_place(p: String) -> void:
	place = p
	queue_redraw()


func set_night(on: bool) -> void:
	night = on
	queue_redraw()


func set_npc(who: String, x: float = 236.0) -> void:
	npc_name = who
	npc_x = x
	queue_redraw()


func clear_npc() -> void:
	npc_name = ""


func walk_to(x: float) -> void:
	figure_target = clampf(x, 24.0, 296.0)


func _process(delta: float) -> void:
	blink_t += delta
	npc_t += delta
	if night:
		night_t = minf(1.0, night_t + delta * 2.2)
	else:
		night_t = maxf(0.0, night_t - delta * 3.0)
	if absf(figure_target - figure_x) > 0.5:
		var dir := signf(figure_target - figure_x)
		figure_x += dir * 72.0 * delta
		walk_t += delta * 9.0
	else:
		figure_x = figure_target
		walk_t += delta * 2.0
	queue_redraw()


func _draw() -> void:
	match place:
		"market":
			_market()
		"lab":
			_lab()
		"fabric":
			_fabric()
		_:
			_home()
	if npc_name != "":
		_npc(npc_name, int(npc_x))
	_figure()
	if night_t > 0.001:
		_lamplight()
	_vignette()


# ---------------------------------------------------------------- 画块工具

## 一块家具：填充 + 上/左两条深边 + 一条高光，读起来就有厚度。
func _slab(r: Rect2, face: Color, edge: Color = INK, alpha: float = 0.55) -> void:
	draw_rect(r, face)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(edge.r, edge.g, edge.b, alpha))
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), Color(edge.r, edge.g, edge.b, alpha * 0.8))
	draw_rect(
		Rect2(r.position.x + 1, r.position.y + r.size.y - 1, r.size.x - 1, 1),
		Color(0, 0, 0, alpha * 0.45)
	)


## 墙：三段很浅的色阶，比一整块平色耐看，也不会抢戏。
func _wall(w: int, h: float, base: Color) -> void:
	var bands := 3
	for i in bands:
		var y := h / bands * i
		var tint := base.lightened(0.035 * float(bands - 1 - i))
		draw_rect(Rect2(0, y, w, h / bands + 1), tint)


## 地面：木条 + 靠墙那一排压暗。
func _floor(base: Color) -> void:
	draw_rect(Rect2(0, GROUND, W, H - GROUND), base)
	draw_rect(Rect2(0, GROUND, W, 3), base.darkened(0.16))
	for i in 8:
		draw_rect(Rect2(i * 40, GROUND, 1, H - GROUND), base.darkened(0.10))
	draw_rect(Rect2(0, GROUND + 3, W, 1), base.lightened(0.10))


## 地脚线：把墙和地面分开，画面立刻不糊。
func _skirting(tint: Color = WOOD2) -> void:
	draw_rect(Rect2(0, GROUND - 5, W, 5), tint)
	draw_rect(Rect2(0, GROUND - 5, W, 1), tint.lightened(0.22))


# ---------------------------------------------------------------- 四套布景

func _home() -> void:
	_wall(W, GROUND - 5, Color("#cdc5b0"))
	_floor(Color("#b3aa96"))
	_skirting(WOOD2)

	# 窗：外框 + 玻璃 + 窗台
	_slab(Rect2(22, 14, 62, 48), WOOD)
	draw_rect(Rect2(26, 18, 54, 40), Color("#9db9c2"))
	draw_rect(Rect2(26, 18, 54, 18), Color("#b6cdd3"))
	draw_rect(Rect2(52, 18, 2, 40), WOOD)
	draw_rect(Rect2(26, 36, 54, 2), WOOD)
	draw_rect(Rect2(24, 60, 58, 3), WOOD3)

	# 橱柜（右）：两扇门 + 把手 + 台面
	_slab(Rect2(196, 26, 108, 58), WOOD2)
	draw_rect(Rect2(202, 32, 44, 46), WOOD)
	draw_rect(Rect2(254, 32, 44, 46), WOOD)
	draw_rect(Rect2(244, 52, 2, 6), GOLD)
	draw_rect(Rect2(252, 52, 2, 6), GOLD)
	draw_rect(Rect2(196, 84, 108, 4), WOOD3)

	# 灶台（中）
	_slab(Rect2(108, 74, 76, 10), DARK)
	draw_rect(Rect2(120, 60, 52, 14), STONE)
	draw_rect(Rect2(124, 56, 44, 4), STONE2)
	draw_rect(Rect2(136, 62, 36, 3), Color("#6d665a"))
	# 蒸汽
	var s := int(blink_t * 5.0) % 3
	draw_rect(Rect2(140, 50 - s * 3, 2, 2), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(154, 46 - s * 3, 2, 2), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(147, 42 - s * 2, 2, 2), Color(1, 1, 1, 0.30))


func _market() -> void:
	_wall(W, GROUND - 5, Color("#cbc2ac"))
	_floor(Color("#aaa18d"))
	_skirting(WOOD)

	# 三顶棚：条纹布 + 支杆 + 台面
	for i in 3:
		var x := 14 + i * 100
		var cloth := RED if i % 2 == 0 else GREEN
		draw_rect(Rect2(x, 12, 90, 10), cloth)
		for k in 5:
			draw_rect(Rect2(x + 4 + k * 18, 12, 9, 10), PAPER2)
		draw_rect(Rect2(x, 22, 90, 3), cloth.darkened(0.18))
		draw_rect(Rect2(x + 3, 25, 3, 55), WOOD)
		draw_rect(Rect2(x + 84, 25, 3, 55), WOOD)
		_slab(Rect2(x + 2, 78, 86, 8), WOOD2)

		# 菜格：三格不同颜色，每格压一道暗边
		for j in 3:
			var cx := x + 10 + j * 26
			draw_rect(Rect2(cx, 70, 22, 8), Color("#8b9583"))
			for k in 3:
				var tone := GREEN2 if (i + j + k) % 2 == 0 else OCHRE
				draw_rect(Rect2(cx + 2 + k * 7, 68, 5, 5), tone)
		# 价牌
		draw_rect(Rect2(x + 6, 60, 14, 7), PAPER2)
		draw_rect(Rect2(x + 8, 62, 10, 1), DARK)


func _lab() -> void:
	_wall(W, GROUND - 5, Color("#d0c8b4"))
	_floor(Color("#bfb6a3"))
	_skirting(WOOD2)

	# 黑板：框 + 面 + 粉笔字 + 槽
	_slab(Rect2(26, 12, 100, 46), WOOD)
	draw_rect(Rect2(30, 16, 92, 38), Color("#3a4a44"))
	draw_rect(Rect2(36, 24, 34, 2), Color(1, 1, 1, 0.72))
	draw_rect(Rect2(36, 32, 48, 2), Color(1, 1, 1, 0.60))
	draw_rect(Rect2(36, 40, 26, 2), Color(1, 1, 1, 0.44))
	draw_rect(Rect2(30, 54, 92, 3), WOOD3)

	# 长桌（靠左）
	_slab(Rect2(8, 80, 110, 8), WOOD2)
	draw_rect(Rect2(14, 88, 5, 16), WOOD)
	draw_rect(Rect2(106, 88, 5, 16), WOOD)

	# 缝纫机
	_slab(Rect2(38, 62, 36, 16), DARK)
	draw_rect(Rect2(46, 56, 6, 7), STONE2)
	draw_rect(Rect2(70, 68, 10, 3), GOLD)
	draw_rect(Rect2(58, 58, 3, 6), STONE)

	# 布料卷（右）
	_slab(Rect2(238, 66, 42, 12), PLUM)
	draw_rect(Rect2(238, 66, 42, 3), PLUM.lightened(0.25))
	draw_rect(Rect2(276, 66, 4, 12), DARK)


func _fabric() -> void:
	_wall(W, GROUND - 5, Color("#d5cdb9"))
	_floor(Color("#c3baa6"))
	_skirting(WOOD2)

	# 两层货架：布匹色块 + 折痕高光
	for row in 2:
		var y := 32 + row * 26
		for i in 9:
			var x := 22 + i * 30
			var cols := [PLUM, BLUE, GREEN, OCHRE, RED, STONE, GREEN2, GOLD, PAPER]
			var c: Color = cols[i % cols.size()]
			draw_rect(Rect2(x, y - 16, 18, 16), c)
			draw_rect(Rect2(x, y - 16, 18, 1), c.lightened(0.30))
			draw_rect(Rect2(x + 2, y - 13, 14, 2), Color(1, 1, 1, 0.22))
		_slab(Rect2(18, y, 284, 4), WOOD)

	# 裁桌（左）：桌沿 + 纸样 + 剪刀
	_slab(Rect2(20, 86, 92, 7), WOOD2)
	draw_rect(Rect2(26, 93, 4, 11), WOOD)
	draw_rect(Rect2(102, 93, 4, 11), WOOD)
	draw_rect(Rect2(30, 82, 30, 4), PAPER2)
	draw_rect(Rect2(62, 83, 10, 1), DARK)
	draw_rect(Rect2(62, 80, 1, 1), STONE2)
	draw_rect(Rect2(66, 80, 1, 1), STONE2)


# ---------------------------------------------------------------- 人物

## 两个人共用一套骨架：腿 / 身 / 头 / 头发 / 眼睛，外面一圈 1 像素深边。
func _body(x: int, y: int, coat: Color, tall: float, hair: Color, swing: int, bob: int) -> void:
	var h_leg := int(13.0 * tall)
	var h_body := int(15.0 * tall)
	var h_head := int(12.0 * tall)
	var yy := y + bob

	# 影子
	draw_rect(Rect2(x - 9, y + 1, 18, 3), Color(0.18, 0.16, 0.13, 0.20))

	# 腿 + 鞋
	var lx0 := x - 5 + swing
	var lx1 := x + 1 - swing
	draw_rect(Rect2(lx0, yy - h_leg, 4, h_leg), DARK)
	draw_rect(Rect2(lx1, yy - h_leg, 4, h_leg), DARK)
	draw_rect(Rect2(lx0 - 1, yy - 2, 6, 2), INK)
	draw_rect(Rect2(lx1 - 1, yy - 2, 6, 2), INK)

	# 身体：外框 → 衣身 → 高光
	var bx := x - 7
	var by := yy - h_leg - h_body
	draw_rect(Rect2(bx - 1, by - 1, 16, h_body + 1), INK)
	draw_rect(Rect2(bx, by, 14, h_body), coat)
	draw_rect(Rect2(bx, by, 14, 2), coat.lightened(0.22))
	draw_rect(Rect2(bx, by + h_body - 2, 14, 1), coat.darkened(0.22))
	# 袖子
	draw_rect(Rect2(bx - 2, by + 2, 2, h_body - 5), coat.darkened(0.10))
	draw_rect(Rect2(bx + 14, by + 2, 2, h_body - 5), coat.darkened(0.10))

	# 头
	var hy := by - h_head
	draw_rect(Rect2(x - 7, hy - 1, 14, h_head + 1), INK)
	draw_rect(Rect2(x - 6, hy, 12, h_head), SKIN)
	# 头发：顶上一窄条 + 额前一条 + 鬓角，比一整块黑更像人
	draw_rect(Rect2(x - 6, hy - 3, 12, 2), hair)
	draw_rect(Rect2(x - 6, hy - 3, 12, 1), hair.lightened(0.22))
	draw_rect(Rect2(x - 7, hy - 1, 14, 2), hair)
	draw_rect(Rect2(x - 7, hy + 1, 2, 3), hair)
	draw_rect(Rect2(x + 5, hy + 1, 2, 2), hair)
	# 眼睛（眨眼：每 7 个刻度闭一次）
	if int(blink_t * 1.6) % 7 != 0:
		draw_rect(Rect2(x - 3, hy + 5, 2, 2), INK)
		draw_rect(Rect2(x + 2, hy + 5, 2, 2), INK)
	else:
		draw_rect(Rect2(x - 3, hy + 6, 2, 1), INK)
		draw_rect(Rect2(x + 2, hy + 6, 2, 1), INK)


func _figure() -> void:
	_body(int(figure_x), GROUND, BLUE, 1.0, DARK, int(sin(walk_t) * 2.0), 0)


func _npc(who: String, x: int) -> void:
	var coat := RED
	var tall := 1.0
	var hair := DARK
	match who:
		"母亲", "mother", "妈妈":
			coat = Color("#8f5a52")
			tall = 1.05
		"妹妹", "sister":
			coat = Color("#7fae8f")
			tall = 0.84
			hair = Color("#3b2f28")
		"同学", "classmate":
			coat = Color("#5a7a8c")
			tall = 0.96
		"家政科教师", "teacher":
			coat = Color("#6b6353")
			tall = 1.03
		"档主", "vendor":
			coat = Color("#c58a3a")
			tall = 1.02
		"裁缝", "tailor":
			coat = PLUM
	_body(x, GROUND, coat, tall, hair, 0, int(sin(npc_t * 1.6)))


# ---------------------------------------------------------------- 光

## 夜：整幅压蓝，再在左边桌上点一盏灯。灯是画出来的，光锥围着它。
func _lamplight() -> void:
	var a := night_t
	draw_rect(Rect2(0, 0, W, H), Color(0.07, 0.09, 0.15, 0.62 * a))

	var lx := 78.0
	var ly := 84.0
	for i in 4:
		var rw := 104.0 - i * 22.0
		var rh := 46.0 - i * 10.0
		draw_set_transform(Vector2(lx, ly), 0.0, Vector2(1.0, rh / rw))
		draw_circle(Vector2.ZERO, rw, Color(1.0, 0.84, 0.55, (0.07 + i * 0.05) * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_slab(Rect2(44, 94, 84, 5), WOOD2)
	draw_rect(Rect2(50, 99, 4, 5), WOOD)
	draw_rect(Rect2(120, 99, 4, 5), WOOD)

	draw_rect(Rect2(lx - 7, 92, 14, 2), DARK)
	draw_rect(Rect2(lx - 1, 78, 2, 14), DARK)
	draw_rect(Rect2(lx - 13, 70, 26, 8), GOLD)
	draw_rect(Rect2(lx - 13, 70, 26, 2), Color("#f2dfa6"))
	draw_rect(Rect2(lx - 9, 78, 18, 2), Color(1.0, 0.93, 0.72, 0.85 * a))


## 四边压暗 —— 很轻，但能把注意力收到中间。
func _vignette() -> void:
	for i in 6:
		var a := 0.02 + float(i) * 0.008
		draw_rect(Rect2(i, 0, W - i * 2, 1), Color(0, 0, 0, a))
		draw_rect(Rect2(i, H - 1 - i, W - i * 2, 1), Color(0, 0, 0, a))
		draw_rect(Rect2(i, 0, 1, H), Color(0, 0, 0, a * 0.7))
		draw_rect(Rect2(W - 1 - i, 0, 1, H), Color(0, 0, 0, a * 0.7))
	# 上沿一道极细的深线，像画框
	draw_rect(Rect2(0, 0, W, 1), Color(WOOD.r, WOOD.g, WOOD.b, 0.5))
