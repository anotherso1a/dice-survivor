## 游戏流程状态机（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 GameManager.xxx 直接访问。
##
## 管理游戏阶段切换：菜单 → 战斗 → 波次清空 → 升级 → 休息站 → BOSS → 结算
## 当前 MVP 阶段：MENU 和 BATTLE 阶段完整可用，其余留骨架。
##
## 击杀升级触发：每击杀 30 只怪物，暂停游戏并弹出骰子三选一升级界面
##
extends Node


enum Phase {
	MENU,           ## 主菜单
	BATTLE,         ## 战斗中
	WAVE_CLEAR,     ## 波次清空 → 弹三选一
	LEVEL_UP,       ## 三选一升级中
	REST_STATION,   ## 休息站（旧版，保留兼容）
	VILLAGE,        ## 村庄/城镇（2D 侧方视角街道，大关卡间修整）
	BOSS,           ## BOSS 战
	GAME_OVER,      ## 死亡 / 通关
}

## 击杀升级触发间隔（每 N 杀触发一次升级选择）
const KILL_UPGRADE_INTERVAL: int = 30


@export_group("Debug")
## 当前阶段（只读查看）
@export var current_phase: Phase = Phase.MENU

## 上一次触发升级的击杀数（防止同一里程碑重复触发）
var _last_upgrade_kill_count: int = 0


func _ready() -> void:
	# 监听击杀数变化，每 30 杀触发升级
	EventBus.kill_count_changed.connect(_on_kill_count_changed)
	# 监听敌人死亡，递增击杀计数
	EventBus.enemy_died.connect(_on_enemy_died)
	print("🎮 GameManager 就绪，等待开始游戏")


func _on_enemy_died(_pos: Vector2, _data) -> void:
	## 敌人死亡，递增击杀计数（RunState.kill_count 的 setter 会自动发 kill_count_changed 信号）
	RunState.kill_count += 1


func _on_kill_count_changed(new_count: int) -> void:
	## 每击杀 KILL_UPGRADE_INTERVAL 只怪物，触发一次升级选择
	## 用 _last_upgrade_kill_count 防止同一里程碑重复触发
	if new_count <= 0:
		return
	if new_count >= KILL_UPGRADE_INTERVAL and \
	   new_count % KILL_UPGRADE_INTERVAL == 0 and \
	   new_count != _last_upgrade_kill_count:
		_last_upgrade_kill_count = new_count
		print("🎲 击杀数达到 %d，触发骰子升级选择" % new_count)
		transition_to(Phase.LEVEL_UP)


## 阶段切换（统一入口）
func transition_to(new_phase: Phase) -> void:
	var old: Phase = current_phase
	current_phase = new_phase
	EventBus.game_phase_changed.emit(
		Phase.keys()[old] as StringName,
		Phase.keys()[new_phase] as StringName,
	)
	match new_phase:
		Phase.MENU:
			pass  # 菜单场景自己管理
		Phase.BATTLE:
			_start_battle()
		Phase.WAVE_CLEAR:
			_on_wave_clear()
		Phase.LEVEL_UP:
			_show_level_up()
		Phase.REST_STATION:
			_enter_rest_station()
		Phase.VILLAGE:
			_enter_village()
		Phase.BOSS:
			_spawn_boss()
		Phase.GAME_OVER:
			_game_over()


## 战斗开始
func _start_battle() -> void:
	print("▶ 战斗开始")


## 波次清空
func _on_wave_clear() -> void:
	print("✅ 波次清空，升级选择...")
	## TODO M2：弹出三选一技能界面


## 显示升级界面（暂停游戏，弹出骰子三选一）
func _show_level_up() -> void:
	print("⬆️  进入升级选择，游戏暂停")
	get_tree().paused = true

	# 加载骰子升级选择 UI
	var ui_scene: PackedScene = load("res://scenes/ui/dice_upgrade_ui.tscn")
	if ui_scene == null:
		push_error("无法加载 res://scenes/ui/dice_upgrade_ui.tscn")
		get_tree().paused = false
		return

	var ui: CanvasLayer = ui_scene.instantiate()
	# 挂载到当前场景的根节点下
	get_tree().current_scene.add_child(ui)
	ui.dice_selected.connect(_on_dice_upgrade_selected)


## 玩家选定升级骰子后，恢复游戏并将新骰子加入玩家
func _on_dice_upgrade_selected(_dice_data: DiceData) -> void:
	print("✅ 骰子升级完成：%s" % _dice_data.dice_name)
	# 找到玩家节点，调用 add_dice 添加新骰子
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node = players[0]
		if player.has_method("add_dice"):
			player.add_dice(_dice_data)
		else:
			push_error("Player 节点没有 add_dice 方法")
	else:
		push_error("找不到 player 组中的节点")
	get_tree().paused = false
	# 回到战斗阶段
	transition_to(Phase.BATTLE)


## 进入休息站（旧版，保留兼容）
func _enter_rest_station() -> void:
	## TODO M4：加载休息站场景
	pass


## 进入村庄（N 波战斗后触发）
##
## 使用方式：
##   GameManager.transition_to(GameManager.Phase.VILLAGE)
##
## village_scene_path 可在调用前通过 set_village_scene 修改，
## 不同大关卡对应不同村庄场景（村庄、城镇、城市、城堡等）。
var village_scene_path: String = "res://scenes/world/village.tscn"

func set_village_scene(path: String) -> void:
	village_scene_path = path

func _enter_village() -> void:
	print("🏘️ 进入村庄：%s" % village_scene_path)
	var err: Error = get_tree().change_scene_to_file(village_scene_path)
	if err != OK:
		push_error("GameManager: 无法加载村庄场景 %s" % village_scene_path)


## 生成 BOSS
func _spawn_boss() -> void:
	## TODO M3：生成 BOSS 敌人
	pass


## 游戏结束
func _game_over() -> void:
	print("💀 游戏结束")
	## TODO：显示结算界面，可选重新开始
	var err := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if err != OK:
		get_tree().reload_current_scene()
