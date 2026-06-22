## 投射物攻击效果 - 子弹、火球、冰锥等
class_name ProjectileEffect
extends AttackEffect

func _init() -> void:
	effect_type = EffectType.PROJECTILE

@export_group("投射物属性")
@export var speed: float = 500.0
@export var penetration: int = 0  # 穿透次数（-1 = 无限）
@export var bounce: int = 0  # 弹射次数
@export var size_multiplier: float = 1.0  # 大小倍率
@export var projectile_count: int = 1  # 投射物数量（遗物可修改为+1）
@export var spread_angle: float = 0.0  # 扇形发射角度
@export var lifetime: float = 2.0  # 投射物存在时间（秒）
@export var projectile_scene: PackedScene  # 投射物场景（null=使用默认 bullet.tscn）

@export_group("元素效果")
@export var freeze_chance: float = 0.0  # 冰冻概率（0.0~1.0）
@export var freeze_duration: float = 2.0  # 冰冻持续时间（秒）
@export var burn_duration: float = 2.0  # 点燃持续时间（秒）
@export var burn_tick_interval: float = 0.5  # 点燃伤害间隔（秒）
@export var burn_damage: int = 1  # 点燃每次伤害
@export var slow_duration: float = 2.0  # 减速持续时间（秒）
@export var slow_factor: float = 0.5  # 减速因子（0.5 = 减速50%）

@export_group("特殊效果")
@export var is_homing: bool = false  # 是否追踪
@export var homing_strength: float = 0.0  # 追踪力度
@export var has_trail: bool = true  # 是否有拖尾

## 应用投射物专用的遗物修饰
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
	for relic in relics:
		if relic == null:
			continue
		match relic.relic_id:
			&"projectile_count_up":  # 投射物数量+1
				projectile_count += 1
			&"projectile_penetration_up":  # 穿透+1
				if penetration >= 0:
					penetration += 1
			&"projectile_speed_up":  # 速度+20%
				speed *= 1.2
			&"projectile_size_up":  # 大小+15%
				size_multiplier *= 1.15
			&"projectile_bounce_up":  # 弹射+1
				bounce += 1

## 获取扇形发射的单个方向
func get_spread_direction(base_direction: Vector2, index: int) -> Vector2:
	if projectile_count == 1:
		return base_direction
	
	var start_angle: float = -spread_angle / 2.0
	var angle_step: float = spread_angle / maxi(projectile_count - 1, 1)
	var current_angle: float = start_angle + angle_step * index
	
	# 旋转基础方向
	return base_direction.rotated(deg_to_rad(current_angle))
