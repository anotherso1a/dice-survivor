## 攻击效果基类 - 定义所有攻击类型的通用属性和接口
class_name AttackEffect
extends Resource
@export_group("基础属性")
@export var effect_name: String = ""
@export var effect_type: EffectType = EffectType.PROJECTILE
@export var element: ElementType = ElementType.NONE
@export var base_damage: int = 0
@export var damage_multiplier: float = 1.0
@export var cooldown: float = 1.0

@export_group("视觉效果")
@export var cast_vfx: String = ""
@export var impact_vfx: String = ""
@export var projectile_vfx: String = ""

## 攻击类型枚举
enum EffectType { PROJECTILE, MELEE, SPELL, DURATION, SUMMON }

## 元素类型枚举
enum ElementType { NONE, FIRE, FROST, LIGHTNING, POISON, HOLY, DARK }

## 遗物修饰接口 - 子类重写此方法来应用类型特定的修饰
func apply_relic_modifiers(relics: Array[RelicData]) -> void:
	# 通用修饰（所有类型都有的）
	for relic in relics:
		if relic == null:
			continue
		match relic.relic_id:
			"attack_power":  # 攻击力+10%
				damage_multiplier += 0.1
			"cooldown_reduction":  # 冷却-10%
				cooldown *= 0.9
	
	# 类型特定修饰（由子类实现）
	_apply_type_specific_relics(relics)

func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
	# 基类不做任何事，子类重写
	pass

## 计算最终伤害
## face_damage: 骰面配置的伤害值（FaceData.damage）
func calculate_damage(face_damage: int) -> int:
	var damage: int = base_damage + face_damage
	damage = int(damage * damage_multiplier)
	return maxi(damage, 1)
