## HUD 界面脚本
##
## 本脚本负责游戏中所有常驻 UI 信息的显示，挂载在 HUD 节点上。
## 核心设计原则：HUD 不直接引用 Player 或 Enemy 节点，而是通过订阅
## EventBus 的信号来获取游戏数据，实现 UI 与游戏逻辑的完全解耦。
## 挂载节点：scenes/ui/HUD.tscn
##
## 功能模块：
##   - HP 条（彩色渐变：绿→黄→红）
##   - 金币显示
##   - 击杀计数
##   - 骰子快捷信息（当前激活骰子名称 + 冷却）
##   - 遗物计数徽章（点击 / 按 R 打开遗物列表）
##   - 操作提示（可切换）
##
extends CanvasLayer


# ========== 节点引用 ==========
@onready var _score_label: Label = %ScoreLabel
@onready var _hp_bar: TextureProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _relic_badge: Label = %RelicBadge
@onready var _dice_label: Label = %DiceLabel
@onready var _dice_icon: TextureRect = %DiceIcon
@onready var _instructions: Label = %Instructions
@onready var _panel: Panel = %TopPanel


func _ready() -> void:
	# 订阅 EventBus 信号
	EventBus.kill_count_changed.connect(_on_kill_count_changed)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.relic_added.connect(_on_relics_changed)
	EventBus.relic_removed.connect(_on_relics_changed)
	EventBus.dice_added.connect(_on_dice_pool_changed)
	EventBus.dice_removed.connect(_on_dice_pool_changed)

	# 初始刷新
	_refresh_hp_bar(RunState.player_hp, RunState.player_max_hp)
	_refresh_coins(RunState.coins)
	_refresh_relic_badge(RunState.relics.size())

	print("✅ HUD ready")


# ========== 击杀计数 ==========
func _on_kill_count_changed(new_count: int) -> void:
	_score_label.text = "击杀: %d" % new_count


# ========== HP 条 ==========
func _on_player_hp_changed(new_hp: int, max_hp: int) -> void:
	_refresh_hp_bar(new_hp, max_hp)


func _refresh_hp_bar(hp: int, max_hp: int) -> void:
	var ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar.value = ratio * 100.0

	# 颜色渐变：绿 (>60%) → 黄 (30-60%) → 红 (<30%)
	var color: Color
	if ratio > 0.6:
		color = Color(0.2, 0.8, 0.3, 1)      # 绿
	elif ratio > 0.3:
		color = Color(0.9, 0.75, 0.2, 1)       # 黄
	else:
		color = Color(0.9, 0.2, 0.2, 1)        # 红

	_hp_bar.tint_progress = color
	_hp_label.text = "%d / %d" % [hp, max_hp]


# ========== 金币 ==========
func _on_coins_changed(new_amount: int) -> void:
	_refresh_coins(new_amount)


func _refresh_coins(amount: int) -> void:
	_coins_label.text = "💰 %d" % amount


# ========== 遗物徽章 ==========
func _on_relics_changed(_relic: RelicData) -> void:
	_refresh_relic_badge(RunState.relics.size())


func _refresh_relic_badge(count: int) -> void:
	if count > 0:
		_relic_badge.text = "📿 %d" % count
		_relic_badge.visible = true
	else:
		_relic_badge.visible = false


# ========== 骰子快捷信息 ==========
func _on_dice_pool_changed(_dice: DiceData) -> void:
	pass  # 骰子信息每帧更新见 _process


func _process(_delta: float) -> void:
	_update_dice_quick_info()


## 更新骰子快捷信息（显示当前激活骰子 + 冷却）
func _update_dice_quick_info() -> void:
	var player_nodes := get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		return

	var player: Node2D = player_nodes[0] as Node2D
	if player == null:
		return

	if not "dice_slots" in player:
		return

	var dice_slots: Array = player.get("dice_slots")
	var active_idx: int = player.get("active_dice_index") if "active_dice_index" in player else 0

	if dice_slots.is_empty() or active_idx >= dice_slots.size():
		_dice_label.text = "🎲 无骰子"
		if _dice_icon != null:
			_dice_icon.texture = null
		return

	var dice_node: Node2D = dice_slots[active_idx]
	if dice_node == null or not is_instance_valid(dice_node):
		_dice_label.text = "🎲 ---"
		return

	var dice_data: DiceData = dice_node.get("dice_data")
	if dice_data == null:
		_dice_label.text = "🎲 ---"
		return

	# 用 DiceFaceRenderer 渲染当前骰子第 0 面作为图标（传入材质）
	if _dice_icon != null and not dice_data.combat_faces.is_empty():
		var face: FaceData = dice_data.combat_faces[0]
		var mat: DiceMaterial = dice_data.dice_material
		_dice_icon.texture = DiceFaceRenderer.render(mat, face)

	var cd: float = 0.0
	if dice_node.has_method("get_cooldown_remaining"):
		cd = dice_node.get_cooldown_remaining()

	var elem_icon: String = _get_element_icon(dice_data.element)
	var broken_str: String = " 💔" if dice_data.is_broken() else ""
	var cd_str: String = "就绪" if cd <= 0 else "%.1fs" % cd

	_dice_label.text = "%s%s  冷却:%s%s | [%d/%d]" % [
		dice_data.dice_name,
		elem_icon,
		cd_str,
		broken_str,
		active_idx + 1,
		dice_slots.size()
	]


func _get_element_icon(element: StringName) -> String:
	match element:
		&"fire":     return "🔥"
		&"ice":      return "❄️"
		&"thunder":  return "⚡"
		&"poison":   return "☠️"
		&"holy":     return "✨"
		&"dark":     return "🌑"
		_:           return ""


## ========== 外部兼容接口（保留，逐步迁移至 EventBus）==========

func add_kill() -> void:
	RunState.kill_count += 1
