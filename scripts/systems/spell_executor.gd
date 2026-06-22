## 法术攻击执行器 - 闪电/陨石/AOE冲击
class_name SpellExecutor
extends AttackExecutor

## 执行法术攻击（远程无飞行过程，直接命中或短延迟）
func _execute_attack(face: FaceData, source: Node2D, effect: AttackEffect, damage: int, relics: Array[RelicData]) -> void:
	var spell_effect: SpellEffect = effect as SpellEffect
	if spell_effect == null:
		push_error("[SpellExecutor] effect 不是 SpellEffect 类型")
		return

	## 播放施法 VFX（闪电引导线 / 陨石落点标记）
	_play_cast_vfx(source, effect)

	## 延迟命中（法术有施法前摇）
	var delay: float = spell_effect.delay
	if delay > 0.0:
		## 用 SceneTreeTimer 延迟执行
		if source.get_tree() != null:
			source.get_tree().create_timer(delay).timeout.connect(
				_execute_spell_impact.bind(face, source, spell_effect, damage, relics)
			)
	else:
		_execute_spell_impact(face, source, spell_effect, damage, relics)


## 法术命中逻辑（延迟后调用）
func _execute_spell_impact(face: FaceData, source: Node2D, effect: SpellEffect, damage: int, relics: Array[RelicData]) -> void:
	## AOE 范围冲击（山岳骰子）
	var center: Vector2 = source.global_position
	var hit_enemies: Array[Node2D] = _find_enemies_in_radius(source, center, effect.aoe_radius)

	if hit_enemies.is_empty():
		return

	## 播放 AOE 爆炸 VFX
	_spawn_aoe_vfx(source, center, effect.aoe_radius)

	## 对每个敌人造成伤害
	for enemy in hit_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			var is_crit: bool = face.is_crit if face != null else false
			enemy.take_damage(damage, is_crit, face)


## 查找半径内的所有敌人
func _find_enemies_in_radius(source: Node2D, center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if source == null or source.get_tree() == null:
		return result
	for e: Node in source.get_tree().get_nodes_in_group("enemies"):
		var e2d: Node2D = e as Node2D
		if e2d == null:
			continue
		if center.distance_to(e2d.global_position) <= radius:
			result.append(e2d)
	return result


## 播放施法 VFX（子类可重写）
func _play_cast_vfx(source: Node2D, effect: AttackEffect) -> void:
	## TODO: 根据 effect.cast_vfx 播放引导线/落点标记
	pass


## 生成 AOE 爆炸 VFX
func _spawn_aoe_vfx(source: Node2D, center: Vector2, radius: float) -> void:
	var aoe := preload("res://scripts/effects/aoe_impact.gd").new()
	if aoe == null:
		return
	aoe.global_position = center
	aoe.setup(radius)
	if source.get_tree() != null:
		source.get_tree().current_scene.add_child(aoe)
