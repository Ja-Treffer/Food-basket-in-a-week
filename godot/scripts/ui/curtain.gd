extends ColorRect
class_name Curtain

## 换场用的黑幕。手写补间 —— Tween 会被下一次调用打断，断了就停在半黑，
## 整幅像蒙了层灰（这坑踩过一次）。
##
## View 只负责「变黑 / 变亮」这一段动画；什么时候用它由 Presenter 决定。

signal reached

const SPEED := 4.6

var _alpha: float = 0.0
var _target: float = 0.0
var _instant: bool = false


func setup(instant: bool) -> void:
	_instant = instant
	color = Color(0.06, 0.06, 0.07, 0.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


## 变黑，等它真的黑透。
func cover() -> void:
	_go(1.0)
	await reached


## 变亮，等它真的清干净。
func uncover() -> void:
	_go(0.0)
	await reached


func _go(target: float) -> void:
	_target = target
	if _instant:
		_alpha = target
		color.a = target
		reached.emit.call_deferred()
		return
	if absf(_alpha - _target) <= 0.001:
		reached.emit.call_deferred()


func _process(delta: float) -> void:
	if _instant:
		return
	if absf(_alpha - _target) <= 0.001:
		_alpha = _target
		color.a = _alpha
		return
	_alpha = move_toward(_alpha, _target, delta * SPEED)
	color.a = _alpha
	if absf(_alpha - _target) <= 0.001:
		_alpha = _target
		color.a = _alpha
		reached.emit()
