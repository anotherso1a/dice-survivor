## 接触伤害组件（可复用）— 信号驱动的碰撞伤害系统
## 设计思想：将"碰触玩家就造成伤害"的机制抽象为独立组件(Composition)，
## 任何可以碰触玩家造成伤害的实体都可以挂载此组件。
##
## 挂载方式：作为 Enemy 的子节点，自动查找兄弟节点 Hitbox（Area2D）。
## 工作原理（信号驱动，非轮询）：
##   - 监听 Hitbox.body_entered → 玩家进入范围立即造成首次伤害
##   - 监听 Hitbox.body_exited → 玩家离开后从列表中移除，停止持续伤害
##   - _physics_process 处理冷却后的持续伤害（玩家停留在范围内时定期扣血）
##   - enemy_base.gd 在敌人死亡后将 enabled = false 禁用本组件
##
class_name ContactDamage                      # 注册为全局类型
extends Node                                  # 继承 Node：组件通常继承 Node


## 有玩家被命中时发出（参数：被命中的玩家节点）
## 信号向上通信：组件不知道父节点是谁，只发射信号，由父节点决定如何处理
signal contacted(body: Node2D)


@export_group("Config")
## 每次接触对玩家造成的伤害值（在 Inspector 中可调）
@export var contact_damage: int = 3
## 是否启用本组件（敌人死亡后设为 false，停止所有接触伤害）
@export var enabled: bool = true
## 伤害冷却时间（秒），避免每帧扣血（60fps = 每秒60次伤害，无冷却会导致秒杀）
@export var damage_cooldown: float = 0.5


@export_group("Reference")
## 调试用：是否在输出窗口打印检测日志（方便排查接触伤害不生效的问题）
@export var debug: bool = false


## 内部引用：自动查找的 Hitbox（Area2D 节点）
var _hitbox: Area2D = null
## 当前停留在 Hitbox 范围内的玩家节点列表（可能有多个玩家进入范围）
var _bodies_inside: Array[Node2D] = []       # Array[Node2D]：类型化数组，确保只存 Node2D 类型
## 伤害冷却计时器（秒），> 0 时暂停持续伤害
var _cooldown_timer: float = 0.0


# ========== 生命周期 ==========

## 节点进入场景树时调用（所有子节点已就位，此时可安全查找兄弟节点）
func _ready() -> void:
	## call_deferred：推迟到 idle 帧再调用，避免节点树未完全构建导致查找失败
	## 为什么需要延迟？_ready() 执行时，父节点的子节点可能还未全部就绪
	## call_deferred 会把 _resolve_hitbox() 推迟到本帧所有 _ready() 执行完毕后调用
	call_deferred("_resolve_hitbox")


## _physics_process(delta) vs _process(delta)：
## - _physics_process：与物理帧同步（默认60fps固定间隔），用于移动、碰撞、伤害等物理逻辑
## - _process：与渲染帧同步（可能120fps或更高），用于 UI 更新等非物理逻辑
## 这里用 _physics_process 因为伤害冷却需要稳定的时间步进
## delta：距离上一物理帧的时间（秒），乘以速度或累计到计时器实现帧率无关逻辑
func _physics_process(delta: float) -> void:
	## 组件被禁用，或范围内没有玩家 → 直接返回（不执行后续循环）
	if not enabled or _bodies_inside.is_empty():
		return

	## 冷却中：扣减计时器，时间到了才允许下一次持续伤害
	if _cooldown_timer > 0:
		_cooldown_timer -= delta               # delta 递减实现帧率无关冷却计时
		return

	## 冷却结束：对范围内第一个有效的玩家造成伤害
	for body: Node2D in _bodies_inside:
		## is_instance_valid(obj)：判断对象是否已被 queue_free() 释放
		## 如果玩家死亡被 queue_free()，_bodies_inside 中可能残留无效引用
		## is_instance_valid 安全地检查对象是否仍然存活，避免访问已释放对象导致崩溃
		## body.is_in_group("player")：确认进入的是玩家组（而非其他敌人/环境体）
		## has_method("method_name")：运行时检查对象是否有指定方法
		## 这里检查 body 是否有 take_damage 方法，避免调用不存在的方法而报错
		if is_instance_valid(body) and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(contact_damage)    # 调用玩家的受伤方法（参数：伤害值）
			contacted.emit(body)                # 发射接触信号（可用于统计/特效）
			_cooldown_timer = damage_cooldown   # 重置冷却计时器
			break                               # 一次只对一个玩家造成伤害，避免同时伤害多人


