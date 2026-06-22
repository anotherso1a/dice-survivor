## 持续攻击效果 - 火焰路径、毒云、治疗光环等
class_name DurationEffect
extends AttackEffect

func _init() -> void:
	effect_type = EffectType.DURATION

@export_group("持续属性")
@export var duration: float = 5.0  # 持续时间（秒）
@export var tick_interval: float = 0.5  # 伤害/治疗效果间隔（秒）
@export var aoe_radius: float = 80.0  # 影响范围
@export var follow_player: bool = false  # 是否跟随玩家
@export var max_instances: int = 3  # 最大同时存在数量

@export_group("特殊效果")
@export var is_ground_based: bool = true  # 是否地面效果（不跟随Z轴）
@export var has_pulse: bool = false  # 是否有脉冲（周期性AOE）
@export var pulse_interval: float = 1.0  # 脉冲间隔

## 应用持续效果专用的遗物修饰
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
	for relic in relics:
		if relic == null:
			continue
		match relic.relic_id:
			"duration_up":  # 持续时间+20%
				duration *= 1.2
			"tick_frequency_up":  # 频率+15%（间隔减少）
				tick_interval *= 0.85
			"aoe_size_up":  # 范围+15%
				aoe_radius *= 1.15
			"max_instances_up":  # 最大数量+1
				max_instances += 1
