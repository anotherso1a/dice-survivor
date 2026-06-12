## 主场景控制器脚本
##
## 本脚本是游戏入口场景（Main 场景）的核心逻辑，挂载在 Main 节点上。
## 主要职责：
##   1. 管理游戏主循环（刷怪、游戏阶段切换）
##   2. 持有对 Player、Enemies 容器、HUD、UI 面板等核心节点的引用
##   3. 实现敌人随机出生算法（含警告色块预判机制）
##   4. 处理全局输入（ESC=暂停, R=遗物, D=骰子背包）
##   5. 将游戏阶段逻辑委托给 GameManager 单例
##
extends Node2D


# ========== @onready 节点引用 ==========
@onready var _player: Node2D = $Player
@onready var _enemies: Node2D = $Enemies
@onready var _hud: CanvasLayer = $HUD
@onready var _bg: ColorRect = $BG
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _relic_list: CanvasLayer = $RelicList
@onready var _dice_status: CanvasLayer = $DiceStatus


# ========== 刷怪相关常量 ==========
const SPAWN_MARGIN: float = 60.0
const WARNING_DURATION: float = 0.5
const MIN_PLAYER_DIST: float = 150.0
const VIEWPORT_W: float = 1280.0
const VIEWPORT_H: float = 720.0


# ========== @export 导出变量 ==========
@export var enemy_scene: PackedScene


## _ready() 生命周期
func _ready() -> void:
	# 初始化 RunState 骰子池（如果从菜单进入，RunState 已初始化）
	if RunState.dice_pool.is_empty():
		RunState.init_dice_pool()

	# 创建刷怪定时器
	var spawner: Timer = Timer.new()
	spawner.wait_time = 1.0
	spawner.autostart = true
	add_child(spawner)
	spawner.timeout.connect(_spawn_enemy)

	# 确保 UI 面板初始隐藏
	_pause_menu.visible = false
	_relic_list.visible = false
	_dice_status.visible = false

	print("✅ Main 场景就绪")


## _input(event) — 处理全局快捷键（在所有 UI 之前处理）
func _input(event: InputEvent) -> void:
	# ESC → 暂停菜单（最高优先级，可在任意面板打开时关闭）
	if event.is_action_pressed("ui_pause"):
		get_viewport().set_input_as_handled()
		# 如果遗物或骰子面板开着，先关闭它们
		if _relic_list.visible:
			_relic_list.visible = false
		elif _dice_status.visible:
			_dice_status.visible = false
		else:
			_pause_menu.toggle()
		return

	# R → 遗物列表（仅在非暂停时可用）
	if event.is_action_pressed("ui_relics") and not _pause_menu.visible:
		get_viewport().set_input_as_handled()
		if _dice_status.visible:
			_dice_status.visible = false
		_relic_list.toggle()
		return

	# B → 骰子背包（仅在非暂停时可用）
	if event.is_action_pressed("ui_dice_bag") and not _pause_menu.visible:
		get_viewport().set_input_as_handled()
		if _relic_list.visible:
			_relic_list.visible = false
		_dice_status.toggle()
		return


# ========== 刷怪逻辑 ==========

func _get_random_spawn_position() -> Vector2:
	var player_pos: Vector2 = _player.global_position if _player else Vector2(VIEWPORT_W / 2, VIEWPORT_H / 2)
	var pos: Vector2 = Vector2.ZERO
	for _attempt in range(20):
		pos = Vector2(
			randf_range(SPAWN_MARGIN, VIEWPORT_W - SPAWN_MARGIN),
			randf_range(SPAWN_MARGIN, VIEWPORT_H - SPAWN_MARGIN),
		)
		if pos.distance_to(player_pos) >= MIN_PLAYER_DIST:
			return pos
	return pos


func _show_spawn_warning(pos: Vector2) -> void:
	var warning: Polygon2D = Polygon2D.new()
	warning.polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10),
		Vector2(10, 10), Vector2(-10, 10)
	])
	warning.color = Color.YELLOW
	warning.z_index = 5
	warning.global_position = pos
	add_child(warning)

	var tw: Tween = create_tween()
	for _i in range(3):
		tw.tween_property(warning, "modulate:a", 0.0, 0.1)
		tw.tween_property(warning, "modulate:a", 1.0, 0.1)
	tw.tween_property(warning, "modulate:a", 0.0, 0.15)
	tw.tween_callback(warning.queue_free)


func _spawn_enemy() -> void:
	if enemy_scene == null:
		return
	var spawn_pos: Vector2 = _get_random_spawn_position()
	_show_spawn_warning(spawn_pos)

	await get_tree().create_timer(WARNING_DURATION).timeout

	var enemy := enemy_scene.instantiate() as CharacterBody2D
	if enemy == null:
		return
	enemy.global_position = spawn_pos
	_enemies.add_child(enemy)
