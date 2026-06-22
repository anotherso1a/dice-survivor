## 召唤攻击效果 - 召唤宠物协助攻击
class_name SummonEffect
extends AttackEffect

func _init() -> void:
	effect_type = EffectType.SUMMON

@export_group("召唤属性")
@export var summon_scene: PackedScene  # 召唤物场景
@export var summon_count: int = 1  # 召唤数量
@export var summon_duration: float = 10.0  # 召唤物存在时间（秒）
@export var summon_range: float = 100.0  # 召唤距离（离玩家）
@export var summon_damage: int = 5  # 召唤物伤害
@export var summon_cooldown: float = 1.0  # 召唤物攻击间隔

@export_group("AI属性")
@export var summon_speed: float = 150.0  # 召唤物移动速度
@export var summon_aoe: float = 50.0  # 召唤物攻击范围
@export var is_passive: bool = false  # 是否被动（不主动攻击）

## 应用召唤专用的遗物修饰
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
	for relic in relics:
		if relic == null:
			continue
		match relic.relic_id:
			"summon_count_up":  # 召唤数量+1
				summon_count += 1
			"summon_duration_up":  # 持续时间+20%
				summon_duration *= 1.2
			"summon_damage_up":  # 伤害+15%
				summon_damage = int(summon_damage * 1.15)
			"summon_cooldown_up":  # 攻击间隔-10%
				summon_cooldown *= 0.9
