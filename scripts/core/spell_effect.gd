## 法术攻击效果 - 闪电、陨石、地刺等（远程无飞行过程）
class_name SpellEffect
extends AttackEffect

func _init() -> void:
	effect_type = EffectType.SPELL

@export_group("法术属性")
@export var cast_range: float = 300.0  # 施法距离
@export var aoe_radius: float = 80.0  # 范围伤害半径
@export var target_count: int = 1  # 同时攻击目标数（遗物可修改）
@export var delay: float = 0.3  # 从施法到命中的延迟（秒）
@export var has_line: bool = false  # 是否有引导线
@export var line_duration: float = 0.5  # 引导线持续时间

@export_group("特殊效果")
@export var is_instant: bool = false  # 是否瞬间命中（无延迟）
@export var has_chain: bool = false  # 是否有连锁（链伤）
@export var chain_count: int = 0  # 连锁次数
@export var chain_range: float = 150.0  # 连锁范围

## 应用法术专用的遗物修饰
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
	for relic in relics:
		if relic == null:
			continue
		match relic.relic_id:
			"spell_range_up":  # 法术范围+15%
				aoe_radius *= 1.15
				cast_range *= 1.15
			"spell_target_up":  # 目标数+1
				target_count += 1
			"spell_chain_up":  # 连锁+1
				if has_chain:
					chain_count += 1
