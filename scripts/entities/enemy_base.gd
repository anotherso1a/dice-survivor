## 敌人基类
## 继承 CharacterBody2D：使用内置 velocity/move_and_slide 实现追踪移动。
## 设计：所有敌人类型（近战/远程/Boss）继承此基类，共享移动、受伤、死亡逻辑。
##
## 挂载节点：scenes/entities/enemies/ 下各敌人场景
## 依赖组件（场景内需挂载为子节点，通过 @onready $NodeName 引用）：
##   $HealthComponent  — HP 管理（血量组件）
##   $BurnComponent    — 燃烧 DOT（持续伤害组件）
##   $ContactDamage    — 接触伤害（碰撞伤害组件，绑定 Hitbox）
## 对应旧文件：scripts/Enemy.gd
## 迁移要点：
##   - HP 管理 → HealthComponent（从直接操作 hp 变量改为调用组件方法）
##   - 燃烧逻辑 → BurnComponent（燃烧 DOT 独立管理）
##   - 接触伤害 → ContactDamage 组件（信号驱动的碰撞伤害）
##   - take_damage() 接收 FaceData（非旧的 Dictionary）
##   - face.element/element_power 判断燃烧（非 face.get("burn")）
##
extends CharacterBody2D                      # 继承 CharacterBody2D：获得 velocity 和 move_and_slide


signal died(pos: Vector2)                    # 死亡信号（参数：死亡位置，用于生成掉落物）


## @onready var x: Type = $X：
## 等价于 _ready() 里写 x = $X as Type，但更简洁
## 确保节点引用在 _ready() 之后才可用，避免运行时路径查找失败
## $AnimatedSprite2D：$ 是 get_node() 的简写，获取子节点
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hp_bar: ProgressBar = $HpBar   # 血条（ProgressBar 控件）
@onready var _hitbox: Area2D = $Hitbox       # 攻击碰撞检测区域
@onready var _collision: CollisionShape2D = $CollisionShape2D # 物理碰撞体

## 组件引用（通过 @onready 获取子节点，使用组件模式 Composition）
## 组件模式的好处：
##   - HealthComponent 可复用：玩家和敌人都用同一个组件
##   - 组件可独立测试：修改燃烧逻辑不需改动敌人基类
##   - 可热插拔：运行时替换组件不影响基础逻辑
@onready var _health: HealthComponent = $HealthComponent
@onready var _burn: BurnComponent = $BurnComponent
@onready var _contact: ContactDamage = $ContactDamage

## 敌人配置（可在场景实例化后在 Inspector 中覆盖）
@export var move_speed: float = Constants.ENEMY_DEFAULT_SPEED    # 移动速度
@export var contact_dmg: int = Constants.ENEMY_DEFAULT_CONTACT_DMG # 接触伤害值

var _is_dying: bool = false                  # 是否正在死亡中（阻止移动/重复触发死亡）
var _is_hurt: bool = false                   # 是否正在播放受伤动画（阻止动画切换）


func _ready() -> void:                        # 节点进入场景树时调用一次
	## 配置组件初始值
	if _health:                               # 防御性检查：场景中可能未挂载 HealthComponent
		_health.max_hp = Constants.ENEMY_DEFAULT_HP # 设置最大 HP（默认值）
		_health.reset()                       # 重置为满血
		## 信号向上通信：组件通过 signal 通知父节点，父节点连接信号并响应
		## HealthComponent 不需要知道敌方类型，只需发射信号
		_health.died.connect(_on_health_died) # connect()：将 died 信号连接到死亡处理
		_health.damaged.connect(_on_health_damaged) # 连接受伤信号（更新血条）
		_hp_bar.max_value = _health.max_hp    # 设置血条最大值
		_hp_bar.value = _health.current_hp    # 设置血条当前值

	if _contact:                              # 如果挂载了接触伤害组件
		_contact.contact_damage = contact_dmg # 同步接触伤害值到组件

	add_to_group("enemies")                   # 加入 "enemies" 组，方便全局查找（如 Player 找最近敌人）

	if _sprite:
		_sprite.animation_finished.connect(_on_animation_finished) # connect()：动画播放完毕的回调


## _physics_process(delta)：与物理帧同步（默认60fps），用于敌人追踪移动
## delta：距上一物理帧的秒数，velocity 乘以速度后 move_and_slide 自动处理帧率无关移动
func _physics_process(_delta: float) -> void:
	if _is_dying:                             # 死亡中 → 不再移动
		return

	var player: Node2D = _find_player()       # 查找玩家位置
	if player == null:                        # 没有玩家 → 不追踪
		return

	var dir: Vector2 = (player.global_position - global_position).normalized() # 指向玩家的方向向量（归一化）
	velocity = dir * move_speed               # 速度 = 方向 × 速度值（单位：像素/秒）
	move_and_slide()                          # CharacterBody2D 专用移动方法：
											 # 自动处理碰撞滑动（沿墙壁滑行而不是卡住）
											 # 遇到其他 CharacterBody2D 或 StaticBody2D 时沿表面滑行

	## 受伤动画期间只更新朝向，不切换动画（防止受伤动画被 walk 覆盖）
	if _sprite and _sprite.animation != "death" and _sprite.animation != "hurt":
		if dir.x < 0:
			_sprite.flip_h = true             # flip_h：水平翻转精灵（面向左）
		elif dir.x > 0:
			_sprite.flip_h = false            # 不翻转（面向右）
		if _sprite.animation != "walk":
			_sprite.play("walk")              # play()：播放行走动画


