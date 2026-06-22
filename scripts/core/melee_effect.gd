## 近战攻击效果 - 挥砍、戳刺、旋转等
class_name MeleeEffect
extends AttackEffect

func _init() -> void:
	effect_type = EffectType.MELEE

enum ShapeType { FAN, CIRCLE, LINE }

@export_group("近战属性")
@export var shape_type: ShapeType = ShapeType.FAN
@export var range: float = 100.0  # 范围
@export var angle: float = 90.0  # 扇形角度（仅 FAN 类型）
@export var arc_segments: int = 8  # 弧形分段数（用于可视化）
@export var melee_damage_multiplier: float = 1.0  # 近战伤害倍率

@export_group("特殊效果")
@export var has_knockback: bool = false  # 是否有击退
@export var knockback_force: float = 100.0  # 击退力度
@export var has_stun: bool = false  # 是否眩晕
@export var stun_duration: float = 0.5  # 眩晕时长

## 应用近战专用的遗物修饰
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
	for relic in relics:
		if relic == null:
			continue
		match relic.relic_id:
			"melee_range_up":  # 近战范围+20%
				range *= 1.2
			"melee_damage_up":  # 近战伤害+15%
				melee_damage_multiplier += 0.15
			"melee_knockback_up":  # 击退+30%
				knockback_force *= 1.3

## 获取攻击范围的形状（用于检测和可视化）
func get_shape_points(center: Vector2, direction: Vector2) -> PackedVector2Array:
	match shape_type:
		ShapeType.FAN:
			return _get_fan_points(center, direction)
		ShapeType.CIRCLE:
			return _get_circle_points(center)
		ShapeType.LINE:
			return _get_line_points(center, direction)
	return PackedVector2Array()

func _get_fan_points(center: Vector2, direction: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var start_angle: float = -angle / 2.0
	var angle_step: float = angle / arc_segments
	
	for i in range(arc_segments + 1):
		var a: float = deg_to_rad(start_angle + angle_step * i)
		var point: Vector2 = center + direction.rotated(a) * range
		points.append(point)
	
	points.append(center)  # 闭合扇形
	return points

func _get_circle_points(center: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 32
	
	for i in range(segments + 1):
		var a: float = TAU / segments * i
		var point: Vector2 = center + Vector2(cos(a), sin(a)) * range
		points.append(point)
	
	return points

func _get_line_points(center: Vector2, direction: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var half_width: float = range * 0.3  # 线宽 = 范围的30%
	var length: float = range
	
	var right: Vector2 = Vector2(-direction.y, direction.x)
	
	points.append(center + direction * length + right * half_width)
	points.append(center + direction * length - right * half_width)
	points.append(center - right * half_width)
	points.append(center + right * half_width)
	points.append(center + direction * length + right * half_width)  # 闭合
	
	return points
