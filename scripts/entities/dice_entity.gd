## 骰子实体（场景中的骰子实例）
## 继承 Node2D：骰子是 2D 空间中的可见节点（需要位置/旋转）。
##
## 挂载在玩家节点下（作为子节点），跟随玩家移动。
## 职责：冷却管理 + 动画状态机 + 投掷逻辑 + 发出骰面数据。
## 动画状态机：IDLE → SPINNING（CD中旋转）→ SHOWING_FACE（展示面0.2s）→ 回到 SPINNING
##
## 你需要准备的动画资源（在检查器中配置）：
##   1. 骰子旋转动画：在 AnimatedSprite2D 中新建一个名为 "spin" 的动画
##      （或者用代码驱动旋转，见 _process 中的 _spin_speed 实现）
##   2. 6个面的展示帧：在 AnimatedSprite2D 的 SpriteFrames 中，
##      确保帧的排列顺序与 face_index（0~5）对应。
##      或者：为每个面新建独立动画 "face_0"、"face_1"…"face_5"
##
extends Node2D

## 动画状态枚举（状态机）
enum AnimState { IDLE, SPINNING, SHOWING_FACE }

## rolled 信号：骰子投掷完成后发出，携带骰面数据和暴击标记
## 信号向上通信：骰子发出信号 → 玩家（父节点）连接并处理（如查找敌人、造成伤害）
signal rolled(face_data: FaceData, is_crit: bool)
signal cooldown_ready()                      # 冷却完毕信号（可用于 UI 提示）
signal broken()                              # 骰子损坏信号（耐久度归零）


## ========== 子节点引用 ==========

## @onready：等价于 _ready() 中获取子节点引用，确保子节点就绪后才赋值
@onready var _visual: Node2D = $Visual                              # 视觉根节点（缩放统一挂在这）
@onready var _sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D  # 骰子动画精灵
@onready var _cd_label: Label = $CooldownLabel                      # 冷却倒计时标签


## ========== @export 检查器配置 ==========

## 骰子旋转速度（度/秒），CD 中以此速度旋转 Visual 节点
@export var spin_speed: float = 360.0

## 展示骰面的持续时间（秒），之后自动发出 rolled 信号
@export var face_show_duration: float = 0.2

## 冷却倒计时文字的颜色
@export var cd_text_color: Color = Color.YELLOW


## ========== 运行时状态 ==========

var dice_data: DiceData:                    # 骰子数据引用（DiceData 是资源/数据类）
	set(v):                                  # setter：值被修改时自动执行
		dice_data = v                        # 执行赋值
		_update_label()                      # 自动更新标签显示

var owner_node: Node2D = null               # 骰子的拥有者（通常是 Player 节点）

var _cooldown_timer: float = 0.0           # 冷却计时器（秒），> 0 表示冷却中
var _anim_state: AnimState = AnimState.IDLE # 当前动画状态
var _face_show_timer: float = 0.0          # 展示面状态的计时器
var _pending_face: FaceData = null          # 待展示的骰面数据（展示状态期间暂存）
var _pending_is_crit: bool = false          # 待展示的暴击标记


## ========== 生命周期 ==========

## _ready()：节点进入场景树后调用，适合做一次性初始化
func _ready() -> void:
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
## data：骰子数据（DiceData）
## owner：骰子拥有者（Player 节点）
func setup(data: DiceData, owner: Node2D) -> void:
	dice_data = data                         # 绑定骰子数据（触发 setter → 更新标签）
	owner_node = owner                       # 记录拥有者引用
	_update_label()                          # 更新标签

	# 设置初始状态
	if dice_data != null and dice_data.cooldown > 0:
		_set_anim_state(AnimState.SPINNING)
	else:
		_set_anim_state(AnimState.IDLE)


## 检查骰子是否可以投掷（冷却完毕 + 未损坏）
func is_ready() -> bool:
	if dice_data == null:
		return false
	return _cooldown_timer <= 0 and _anim_state != AnimState.SHOWING_FACE