## 受到伤害（由玩家的骰子实体调用，传递给 HealthComponent）
## dmg：伤害值
## is_crit：是否暴击
## face：骰面数据（FaceData 强类型，非旧版的 Dictionary）
func take_damage(dmg: int, is_crit: bool, face: FaceData) -> void:
	if _is_dying:                             # 已死亡 → 不再受伤
		return

	_health.take_damage(dmg, is_crit)         # 委托给 HealthComponent（组件模式）

	## 元素效果：火 → 燃烧 DOT
	## face.element == &"fire"：& 是 StringName 字面量语法，比字符串字面量性能更好
	## element_power：此次骰面的元素强度，决定添加的燃烧层数
	if face and face.element == &"fire" and face.element_power > 0:
		if _burn:                             # 如果挂载了 BurnComponent
			_burn.apply(face.element_power)   # 施加燃烧层数（由 BurnComponent 管理 DOT 逻辑）

	if _health.current_hp <= 0:               # HP 已归零 → 不再放受伤动画（直接走死亡）
		return

	## 播放受伤动画（HP > 0 时）
	if _sprite and _sprite.sprite_frames.has_animation("hurt"): # has_animation()：检查精灵帧资源中是否有指定动画
		_is_hurt = true                       # 标记受伤状态（阻止 _physics_process 切换动画）
		_sprite.play("hurt")                  # 播放受伤动画

	## 受击闪红效果（短暂的红色调制，然后恢复原色）
	if _sprite:
		_sprite.modulate = Color.RED          # modulate：颜色调制，设红色
		## await get_tree().create_timer(secs).timeout：
		## 创建一个一次性 Timer，await 等待其 timeout 信号
		## 协程式延迟：不阻塞主线程（不卡帧），0.06秒后恢复颜色
		await get_tree().create_timer(0.06).timeout
		if _sprite and not _is_dying:         # 防御性检查：等待期间可能已经死亡
			_sprite.modulate = Color(1, 1, 1, 1) # 恢复原始颜色（白色 = 无调制）


## 查找玩家（从 "player" 组获取第一个玩家节点）
func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player") # get_nodes_in_group：获取组内所有节点
	if players.is_empty():                    # 组内无节点
		return null
	return players[0] as Node2D               # as：安全类型转换，失败返回 null 而不报错


## HP 归零 → 执行死亡流程（HealthComponent.died 信号回调）
## 信号向上通信：HealthComponent 发射 died 信号，Enemy 接收并处理死亡
func _on_health_died() -> void:
	_die()


## 受伤瞬间回调（HealthComponent.damaged 信号触发）
## 用于更新血条显示
func _on_health_damaged(_dmg: int, _is_crit: bool) -> void: # _ 前缀：参数未使用
	if _hp_bar and _health:
		_hp_bar.value = _health.current_hp    # 同步 HP 组件的当前值到血条


## 死亡处理：停止移动、禁用碰撞、播放死亡动画、最终删除节点
func _die() -> void:
	_is_dying = true                          # 标记死亡（阻止 _physics_process 继续移动）
	died.emit(global_position)                # 发射死亡信号（传递死亡位置，用于生成掉落物/经验）

	velocity = Vector2.ZERO                  # 停止移动
	set_physics_process(false)                # 禁用物理帧处理（不再执行 _physics_process）

	## 死亡后隐藏 UI 和禁用碰撞
	if _hp_bar:
		_hp_bar.visible = false               # 隐藏血条
	if _collision:
		_collision.disabled = true            # 禁用物理碰撞（玩家可穿过尸体）
	if _hitbox:
		_hitbox.monitoring = false            # 关闭 Area2D 监测（停止检测接触伤害）
	if _contact:
		_contact.enabled = false              # 禁用接触伤害组件

	## 播放死亡动画
	if _sprite and _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")                 # 播放死亡动画
		## 动画播放完毕后，_on_animation_finished 会检测到 death 动画并调用 queue_free()
	else:
		queue_free()                          # queue_free()：如果没有死亡动画，直接安全删除
											  # 使用 queue_free() 而非 free()：
											  # free() 立即删除可能导致本帧后续代码访问悬空指针而崩溃
											  # queue_free() 推迟到帧末删除，安全可靠


## 动画播放完毕回调（_sprite.animation_finished 信号连接到此）
func _on_animation_finished() -> void:
	if _sprite == null:                       # 防御性检查
		return
	if _sprite.animation == "death":          # 死亡动画播完了
		queue_free()                          # queue_free()：安全删除节点（推迟到帧末）
	elif _sprite.animation == "hurt":         # 受伤动画播完了
		_is_hurt = false                      # 取消受伤标记
		if not _is_dying:                     # 如果还没死
			_sprite.play("walk")              # 恢复行走动画
