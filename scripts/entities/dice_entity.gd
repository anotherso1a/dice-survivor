## 骰子实体（场景中的骰子实例）
## 继承 Node2D：骰子是 2D 空间中的可见节点（需要位置/旋转）。
##
## 骰面完全由代码渲染（DiceFaceRenderer），无需美术资源。
## 每个骰面在 setup() 时一次性生成纹理，运行时切换帧只需替换 Sprite2D.texture。
##
## 职责：冷却管理 + 动画状态机 + 投掷逻辑 + 发出骰面数据。
## 动画状态机：IDLE → SPINNING（CD中旋转）→ SHOWING_FACE（展示面）→ 回到 SPINNING
##
extends Node2D

## 动画状态枚举（状态机）
enum AnimState { IDLE, SPINNING, SHOWING_FACE }

## rolled 信号：骰子投掷完成后发出，携带骰面数据和暴击标记
signal rolled(face_data: FaceData, is_crit: bool)
signal cooldown_ready()
signal broken()

## ========== 子节点引用 ==========
@onready var _visual: Node2D = $Visual
# 替代 AnimatedSprite2D：用 Sprite2D + 代码纹理
@onready var _sprite: Sprite2D = $Visual/Sprite2D
@onready var _cd_label: Label = $CooldownLabel

## ========== 运行时状态 ==========
var _dice_data_internal: DiceData  # backing field
var dice_data: DiceData:
	get:
		return _dice_data_internal
	set(v):
		_dice_data_internal = v
		_update_label()

var owner_node: Node2D = null
var _cooldown_timer: float = 0.0
var _anim_state: AnimState = AnimState.IDLE
var _face_show_timer: float = 0.0
var _pending_face: FaceData = null
var _pending_is_crit: bool = false

## 代码渲染的骰面纹理缓存（按 face_index 索引）
var _face_textures: Array[Texture2D] = []
@export var face_show_duration: float = 0.2

## 冷却倒计时文字的颜色
@export var cd_text_color: Color = Color.YELLOW

@export var spin_speed: float = 720.0
@export var spin_face_interval: float = 0.09
var _spin_face_timer: float = 0.0



## ========== 生命周期 ==========

## _ready()：节点进入场景树后调用，适合做一次性初始化
func _ready() -> void:
	print("[Dice] _ready() dice_data=%s" % dice_data)
	# 初始状态：如果有 dice_data 且有冷却时间，直接进入 SPINNING
	if dice_data != null and dice_data.cooldown > 0:
		_set_anim_state(AnimState.SPINNING)
	else:
		_set_anim_state(AnimState.IDLE)


## _process(delta)：与渲染帧同步，用于冷却计时和动画驱动
## 这里用 _process 而非 _physics_process，因为动画和冷却计时不需要物理帧同步精度
func _process(delta: float) -> void:
	if dice_data == null:
		return

	# 冷却计时：只在非展示面状态下计时（展示面期间暂停 CD）
	if _anim_state != AnimState.SHOWING_FACE:
		_tick_cooldown(delta)

	# 根据当前动画状态驱动对应逻辑
	match _anim_state:
		AnimState.IDLE:
			_passive_idle(delta)
		AnimState.SPINNING:
			_process_spinning(delta)
		AnimState.SHOWING_FACE:
			_process_showing_face(delta)


## ========== 公有方法 ==========

## 初始化骰子（由玩家在 _spawn_starting_dice 或 cycle_dice 中调用）
func setup(data: DiceData, owner: Node2D) -> void:
	print("[Dice] setup() 开始，data=%s" % data)
	dice_data = data
	owner_node = owner

	# 用 DiceFaceRenderer 预生成所有战斗面的纹理
	_generate_face_textures()

	_update_label()

	if dice_data != null and dice_data.cooldown > 0:
		_set_anim_state(AnimState.SPINNING)
	else:
		_set_anim_state(AnimState.IDLE)


## 预生成当前骰子所有战斗面的纹理（setup 时调用一次）
func _generate_face_textures() -> void:
	print("[Dice] _generate_face_textures() 开始")
	_face_textures.clear()
	if dice_data == null or dice_data.combat_faces.is_empty():
		print("[Dice] ⚠  dice_data 为空或 combat_faces 为空")
		return
	var material: DiceMaterial = dice_data.dice_material
	for i in range(dice_data.combat_faces.size()):
		var face: FaceData = dice_data.combat_faces[i]
		var tex: Texture2D = DiceFaceRenderer.render(material, face)
		if tex == null:
			print("[Dice] ⚠  面%d 渲染失败，tex=null" % i)
		else:
			print("[Dice] ✅ 面%d 渲染成功，纹理尺寸：%dx%d" % [i, tex.get_width(), tex.get_height()])
		_face_textures.append(tex)
	# 设置初始纹理（显示第 0 面）
	if _sprite != null and not _face_textures.is_empty():
		_sprite.texture = _face_textures[0]
		print("[Dice] Sprite2D.texture 已设置为面0")
	else:
		print("[Dice] ⚠  _sprite 为空或 _face_textures 为空，无法设置纹理")


