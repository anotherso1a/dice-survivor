## 村庄场景控制器（VillageScene）
##
## 管理村庄的整个生命周期：
##   - 响应 EventBus.village_entered → 加载场景 / 初始化 NPC
##   - 响应 NPC 互动 → 动态加载对应小游戏或 UI
##   - 响应 EventBus.village_exited → 切换到下一大关卡
##   - ESC / B 键 → 退出当前小游戏（不退出村庄）
##
## 挂载到 scenes/world/village.tscn 根节点。
##
class_name VillageScene
extends Node2D

## ─── 节点引用 ────────────────────────────────────────────────
@onready var player: VillagePlayer = $VillagePlayer
@onready var npc_container: Node2D = $NPCs
@onready var minigame_layer: CanvasLayer = $MinigameLayer
@onready var _floor: ColorRect = $Floor

## ─── 场景路径（可在编辑器中覆写）────────────────────────────
@export var dice_cup_scene_path: String = "res://scenes/minigames/dice_cup_duel.tscn"
@export var next_battle_scene_path: String = "res://scenes/Main.tscn"

## ─── 运行时状态 ──────────────────────────────────────────────
var _current_minigame: MinigameBase = null
var _active_npc: VillageNPC = null

const ACTION_EXIT_MINIGAME: StringName = &"ui_cancel"  ## ESC / B 键


func _ready() -> void:
	EventBus.village_exited.connect(_on_village_exited)

	## 连接所有 NPC 的互动信号
	for npc: Node in npc_container.get_children():
		if npc is VillageNPC:
			(npc as VillageNPC).interaction_triggered.connect(_on_npc_interaction)

	## 通知全局：已进入村庄
	var village_id: StringName = name as StringName
	EventBus.village_entered.emit(village_id)


func _input(event: InputEvent) -> void:
	## ESC / B 键：退出当前小游戏（返回街道，不离开村庄）
	if event.is_action_pressed(ACTION_EXIT_MINIGAME) and _current_minigame != null:
		_force_close_minigame()
		get_viewport().set_input_as_handled()


## ─── NPC 互动处理 ────────────────────────────────────────────
func _on_npc_interaction(npc: VillageNPC) -> void:
	if _current_minigame != null:
		return  ## 已有小游戏在跑，忽略重复触发
	_active_npc = npc
	match npc.npc_type:
		VillageNPC.NPCType.GAMBLER:
			_start_dice_cup_duel(npc)
		VillageNPC.NPCType.MERCHANT:
			_open_merchant_ui(npc)
		VillageNPC.NPCType.HEALER:
			_open_healer_ui(npc)
		_:
			push_warning("VillageScene: NPC 类型 %s 暂未实现" % VillageNPC.NPCType.keys()[npc.npc_type])


## ─── 骰盅赌斗 ────────────────────────────────────────────────
func _start_dice_cup_duel(_npc: VillageNPC) -> void:
	var scene_res: PackedScene = load(dice_cup_scene_path) as PackedScene
	if scene_res == null:
		push_error("VillageScene: 无法加载骰盅场景 %s" % dice_cup_scene_path)
		return

	var root_node := scene_res.instantiate()
	if root_node == null:
		push_error("VillageScene: 骰盅场景实例化失败")
		return

	minigame_layer.add_child(root_node)

	## 骰盅场景的根节点是 DiceCupDuelRoot（无脚本），实际游戏逻辑在子节点 DiceCupDuel 上
	var duel_node: Node = root_node.get_node_or_null("DiceCupDuel")
	if duel_node == null or not (duel_node is MinigameBase):
		push_error("VillageScene: 骰盅场景中未找到 DiceCupDuel 节点")
		root_node.queue_free()
		return

	## 用实际的逻辑节点作为小游戏实例，但保留 root 在场景树中
	_current_minigame = duel_node as MinigameBase
	_current_minigame.minigame_finished.connect(_on_minigame_finished, CONNECT_ONE_SHOT)

	## 锁定街道玩家移动
	player.lock_input(true)

	## 启动小游戏（传入骰子池 + 当前金币作为赌注）
	var bet: int = min(RunState.coins, 20)  ## 最多赌 20 金币
	_current_minigame.start(RunState.dice_pool, bet)
	EventBus.dice_cup_started.emit(bet)


## ─── 商人（预留骨架）────────────────────────────────────────
func _open_merchant_ui(_npc: VillageNPC) -> void:
	## TODO：加载商人 UI 场景
	push_warning("VillageScene: 商人 UI 待实现")


## ─── 医师（预留骨架）────────────────────────────────────────
func _open_healer_ui(_npc: VillageNPC) -> void:
	## TODO：加载医师 UI 场景
	push_warning("VillageScene: 医师 UI 待实现")


## ─── 小游戏结束处理 ──────────────────────────────────────────
func _on_minigame_finished(result: Dictionary) -> void:
	## 发放/扣除奖励
	_apply_reward(result)
	EventBus.dice_cup_finished.emit(result)

	## 清理小游戏节点（释放整个场景树）
	if _current_minigame != null:
		var root: Node = _current_minigame.get_parent()
		if root != null:
			root.queue_free()
		else:
			_current_minigame.queue_free()
		_current_minigame = null

	_active_npc = null
	## 解锁玩家移动
	player.lock_input(false)


func _force_close_minigame() -> void:
	if _current_minigame == null:
		return
	_current_minigame.force_end()
	## minigame_finished 信号会在 force_end 内发出，走 _on_minigame_finished


## ─── 奖励应用 ────────────────────────────────────────────────
func _apply_reward(result: Dictionary) -> void:
	if not result.has("won"):
		return
	var reward: Dictionary = result.get("reward", {}) as Dictionary

	var coins: int = reward.get("coins", 0) as int
	var hp: int = reward.get("hp", 0) as int

	if coins != 0:
		RunState.coins += coins
		## RunState.coins 的 setter 会自动发 coins_changed 信号

	if hp < 0:
		## 扣血（输了）
		var players: Array[Node] = get_tree().get_nodes_in_group(&"village_player")
		for p: Node in players:
			if p.has_method("take_damage"):
				p.take_damage(abs(hp))
	elif hp > 0:
		## 回血（赢了且有回血奖励）
		var players: Array[Node] = get_tree().get_nodes_in_group(&"village_player")
		for p: Node in players:
			if p.has_method("heal"):
				p.heal(hp)


## ─── 离开村庄 ────────────────────────────────────────────────
func _on_village_exited() -> void:
	print("🏘️ 玩家离开村庄，前往下一关卡")
	## 切换到下一大关卡（俯视角幸存者）
	var err: Error = get_tree().change_scene_to_file(next_battle_scene_path)
	if err != OK:
		push_error("VillageScene: 无法切换场景 %s" % next_battle_scene_path)
