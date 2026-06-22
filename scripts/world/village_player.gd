## 村庄玩家控制器（VillagePlayer）
##
## 村庄（2D 侧方视角）专用玩家：
##   - 只能左右移动（不能跳，不能上下）
##   - 靠近 NPC 显示交互提示，按 F 触发互动
##   - 走到街道最右端触发"离开村庄"
##
class_name VillagePlayer
extends CharacterBody2D

## ─── 导出配置 ────────────────────────────────────────────────
@export var move_speed: float = 120.0
@export var exit_trigger_x: float = 1200.0

## ─── 节点引用 ────────────────────────────────────────────────
@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_hint: Label = $InteractHint
@onready var collision: CollisionShape2D = $CollisionShape2D

## ─── 运行时状态 ──────────────────────────────────────────────
var _nearby_npc: VillageNPC = null
var _input_locked: bool = false
var _walk_frame: int = 0
var _walk_timer: float = 0.0
var _idle_bob_timer: float = 0.0
const WALK_FRAME_INTERVAL: float = 0.15  ## 每帧持续时间

## 行走 spritesheet（4帧 24×32，共 96×32）
var _walk_texture: Texture2D = null

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_INTERACT: StringName = &"interact"


func _ready() -> void:
	interact_hint.hide()
	add_to_group(&"village_player")
	## 预加载行走 spritesheet
	_walk_texture = load("res://assets/sprites/player_walk_sheet.png")


func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir: float = Input.get_axis(ACTION_LEFT, ACTION_RIGHT)
	velocity.x = dir * move_speed
	velocity.y = 0.0

	_update_animation(dir, delta)
	move_and_slide()
	_check_village_exit()


func _input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event.is_action_pressed(ACTION_INTERACT) and _nearby_npc != null:
		_nearby_npc.interact()
		get_viewport().set_input_as_handled()


## ─── 动画 ────────────────────────────────────────────────────
func _update_animation(dir: float, delta: float) -> void:
	if abs(dir) > 0.01:
		## 行走中：翻转朝向 + 循环帧
		sprite.flip_h = dir < 0.0

		_walk_timer += delta
		if _walk_timer >= WALK_FRAME_INTERVAL:
			_walk_timer = 0.0
			_walk_frame = (_walk_frame + 1) % 4

			## 从 spritesheet 中切出当前帧
			if _walk_texture:
				var frame_tex := AtlasTexture.new()
				frame_tex.atlas = _walk_texture
				frame_tex.region = Rect2(_walk_frame * 24, 0, 24, 32)
				sprite.texture = frame_tex

		## 行走上下弹跳
		sprite.position.y = sin(Time.get_ticks_msec() * 0.008) * 1.5
	else:
		## 空闲：恢复空闲纹理 + 呼吸弹跳
		_walk_timer = 0.0
		_walk_frame = 0
		_idle_bob_timer += delta
		sprite.position.y = sin(_idle_bob_timer * 2.0) * 1.0


## ─── 离开村庄检测 ────────────────────────────────────────────
func _check_village_exit() -> void:
	if global_position.x >= exit_trigger_x:
		_input_locked = true
		EventBus.village_exited.emit()


## ─── NPC 交互 ─────────────────────────────────────────────────
func set_nearby_npc(npc: VillageNPC) -> void:
	_nearby_npc = npc
	if npc != null:
		interact_hint.text = "按 F 与 %s 互动" % npc.npc_display_name
		interact_hint.show()
		print("[Player] 靠近 NPC: %s，显示提示" % npc.npc_display_name)
	else:
		interact_hint.hide()
		print("[Player] 离开 NPC，隐藏提示")


func lock_input(locked: bool) -> void:
	_input_locked = locked
