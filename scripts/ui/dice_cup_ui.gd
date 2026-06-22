## 骰盅赌斗 UI 控制器（DiceCupUI）
##
## 所有动画通过 Tween 驱动，不依赖 AnimationPlayer。
## 监听 DiceCupDuel 信号，不持有游戏逻辑。
##
class_name DiceCupUI
extends Control

## ─── 节点引用 ────────────────────────────────────────────────
@onready var dice_table: Control = $"../DiceTable"
@onready var player_cup: TextureRect = $"../DiceTable/PlayerCup"
@onready var npc_cup: TextureRect = $"../DiceTable/NpcCup"
@onready var player_dice: TextureRect = $"../DiceTable/PlayerDice"
@onready var npc_dice: TextureRect = $"../DiceTable/NpcDice"
@onready var hint_label: Label = $HintLabel
@onready var debug_hint: Label = $DebugHint
@onready var result_popup: Control = $ResultPopup
@onready var result_title: Label = $ResultPopup/TitleLabel
@onready var result_detail: Label = $ResultPopup/DetailLabel
@onready var dice_cup_duel: DiceCupDuel = $"../DiceCupDuel"

## 结果弹窗自动关闭延迟（秒）
@export var popup_auto_close_delay: float = 3.0
## 摇晃幅度（像素）
@export var shake_amplitude: float = 8.0
## 摇晃速度（次/秒）
@export var shake_speed: float = 12.0

## ─── 着色器材质引用 ──────────────────────────────────────────
var _shake_mat: ShaderMaterial
var _npc_shake_mat: ShaderMaterial
var _player_dice_mat: ShaderMaterial
var _npc_dice_mat: ShaderMaterial

## ─── 运行时状态 ─────────────────────────────────────────────
var _shake_tween: Tween = null
var _player_cup_origin: Vector2
var _npc_cup_origin: Vector2


func _ready() -> void:
	player_cup.hide()
	npc_cup.hide()
	player_dice.hide()
	npc_dice.hide()
	result_popup.hide()
	hint_label.hide()

	## 记录初始位置
	_player_cup_origin = player_cup.position
	_npc_cup_origin = npc_cup.position

	## 缓存着色器材质
	_shake_mat = player_cup.material as ShaderMaterial
	_npc_shake_mat = npc_cup.material as ShaderMaterial
	var mat := player_dice.material as ShaderMaterial
	if mat:
		_player_dice_mat = mat.duplicate() as ShaderMaterial
		player_dice.material = _player_dice_mat
	mat = npc_dice.material as ShaderMaterial
	if mat:
		_npc_dice_mat = mat.duplicate() as ShaderMaterial
		npc_dice.material = _npc_dice_mat

	## 连接 DiceCupDuel 信号
	dice_cup_duel.reveal_started.connect(_on_reveal_started)
	dice_cup_duel.player_cup_revealed.connect(_on_player_cup_revealed)
	dice_cup_duel.npc_cup_revealed.connect(_on_npc_cup_revealed)
	dice_cup_duel.duel_result_ready.connect(_on_duel_result_ready)


## ═══════════════════════════════════════════════════════════════
##  DiceCupDuel 信号响应
## ═══════════════════════════════════════════════════════════════

func _on_reveal_started() -> void:
	hint_label.hide()
	debug_hint.hide()


func _on_player_cup_revealed(value: int) -> void:
	_open_cup(player_cup, player_dice, value, _player_dice_mat)


func _on_npc_cup_revealed(value: int) -> void:
	_open_cup(npc_cup, npc_dice, value, _npc_dice_mat)


func _on_duel_result_ready(player_val: int, npc_val: int, player_won: bool) -> void:
	await get_tree().create_timer(0.5).timeout
	_show_result_popup(player_val, npc_val, player_won)


## ═══════════════════════════════════════════════════════════════
##  外部调用（由 DiceCupDuel 状态机驱动）
## ═══════════════════════════════════════════════════════════════

## 游戏开始：两个骰盅淡入
func on_game_started() -> void:
	player_cup.show()
	player_cup.position = _player_cup_origin + Vector2(0, -40)
	player_cup.modulate.a = 0.0
	npc_cup.show()
	npc_cup.position = _npc_cup_origin + Vector2(0, -40)
	npc_cup.modulate.a = 0.0
	player_dice.hide()
	npc_dice.hide()
	result_popup.hide()

	## 两个骰盅同步落下淡入
	var tw := create_tween().set_parallel(true)
	for cup in [player_cup, npc_cup]:
		tw.tween_property(cup, "modulate:a", 1.0, 0.3)
		tw.tween_property(cup, "position:y", cup.position.y + 40, 0.3)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	await tw.finished
	debug_hint.show()


## 开始摇晃：循环左右震荡 + 着色器模糊
func play_shake() -> void:
	## 开启着色器运动模糊
	if _shake_mat:
		_shake_mat.set_shader_parameter("shake_intensity", 0.4)
	if _npc_shake_mat:
		_npc_shake_mat.set_shader_parameter("shake_intensity", 0.4)

	## 玩家骰盅循环震荡
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.set_loops()  # 无限循环
	var dt := 1.0 / shake_speed
	_shake_tween.tween_property(player_cup, "position:x",
		_player_cup_origin.x - shake_amplitude, dt * 0.5)
	_shake_tween.tween_property(player_cup, "position:x",
		_player_cup_origin.x + shake_amplitude, dt)
	_shake_tween.tween_property(player_cup, "position:x",
		_player_cup_origin.x - shake_amplitude, dt)
	_shake_tween.tween_property(player_cup, "position:x",
		_player_cup_origin.x, dt * 0.5)

	## NPC 骰盅振幅小一点（它不参与交互）
	var npc_tw := create_tween().set_loops()
	npc_tw.tween_property(npc_cup, "position:x",
		_npc_cup_origin.x - 3.0, dt * 0.7)
	npc_tw.tween_property(npc_cup, "position:x",
		_npc_cup_origin.x + 3.0, dt * 1.3)
	npc_tw.tween_property(npc_cup, "position:x",
		_npc_cup_origin.x - 3.0, dt * 1.3)
	npc_tw.tween_property(npc_cup, "position:x",
		_npc_cup_origin.x, dt * 0.7)


