## 攻击执行器基类 - 定义攻击执行的通用接口
class_name AttackExecutor
extends RefCounted

## 工厂方法 - 根据 AttackEffect 类型创建对应的执行器
static func create_executor(effect: AttackEffect) -> AttackExecutor:
	if effect == null:
		push_error("AttackExecutor: AttackEffect 为 null")
		return null
	
	# 动态加载执行器脚本（避免类名未解析的问题）
	var script_path: String = ""
	match effect.effect_type:
		AttackEffect.EffectType.PROJECTILE:
			script_path = "res://scripts/systems/projectile_executor.gd"
		AttackEffect.EffectType.MELEE:
			script_path = "res://scripts/systems/melee_executor.gd"
		AttackEffect.EffectType.SPELL:
			script_path = "res://scripts/systems/spell_executor.gd"
		AttackEffect.EffectType.DURATION:
			script_path = "res://scripts/systems/duration_executor.gd"
		AttackEffect.EffectType.SUMMON:
			script_path = "res://scripts/systems/summon_executor.gd"
		_:
			push_error("AttackExecutor: 未知的攻击类型 %d" % effect.effect_type)
			return null
	
	var script: Script = load(script_path)
	if script == null:
		push_error("AttackExecutor: 无法加载脚本 %s" % script_path)
		return null
	
	var executor: AttackExecutor = script.new()
	if executor == null:
		push_error("AttackExecutor: 无法创建执行器实例 %s" % script_path)
		return null
	
	return executor

## 执行攻击 - 由子类实现具体逻辑
func execute(face: FaceData, source: Node2D, effect: AttackEffect, relics: Array[RelicData]) -> void:
	if effect == null or source == null:
		push_error("AttackExecutor: 参数无效")
		return
	
	# 1. 应用遗物修饰
	effect.apply_relic_modifiers(relics)
	
	# 2. 计算最终伤害（传入 FaceData.damage，而非 face_value）
	var final_damage: int = effect.calculate_damage(face.damage)
	# 暴击伤害翻倍
	if face.is_crit:
		final_damage *= 2
	
	# 3. 执行具体攻击逻辑（由子类实现）
	_execute_attack(face, source, effect, final_damage, relics)

## 子类必须重写的攻击执行方法
func _execute_attack(face: FaceData, source: Node2D, effect: AttackEffect, damage: int, relics: Array[RelicData]) -> void:
	push_error("AttackExecutor: 子类必须实现 _execute_attack()")

## 播放 cast VFX
func _play_cast_vfx(source: Node2D, effect: AttackEffect) -> void:
	if effect == null or effect.cast_vfx.is_empty():
		return
	
	# TODO: 实例化 VFX 场景
	pass

## 获取最近的敌人
func _find_nearest_enemy(source: Node2D, max_range: float = -1) -> Node2D:
	if source == null or source.get_tree() == null:
		return null
	
	var nearest: Node2D = null
	var nearest_dist: float = INF
	
	for enemy in source.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		
		var dist: float = source.global_position.distance_to(enemy.global_position)
		
		if max_range > 0 and dist > max_range:
			continue
		
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest
