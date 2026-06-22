## 骰盅赌斗小游戏（DiceCupDuel）
##
## 流程：
##   1. 玩家长按 A / 鼠标左键 → 摇晃骰盅动画（_shake 状态）
##   2. 松开 → 骰盅放下，过渡到 _wait_reveal 状态，提示按 X / 右键
##   3. 玩家按 X / 右键 → 禁止输入，进入演绎动画
##   4. 先揭玩家骰盅（显示点数），再揭 NPC 骰盅
##   5. 比较点数 → 发出 minigame_finished 信号 → 轻量弹窗告知结果
##
## 输入：
##   长按 A / 鼠标左键  → 摇晃
##   松开               → 放下
##   X / 鼠标右键       → 揭牌（仅在 wait_reveal 状态有效）
##   ESC / B            → 退出（由父场景/村庄层处理，调用 force_end()）
##
class_name DiceCupDuel
extends MinigameBase

## 揭牌演绎完成信号（供 UI 层接收，驱动动画）
signal reveal_started
signal player_cup_revealed(value: int)
signal npc_cup_revealed(value: int)
signal duel_result_ready(player_val: int, npc_val: int, player_won: bool)

## ─── 状态枚举 ───────────────────────────────────────────────
enum State {
	IDLE,          ## 待机，等待玩家长按
	SHAKING,       ## 摇晃中（长按输入激活）
	SETTLING,      ## 放下的落地过渡（短暂，播放"啪"动画）
	WAIT_REVEAL,   ## 等待玩家按 X / 右键揭牌
	REVEALING,     ## 演绎动画进行中（禁止输入）
	DONE,          ## 已结束
}

## ─── 配置参数 ───────────────────────────────────────────────
## 最短摇晃时间（秒）：未满此时间松手不算已摇好
@export var min_shake_duration: float = 0.5
## 落地过渡时长（秒）
@export var settle_duration: float = 0.4
## 揭牌动画每步延迟（秒）
@export var reveal_step_delay: float = 0.8
## 奖励金币基础值
@export var base_reward_coins: int = 30

## ─── 运行时状态 ─────────────────────────────────────────────
var _state: State = State.IDLE
var _player_value: int = 0
var _npc_value: int = 0
var _bet: int = 0
var _shake_timer: float = 0.0
var _is_input_locked: bool = false

## 手柄/键盘 摇晃动作名（project settings 中定义）
const ACTION_SHAKE: StringName = &"ui_accept"      ## A 键 / Enter
const ACTION_REVEAL: StringName = &"dice_cup_reveal"  ## X 键（需在 InputMap 注册）

## ─── UI 引用（兄弟节点）──────────────────────────────────────
@onready var _ui: DiceCupUI = $"../DiceCupUI"


## 检测是否以独立场景运行（F6）
## 独立运行时 current_scene 就是本场景的根节点（DiceCupDuelRoot）
func _is_running_standalone() -> bool:
	var cs = get_tree().current_scene
	if cs == null:
		return false
	## 方式1：检查场景文件路径是否完全匹配
	if cs.scene_file_path == "res://scenes/minigames/dice_cup_duel.tscn":
		return true
	## 方式2：检查当前场景的根节点是否就是我们的父节点 DiceCupDuelRoot
	var parent := get_parent()
	if parent != null:
		return parent == cs or parent.get_parent() == cs
	return false


func _ready() -> void:
	set_process_input(true)
	## DEBUG：F6 独立运行时自启动，正式集成时删掉下面这段
	## 修正：current_scene 是场景根节点 DiceCupDuelRoot，不是 DiceCupDuel 本身
	if not Engine.is_editor_hint():
		await get_tree().process_frame
		## 检查当前场景是否是本场景（独立运行）还是作为子场景被加载
		var is_standalone: bool = _is_running_standalone()
		if is_standalone and _ui != null:
			start([], 50)
			print("DiceCupDuel: 调试自启动，按住鼠标左键摇晃骰盅，右键揭牌")


## ─── 公开接口（由 MinigameBase 调用）───────────────────────
func _on_start(_player_dice: Array[DiceData], bet: int) -> void:
	_bet = bet
	_state = State.IDLE
	_is_input_locked = false
	_shake_timer = 0.0
	_player_value = 0
	_npc_value = 0
	## 通知 UI 显示骰盅
	_ui.on_game_started()