## 停止摇晃 → 落地"啪"
func play_settle() -> void:
	## 停止震荡
	if _shake_tween:
		_shake_tween.kill()
		_shake_tween = null

	## 关着色器模糊
	if _shake_mat:
		_shake_mat.set_shader_parameter("shake_intensity", 0.0)
	if _npc_shake_mat:
		_npc_shake_mat.set_shader_parameter("shake_intensity", 0.0)

	## 落地效果：先微微抬起再砸下
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player_cup, "position:y",
		_player_cup_origin.y, 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(player_cup, "position:x",
		_player_cup_origin.x, 0.15)

	## 同时缩放回弹（"啪"的质感）
	var sc_tw := create_tween()
	sc_tw.tween_property(player_cup, "scale",
		Vector2(1.08, 0.92), 0.08)
	sc_tw.tween_property(player_cup, "scale",
		Vector2(1.0, 1.0), 0.12)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	await tw.finished

	## 显示"按 X 揭牌"提示
	hint_label.text = "按 X / 右键 打开骰盅"
	hint_label.modulate.a = 0.0
	hint_label.show()
	var hint_tw := create_tween()
	hint_tw.tween_property(hint_label, "modulate:a", 1.0, 0.3)
	## 提示呼吸闪烁
	hint_tw = create_tween().set_loops()
	hint_tw.tween_property(hint_label, "modulate:a", 0.5, 0.6)
	hint_tw.tween_property(hint_label, "modulate:a", 1.0, 0.6)


## ═══════════════════════════════════════════════════════════════
##  揭牌动画（内部）
## ═══════════════════════════════════════════════════════════════

## 单个骰盅打开 + 骰子揭晓
func _open_cup(cup: TextureRect, dice: TextureRect, value: int, dice_mat: ShaderMaterial) -> void:
	## 停止提示闪烁
	hint_label.hide()

	## 1. 骰子先以极小比例放置在杯下
	dice.scale = Vector2(0.01, 0.01)
	dice.modulate.a = 0.0
	dice.show()

	_set_dice_texture(dice, value)
	if dice_mat:
		dice_mat.set_shader_parameter("face_value", value)
		dice_mat.set_shader_parameter("flash_intensity", 1.0)

	## 2. 骰盅飞起消失
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cup, "position:y", cup.position.y - 80, 0.25)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(cup, "modulate:a", 0.0, 0.25)

	## 3. 骰子从小弹大出现（延迟一瞬，等杯飞走）
	var dice_tw := create_tween()
	dice_tw.tween_interval(0.15)
	dice_tw.tween_property(dice, "modulate:a", 1.0, 0.1)
	dice_tw.set_parallel(true)
	dice_tw.tween_property(dice, "scale", Vector2(1.3, 1.3), 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	dice_tw.tween_property(dice, "position:y", dice.position.y - 5, 0.2)
	dice_tw.chain()
	dice_tw.tween_property(dice, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_ease(Tween.EASE_IN_OUT)

	## 4. 闪光衰减
	if dice_mat:
		var flash_tw := create_tween()
		flash_tw.tween_interval(0.15)
		flash_tw.tween_method(
			func(v: float): dice_mat.set_shader_parameter("flash_intensity", v),
			1.0, 0.0, 0.6
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await dice_tw.finished


## ═══════════════════════════════════════════════════════════════
##  结果弹窗
## ═══════════════════════════════════════════════════════════════

func _show_result_popup(player_val: int, npc_val: int, player_won: bool) -> void:
	if player_won:
		result_title.text = "🎲 你赢了！"
		result_title.set("theme_override_colors/font_color", Color(0.3, 0.92, 0.3))
	else:
		result_title.text = "😞 你输了..."
		result_title.set("theme_override_colors/font_color", Color(0.92, 0.2, 0.2))

	result_detail.text = "你的点数：%d    vs    庄家点数：%d" % [player_val, npc_val]

	result_popup.scale = Vector2(0.1, 0.1)
	result_popup.modulate.a = 0.0
	result_popup.show()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(result_popup, "scale", Vector2(1.0, 1.0), 0.35)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(result_popup, "modulate:a", 1.0, 0.25)

	await get_tree().create_timer(popup_auto_close_delay).timeout
	_close_result_popup()


func _close_result_popup() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(result_popup, "scale", Vector2(0.5, 0.5), 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(result_popup, "modulate:a", 0.0, 0.2)
	await tw.finished
	result_popup.hide()
	debug_hint.show()


## ═══════════════════════════════════════════════════════════════
##  辅助
## ═══════════════════════════════════════════════════════════════

## 根据点数切换骰子纹理（1-6）
func _set_dice_texture(dice: TextureRect, value: int) -> void:
	var clamped := clampi(value, 1, 6)
	var path := "res://assets/sprites/dice_%d.png" % clamped
	var tex := load(path) as Texture2D
	if tex:
		dice.texture = tex
