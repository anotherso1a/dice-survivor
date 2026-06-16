## 经验光芒流星特效节点
##
## 敌人死亡时在死亡位置生成，沿抛物线飞向玩家，
## 模拟"流星拖尾 → 被吸收"的视觉反馈。
##
## 拖尾效果：
##   - 飞行中尾焰始终指向运动反方向，就像彗星尾巴
##   - 尾焰长度动态变化：起飞时最长（拉伸感），接近玩家时逐渐缩短（压缩感）
##   - 白→蓝→白渐变 + 直径从头到尾衰减到 0
##
## 使用方式：
##   var orb := EXP_ORB_SCENE.instantiate()
##   get_parent().add_child(orb)
##   orb.start(death_pos)  # 自动飞向玩家，到达后 queue_free
extends Node2D
class_name ExpOrb


# ========== 导出参数（可在 Inspector / 场景中配置）==========

@export_group("轨迹")
## 抛物线弧顶高度（像素），越大弧线越弯
@export var arc_height: float = 80.0
## 飞行时长（秒）
@export var travel_duration: float = 0.55

@export_group("流星拖尾")
## 尾焰最大长度（像素）— 起飞时尾焰最长
@export var tail_length_max: float = 150.0
## 尾焰最小长度（像素）— 到达时缩到这个比例
@export var tail_length_ratio_at_end: float = 0.15
## 尾焰头部最大宽度（像素），Line2D 会从宽→窄渐变
@export var tail_head_width: float = 12.0

@export_group("着色器参数")
## 光芒颜色（头部光球）
@export var glow_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(v):
		glow_color = v
		_update_shader_params()
## 光晕半径倍率
@export var glow_radius: float = 1.0:
	set(v):
		glow_radius = v
		_update_shader_params()
## 呼吸脉冲速度（0 = 不闪烁）
@export var pulse_speed: float = 5.0:
	set(v):
		pulse_speed = v
		_update_shader_params()


# ========== 内部状态 ==========

var _tween: Tween = null
var _sprite: Sprite2D = null
var _tail_line: Line2D = null
var _start_pos: Vector2          # 贝塞尔起始点（敌人死亡位置）
var _last_pos: Vector2           # 上一帧位置，在 _on_tween_step 内追踪


# ========== 生命周期 ==========

func _ready() -> void:
	_sprite = get_node_or_null("GlowSprite") as Sprite2D
	_tail_line = get_node_or_null("TailLine") as Line2D
	visible = false


## 启动飞行：从 from_pos 沿抛物线飞向玩家
func start(from_pos: Vector2) -> void:
	_start_pos = from_pos
	_last_pos = from_pos
	global_position = from_pos
	visible = true
	_update_shader_params()

	if _tail_line:
		_tail_line.visible = false

	# TRANS_QUAD + EASE_OUT：起飞时高速（尾焰拉长），到达时减速（尾焰压缩）
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_on_tween_step, 0.0, 1.0, travel_duration)
	_tween.tween_callback(_on_arrived)


## 贝塞尔曲线每帧回调（t: 0→1）
## 此处同时负责：推进位置 + 更新尾焰方向 + 动态尾焰长度
func _on_tween_step(t: float) -> void:
	var player: Node2D = _find_player()
	if player == null:
		return

	# --- 计算贝塞尔位置 ---
	var end: Vector2 = player.global_position
	var ctrl: Vector2 = (_start_pos + end) * 0.5 + Vector2(0, -arc_height)
	var new_pos: Vector2 = _quadratic_bezier(_start_pos, ctrl, end, t)

	# --- 更新尾焰方向（运动反方向）---
	if _tail_line:
		var vel: Vector2 = new_pos - _last_pos
		if vel.length_squared() > 1.0:
			var tail_dir: Vector2 = -vel.normalized()

			# 动态尾焰长度：t=0 时最长（100%），t=1 时最短（tail_length_ratio_at_end）
			var current_len: float = lerpf(tail_length_max, tail_length_max * tail_length_ratio_at_end, t)

			# 3 点折线：头部 → 中间过渡 → 尖端
			_tail_line.points = PackedVector2Array([
				Vector2.ZERO,                     # 头部（光球中心）
				tail_dir * current_len * 0.35,   # 中间点
				tail_dir * current_len,           # 尖端
			])
			_tail_line.visible = true
		else:
			_tail_line.visible = false

	global_position = new_pos
	_last_pos = new_pos


## 到达玩家位置 → 播放吸收动画 → 自毁
func _on_arrived() -> void:
	if _tail_line:
		_tail_line.visible = false  # 到达瞬间熄灭尾焰

	var a: Tween = create_tween()
	a.set_parallel(true)
	a.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	a.tween_property(self, "modulate:a", 0.6, 0.08)
	a.tween_interval(0.08)
	a.set_parallel(false)
	a.tween_property(self, "scale", Vector2(0.0, 0.0), 0.12)
	a.tween_callback(queue_free)


# ========== 内部工具 ==========

func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	return players[0] as Node2D if players.size() > 0 else null


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func _update_shader_params() -> void:
	if _sprite == null:
		return
	var mat: ShaderMaterial = _sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glow_color", glow_color)
	mat.set_shader_parameter("glow_radius", glow_radius)
	mat.set_shader_parameter("pulse_speed", pulse_speed)