# ========== 初始化 ==========

## 查找并绑定 Hitbox Area2D（通过 get_parent() 获取兄弟节点）
func _resolve_hitbox() -> void:
	## ContactDamage 和 Hitbox 都是 Enemy 的子节点，用 get_parent() 拿到父节点后查找兄弟节点
	var parent := get_parent()                 # get_parent()：获取父节点引用（此处为 Enemy）
	if parent == null:                         # 防御性检查：父节点可能已被释放
		push_warning("ContactDamage: 父节点为空，无法查找 Hitbox")
		return

	## has_node(path)：检查父节点下是否有名为 "Hitbox" 的子节点（返回 bool，不触发错误）
	if parent.has_node("Hitbox"):
		_hitbox = parent.get_node("Hitbox") as Area2D # get_node：获取指定路径的节点，as 进行类型转换

	## 找不到 Hitbox → 发警告（不影响游戏运行，只是接触伤害不生效）
	if _hitbox == null:
		push_warning("ContactDamage: 未找到 Hitbox (Area2D)，接触伤害不会生效")
		return

	## 确保 Area2D 的监测开关已打开（collision_mask 已在 .tscn 场景文件中设为 1）
	_hitbox.monitoring = true                 # monitoring 开启后 Area2D 才会检测进入/离开事件

	## 连接 Hitbox 的进出信号（只连一次，先通过 is_connected 检查是否已连接）
	## body_entered：有物理体（CharacterBody2D/RigidBody2D 等）进入 Area2D 范围时发出
	## body_exited：有物理体离开 Area2D 范围时发出
	if not _hitbox.body_entered.is_connected(_on_body_entered): # is_connected：防止重复连接导致多次回调
		_hitbox.body_entered.connect(_on_body_entered)
	if not _hitbox.body_exited.is_connected(_on_body_exited):
		_hitbox.body_exited.connect(_on_body_exited)

	if debug:
		print("✅ ContactDamage: Hitbox 已绑定，monitoring = ", _hitbox.monitoring, " collision_mask = ", _hitbox.collision_mask)


# ========== 信号回调 ==========

## 有物理体进入 Hitbox 范围时调用（Area2D.body_entered 信号的回调）
## body：进入范围的物理体节点（可能是玩家、其他敌人、环境物体等）
func _on_body_entered(body: Node2D) -> void:
	## 只处理玩家组（通过 is_in_group 判断，不依赖节点类型或节点名）
	if not body.is_in_group("player"):
		return

	## 把玩家加入"范围内"列表（用于 _physics_process 中持续伤害）
	_bodies_inside.append(body)

	## 首次接触立即造成一次伤害（不等冷却计时器）
	## has_method()：运行时检查是否存在 take_damage 方法，泛型安全回调
	if enabled and body.has_method("take_damage"):
		body.take_damage(contact_damage)       # 调用玩家的受伤方法
		contacted.emit(body)                   # 发射接触信号
		_cooldown_timer = damage_cooldown      # 开始冷却（防止连续触发）

	if debug:
		print("⚔ ContactDamage: 玩家进入范围，造成 ", contact_damage, " 点伤害")


## 有物理体离开 Hitbox 范围时调用
func _on_body_exited(body: Node2D) -> void:
	## 把玩家从"范围内"列表中移除（停止持续伤害）
	_bodies_inside.erase(body)                # Array.erase()：从数组中移除指定元素

	if debug:
		print("🚪 ContactDamage: 玩家离开范围，范围内剩余 ", _bodies_inside.size(), " 个物体")
