## 经验光芒生成器
##
## 监听 EventBus.enemy_died，在敌人死亡位置生成一枚流星 ExpOrb 飞向玩家。
## 本节点应挂载在主场景（Main.tscn）下。
##
## 特效是只读观察者：不修改任何游戏数据。
extends Node2D


## ExpOrb 场景引用（Inspector 中拖入 scenes/effects/exp_orb.tscn）
@export var orb_scene: PackedScene


func _ready() -> void:
	if orb_scene == null:
		push_error("ExpOrbSpawner: orb_scene 未赋值，请在 Inspector 中拖入 exp_orb.tscn")
		return

	EventBus.enemy_died.connect(_on_enemy_died)
	print("✨ ExpOrbSpawner 就绪")


func _on_enemy_died(pos: Vector2, _enemy_data) -> void:
	_spawn_orb(pos)


func _spawn_orb(from_pos: Vector2) -> void:
	var orb: ExpOrb = orb_scene.instantiate() as ExpOrb
	get_parent().add_child(orb)

	# start() 已内置玩家追踪逻辑，只需传入出生点
	orb.start(from_pos)