## 投掷骰子（核心逻辑，通常由玩家调用）
## 返回：随机到的骰面数据（FaceData），如果冷却中/已损坏则返回 null
func roll() -> FaceData:
	if not is_ready():                        # 冷却中 或 正在展示面 → 不能投掷
		return null
	if dice_data == null:
		return null
	if dice_data.is_broken():
		broken.emit()
		return null

	# ① 掷骰：计算随机面
	var face: FaceData = dice_data.roll_combat()
	var is_crit: bool = face != null and face.is_crit

	# ② 进入"展示面"状态（播放动画，0.2s 后发信号）
	_pending_face = face
	_pending_is_crit = is_crit
	_set_anim_state(AnimState.SHOWING_FACE)

	# ③ 检查骰子是否损坏（耐久度用完）
	if dice_data.durability > 0 and dice_data.is_broken():
		# 延迟发出 broken 信号（等展示面结束后），或者立即发
		# 这里选择立即发，让 UI 可以提前响应
		call_deferred("emit_signal", "broken")

	return face


## 获取剩余冷却时间（供 UI 显示用）
func get_cooldown_remaining() -> float:
	return _cooldown_timer


## ========== 内部方法 ==========

## 冷却计时逻辑（每帧调用）
func _tick_cooldown(delta: float) -> void:
	if _cooldown_timer <= 0:
		return

	_cooldown_timer -= delta
	if _cooldown_timer <= 0:
		_cooldown_timer = 0.0
		cooldown_ready.emit()              # 发射冷却就绪信号
		# CD 结束 → 如果当前是 IDLE，切换到 SPINNING（等待下次触发）
		if _anim_state == AnimState.IDLE:
			_set_anim_state(AnimState.SPINNING)

	_update_label()


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
	# 停止旋转，显示默认帧（如果有 AnimatedSprite2D）
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.play("idle")                # 尝试播放 idle 动画（你需要自己创建）
	# 或者：停止旋转
	_update_label()


func _passive_idle(_delta: float) -> void:
	pass                                   # IDLE 状态暂无持续逻辑


## ---------- SPINNING 状态（CD 中） ----------

func _enter_spinning() -> void:
	# 开始冷却（如果还没开始的话）
	if _cooldown_timer <= 0 and dice_data != null:
		_cooldown_timer = dice_data.cooldown

	# 播放旋转动画（如果你在 AnimatedSprite2D 里做了 "spin" 动画）
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.play("spin")               # 尝试播放 spin 动画


func _process_spinning(delta: float) -> void:
	# 用代码驱动旋转（不依赖 sprite sheet）
	# 旋转 Visual 节点（这样可以同时旋转精灵和任何附加特效）
	if _visual != null:
		_visual.rotation_degrees += spin_speed * delta

	# 如果你用 AnimatedSprite2D 的动画来代替代码旋转，上面的旋转可以去掉，
	# 只要在 spin 动画里做好了旋转关键帧即可。


## ---------- SHOWING_FACE 状态（展示掷出的面） ----------

func _enter_showing_face() -> void:
	# 停止旋转
	if _visual != null:
		_visual.rotation_degrees = 0.0

	_face_show_timer = face_show_duration

	# 播放对应面的动画/帧
	if _sprite != null and _pending_face != null:
		# 方式1（推荐）：如果 SpriteFrames 里只有一个动画（比如叫 "default"），
		# 且 6 个帧按顺序对应 6 个面（帧0=面1，帧1=面2...），
		# 直接切换帧即可：
		if _sprite.sprite_frames != null and _pending_face.face_index >= 0:
			_sprite.frame = _pending_face.face_index

		# 方式2：如果你为每个面做了独立动画 "face_0" ~ "face_5"
		# var anim_name := "face_%d" % _pending_face.face_index
		# if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim_name):
		#     _sprite.play(anim_name)

	# DEBUG：在控制台打印掷骰结果
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