## ─── 输入处理 ────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _is_input_locked or not _is_running:
		return

	## 长按摇晃（A键 或 鼠标左键）
	if event.is_action_pressed(ACTION_SHAKE) or \
	   (event is InputEventMouseButton and \
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and \
		(event as InputEventMouseButton).pressed):
		_on_shake_press()
		get_viewport().set_input_as_handled()

	elif event.is_action_released(ACTION_SHAKE) or \
		 (event is InputEventMouseButton and \
		  (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and \
		  not (event as InputEventMouseButton).pressed):
		_on_shake_release()
		get_viewport().set_input_as_handled()

	## 揭牌（X键 或 鼠标右键）
	elif _state == State.WAIT_REVEAL:
		var is_reveal: bool = event.is_action_pressed(ACTION_REVEAL) or \
			(event is InputEventMouseButton and \
			 (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and \
			 (event as InputEventMouseButton).pressed)
		if is_reveal:
			_start_reveal()
			get_viewport().set_input_as_handled()


## ─── 每帧（计时摇晃时长）────────────────────────────────────
func _process(delta: float) -> void:
	if _state == State.SHAKING:
		_shake_timer += delta


## ─── 状态机处理 ──────────────────────────────────────────────
func _on_shake_press() -> void:
	match _state:
		State.IDLE, State.WAIT_REVEAL:
			_state = State.SHAKING
			_shake_timer = 0.0
			_ui.play_shake()


func _on_shake_release() -> void:
	if _state != State.SHAKING:
		return
	if _shake_timer < min_shake_duration:
		## 摇晃时间不足，回到 IDLE，不算摇好
		_state = State.IDLE
		return

	## 摇晃够了，进入落地过渡
	_state = State.SETTLING
	_ui.play_settle()
	## 掷骰：在落地动画期间暗中计算结果
	_roll_dice()
	## 等落地动画播完再切换到 wait_reveal
	get_tree().create_timer(settle_duration).timeout.connect(_on_settle_done, CONNECT_ONE_SHOT)


func _on_settle_done() -> void:
	if _state != State.SETTLING:
		return
	_state = State.WAIT_REVEAL
	## 通知 UI 层：可以揭牌了（显示"按 X 打开骰盅"提示）


func _start_reveal() -> void:
	_state = State.REVEALING
	_is_input_locked = true
	reveal_started.emit()
	## 演绎时序（通过 Timer 串联）：
	##   T=0:       开始揭玩家骰盅动画
	##   T=delay:   发出玩家点数 → 触发揭 NPC 骰盅动画
	##   T=delay*2: 发出 NPC 点数
	##   T=delay*3: 结算胜负
	_reveal_player_cup()


func _reveal_player_cup() -> void:
	## T+delay: 发出玩家点数
	var t1: SceneTreeTimer = get_tree().create_timer(reveal_step_delay)
	t1.timeout.connect(_on_player_cup_revealed, CONNECT_ONE_SHOT)


func _on_player_cup_revealed() -> void:
	player_cup_revealed.emit(_player_value)
	## T+delay*2: 开始揭 NPC 骰盅
	var t2: SceneTreeTimer = get_tree().create_timer(reveal_step_delay)
	t2.timeout.connect(_reveal_npc_cup, CONNECT_ONE_SHOT)


func _reveal_npc_cup() -> void:
	## T+delay*2: 发出 NPC 点数
	npc_cup_revealed.emit(_npc_value)
	## T+delay*3: 结算
	var t3: SceneTreeTimer = get_tree().create_timer(reveal_step_delay)
	t3.timeout.connect(_finish_duel, CONNECT_ONE_SHOT)


func _finish_duel() -> void:
	var player_won: bool = _player_value > _npc_value
	var reward: Dictionary = _calc_reward(player_won)
	duel_result_ready.emit(_player_value, _npc_value, player_won)
	_state = State.DONE
	_is_input_locked = false
	_end_minigame(player_won, reward)


## ─── 骰子结算 ────────────────────────────────────────────────

## 暗中掷骰：从玩家骰子池的赌博面取点数，NPC 随机
func _roll_dice() -> void:
	_player_value = _roll_player_gamble_value()
	_npc_value = randi_range(1, 6)


## 从玩家骰子池里取赌博模式点数（取最高面 gamble_value）
func _roll_player_gamble_value() -> int:
	var dice_pool: Array[DiceData] = RunState.dice_pool
	if dice_pool.is_empty():
		return randi_range(1, 6)

	## 每颗骰子随机摇一次赌博面，取所有结果的最大值
	var best: int = 0
	for dice: DiceData in dice_pool:
		var face: FaceData = dice.roll_gamble()
		if face != null:
			best = max(best, face.gamble_value)
	## 防止 gamble_value 全为 0 的兜底
	return best if best > 0 else randi_range(1, 6)


## 计算奖励/惩罚
func _calc_reward(won: bool) -> Dictionary:
	if won:
		return {
			"coins": _bet + base_reward_coins,
			"hp": 0,
		}
	else:
		return {
			"coins": -_bet,
			"hp": -5,  ## 输了扣血
		}