## 设置动画状态（状态切换入口，统一管理进入/退出逻辑）
func _set_anim_state(new_state: AnimState) -> void:
	if _anim_state == new_state:
		return

	# 退出旧状态
	match _anim_state:
		AnimState.SHOWING_FACE:
			_face_show_timer = 0.0

	_anim_state = new_state

	# 进入新状态
	match _anim_state:
		AnimState.IDLE:
			_enter_idle()
		AnimState.SPINNING:
			_enter_spinning()
		AnimState.SHOWING_FACE:
			_enter_showing_face()


## ---------- IDLE 状态 ----------

func _enter_idle() -> void:
	# 停止旋转，显示默认第 0 面
	if _sprite != null and not _face_textures.is_empty():
		_sprite.texture = _face_textures[0]
	_update_label()


func _passive_idle(_delta: float) -> void:
	pass


## ---------- SPINNING 状态（CD 中） ----------

func _enter_spinning() -> void:
	if _cooldown_timer <= 0 and dice_data != null:
		_cooldown_timer = dice_data.cooldown
	_spin_face_timer = 0.0  # 立即切一次面


func _process_spinning(delta: float) -> void:
	if _visual != null:
		_visual.rotation_degrees += spin_speed * delta

	# rolling 过程中随机切换面（视觉特效）
	if not _face_textures.is_empty():
		_spin_face_timer -= delta
		if _spin_face_timer <= 0.0:
			var ridx: int = randi() % _face_textures.size()
			if _sprite != null and _face_textures[ridx] != null:
				_sprite.texture = _face_textures[ridx]
			_spin_face_timer = spin_face_interval


## ---------- SHOWING_FACE 状态（展示掷出的面） ----------

func _enter_showing_face() -> void:
	if _visual != null:
		_visual.rotation_degrees = 0.0

	_face_show_timer = face_show_duration

	# 用 DiceFaceRenderer 生成的纹理切换显示
	if _sprite != null and _pending_face != null:
		var idx: int = _pending_face.face_index
		if idx >= 0 and idx < _face_textures.size():
			_sprite.texture = _face_textures[idx]
		else:
			# 如果缓存里没有，实时渲染（兜底）
			if dice_data != null and dice_data.dice_material != null:
				_sprite.texture = DiceFaceRenderer.render(dice_data.dice_material, _pending_face)
			else:
				_sprite.texture = DiceFaceRenderer.render(null, _pending_face)

	print("[Dice] 掷出：面%d (%s)" % [_pending_face.face_index + 1, _pending_face.description])


func _process_showing_face(delta: float) -> void:
	_face_show_timer -= delta
	if _face_show_timer <= 0.0:
		# 展示时间到 → 发出 rolled 信号
		rolled.emit(_pending_face, _pending_is_crit)

		_pending_face = null
		_pending_is_crit = false

		# 开始下一轮 CD（展示面后才开始计时）
		if dice_data != null:
			_cooldown_timer = dice_data.cooldown
		else:
			_cooldown_timer = 0.0

		# 切换到旋转状态（如果 CD > 0 则开始旋转，否则进入 IDLE）
		if dice_data != null and dice_data.cooldown > 0:
			_set_anim_state(AnimState.SPINNING)
		else:
			_set_anim_state(AnimState.IDLE)


## ---------- UI 更新 ----------

func _update_label() -> void:
	if _cd_label == null:
		return
	if dice_data == null:
		_cd_label.text = ""
		_cd_label.visible = false
		return

	# 只在 CD 中显示倒计时
	if _cooldown_timer > 0:
		_cd_label.text = "%.1f" % _cooldown_timer
		_cd_label.visible = true
	else:
		_cd_label.visible = false


## ---------- 冷却与投掷 ----------

func _tick_cooldown(delta: float) -> void:
	"""冷却计时，CD 归零时触发投掷"""
	if _cooldown_timer <= 0.0:
		return
	_cooldown_timer -= delta
	_update_label()
	if _cooldown_timer <= 0.0:
		_cooldown_timer = 0.0
		_update_label()
		_trigger_roll()


func _trigger_roll() -> void:
	"""CD 结束，触发投掷：随机选面，进入展示状态"""
	if dice_data == null or dice_data.combat_faces.is_empty():
		return

	# TODO: 根据骰子数据选择合适的面（目前随机）
	var idx: int = randi() % dice_data.combat_faces.size()
	_pending_face = dice_data.combat_faces[idx]

	# 暴击由骰面数据决定（FaceData.is_crit），不是随机 10%
	_pending_is_crit = _pending_face.is_crit

	_set_anim_state(AnimState.SHOWING_FACE)
