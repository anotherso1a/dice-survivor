## 投射物攻击执行器 - 处理子弹、火球、冰锥等
class_name ProjectileExecutor
extends AttackExecutor

## 调试开关
@export var debug: bool = false


## 执行投射物攻击
func _execute_attack(face: FaceData, source: Node2D, effect: AttackEffect, damage: int, relics: Array[RelicData]) -> void:
	var projectile_effect: ProjectileEffect = effect as ProjectileEffect
	if projectile_effect == null:
		push_error("[ProjectileExecutor] effect 不是 ProjectileEffect 类型")
		return
	
	## 播放施法 VFX
	_play_cast_vfx(source, effect)
	
	## 获取基础方向（朝向最近敌人）
	var base_direction: Vector2 = _get_base_direction(source, projectile_effect)
	
	## 创建多个投射物（扇形发射）
	for i in range(projectile_effect.projectile_count):
		_create_projectile(source, face, projectile_effect, damage, base_direction, i)


## 获取基础发射方向
func _get_base_direction(source: Node2D, effect: ProjectileEffect) -> Vector2:
	## 默认：朝向最近敌人
	var nearest: Node2D = _find_nearest_enemy(source)
	if nearest != null:
		return (nearest.global_position - source.global_position).normalized()
	
	## 兜底：朝向玩家面向方向
	if source.has_method("get_facing_direction"):
		return source.get_facing_direction()
	
	return Vector2.RIGHT  # 默认向右


## 创建单个投射物
func _create_projectile(source: Node2D, face: FaceData, effect: ProjectileEffect, damage: int, base_direction: Vector2, index: int) -> void:
	## 加载子弹场景（优先使用 effect.projectile_scene，否则使用默认 bullet.tscn）
	var bullet_scene: PackedScene = null
	if effect != null and effect.projectile_scene != null:
		bullet_scene = effect.projectile_scene
	
	if bullet_scene == null:
		bullet_scene = load("res://scenes/effects/bullet.tscn")
	
	if bullet_scene == null:
		push_error("[ProjectileExecutor] 无法加载 bullet.tscn")
		return
	
	var bullet = bullet_scene.instantiate()
	if bullet == null:
		push_error("[ProjectileExecutor] 无法实例化子弹")
		return
	
	## 计算方向（考虑扇形）
	var direction: Vector2 = base_direction
	if effect != null:
		direction = effect.get_spread_direction(base_direction, index)
	
	## 计算穿透参数
	var penetration: int = 0
	var damage_mult: float = 1.0
	if face != null:
		var pen_result: Array = Bullet.calc_penetration(face.value)
		penetration = pen_result[0] if pen_result.size() > 0 else 0
		damage_mult = pen_result[1] if pen_result.size() > 1 else 1.0
	
	## 设置子弹属性
	if bullet.has_method("setup"):
		bullet.setup(direction, damage, face, penetration, damage_mult, effect)
	
	## 设置位置
	bullet.global_position = source.global_position + direction * 20.0
	
	## 添加到场景
	if source.get_tree() != null:
		source.get_tree().current_scene.add_child(bullet)
	
	if debug:
		print("[ProjectileExecutor] 创建子弹 | pos:%s | dir:%s" % [bullet.global_position, direction])


## 播放施法 VFX（TODO: 实现）
func _play_cast_vfx(source: Node2D, effect: AttackEffect) -> void:
	## TODO: 根据 effect.cast_vfx 播放特效
	pass
