## AOE 范围冲击效果 - 实例化后自动播放爆炸动画并释放
class_name AoeImpact
extends Node2D

## 爆炸半径
var _radius: float = 80.0

func _ready() -> void:
	## 创建爆炸视觉效果
	_spawn_visual()
	
	## 0.5秒后自毁
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)


## 初始化（由 SpellExecutor 调用）
func setup(radius: float) -> void:
	_radius = radius


## 生成爆炸视觉效果
func _spawn_visual() -> void:
	## 创建一组逐渐扩大的同心圆（用 Line2D 画圆）
	for i in range(3):
		var circle: Line2D = Line2D.new()
		circle.width = 2.0
		circle.default_color = Color(1.2, 0.8, 0.2, 0.8 - i * 0.2)
		circle.closed = true
		## 用 32 个点画圆
		var pts: PackedVector2Array = []
		var n: int = 32
		for j in range(n + 1):
			var angle: float = TAU * j / n
			pts.append(Vector2(cos(angle), sin(angle)) * _radius * (0.3 + i * 0.2))
		circle.points = pts
		add_child(circle)
		
		## 动画：放大 + 渐隐
		var tween := create_tween()
		tween.tween_property(circle, "scale", Vector2(1.8, 1.8), 0.4)
		tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(circle.queue_free)
	
	## 中心闪光
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1.5, 1.0, 0.3, 0.6)
	flash.size = Vector2(40, 40)
	flash.position = -flash.size / 2.0
	add_child(flash)
	var tween2 := create_tween()
	tween2.tween_property(flash, "scale", Vector2(3, 3), 0.3)
	tween2.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
	tween2.tween_callback(flash.queue_free)
