## 玩家实体
## 继承 CharacterBody2D：Godot 专门用于角色移动的节点类型，
## 内置 velocity 速度和 move_and_slide() 碰撞滑动方法。
##
## 挂载节点：scenes/entities/Player.tscn
## 依赖组件（子节点）：
##   $HealthComponent  — HP 管理（血量组件模式）
##   $AnimatedSprite2D — 玩家角色精灵动画
##   $Label / $HpLabel  — UI 标签
## 对应旧文件：scripts/Player.gd
## 迁移要点：
##   - HP 管理 → HealthComponent（从直接操作 hp 变量改为调用组件方法）
##   - 骰子投掷 → DiceEntity 发出 FaceData（不再从滚动点面获取）
##   - 受到伤害 → 通过 EventBus 订阅（后续）
##
extends CharacterBody2D                      # CharacterBody2D：内置 velocity/move_and_slide 的角色节点


const DiceEntityScene = preload("res://scenes/entities/Dice.tscn") # preload：编译期加载资源，避免运行时路径查找


## @onready：等价于在 _ready() 中写 _sprite = $AnimatedSprite2D as AnimatedSprite2D
## 使用 @onready 更简洁，且确保在 _ready() 之后节点引用才可用
## $AnimatedSprite2D：$ 是 get_node() 的简写，查找当前节点下名为 "AnimatedSprite2D" 的子节点
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _label: Label = $Label
@onready var _hp_label: Label = $HpLabel
## 组件引用（通过 @onready 获取子节点，方便后续调用组件方法）
@onready var _health: HealthComponent = $HealthComponent
## 骰子投射物特效节点（兄弟节点，在 Main.tscn 中）
@onready var _dice_fx: DiceProjectileFX = $"../DiceProjectileFX"
## 穿透子弹场景（枪手角色专属）
const BULLET_SCENE: PackedScene = preload("res://scenes/effects/bullet.tscn")
## 主摄像机（兄弟节点，在 Main.tscn 中）— 用于屏幕震动
@onready var _camera: Camera2D = $"../Camera2D"

var dice_slots: Array[Node2D] = []           # 骰子槽位：存储玩家持有的骰子节点列表
var active_dice_index: int = 0               # 当前激活的骰子索引（按 Q 键切换）


func _ready() -> void:                        # 节点进入场景树时调用一次
	add_to_group("player")                    # add_to_group：将节点加入 "player" 组，方便全局查找
	_spawn_starting_dice()                    # 生成初始骰子
	_update_labels()                          # 更新 HP/骰子信息标签
	## 信号向上通信：组件通过 signal 通知玩家，玩家连接信号并响应
	## HealthComponent 不需要知道父节点是 Player，发射信号即可
	_health.died.connect(_on_died)            # connect()：连接信号到回调方法
	_health.damaged.connect(_on_damaged)      # 连接受伤瞬间信号（触发闪红特效）
	print("✅ Player _ready 完成，骰子数: %d" % dice_slots.size()) # print 调试输出


## _physics_process(delta)：与物理帧同步（默认60fps），用于角色移动
## _delta 前缀下划线：表示参数未使用（GDScript 约定，避免编辑器警告）
func _physics_process(_delta: float) -> void:
	var input_dir: Vector2 = _get_input_dir() # 获取 WASD/方向键输入方向向量
	if input_dir.length() > 0:                # length()：判断向量长度，> 0 表示有输入
		velocity = input_dir.normalized() * Constants.PLAYER_MOVE_SPEED # normalized() 将斜向归一化，避免斜走更快；乘以速度常量
		_update_walk_animation(input_dir)     # 根据移动方向切换走路动画
	else:
		velocity = Vector2.ZERO               # 无输入时速度为 0
		if _sprite and _sprite.animation != "idle":
			_sprite.play("idle")              # 播放待机动画
	move_and_slide()                          # CharacterBody2D 专用移动方法：
											  # 自动处理碰撞滑动（沿墙壁滑行而非卡住）
											  # 将 velocity 重置为 0，返回移动后的位置增量


## 根据输入方向更新行走动画方向
func _update_walk_animation(dir: Vector2) -> void:
	if _sprite == null:                       # 防御性检查：精灵引用可能为空
		return
	if abs(dir.x) >= abs(dir.y):              # X 轴移动量 >= Y 轴 → 优先左右方向
		if dir.x < 0:
			_sprite.play("walk_left")         # play()：播放精灵动画
		else:
			_sprite.play("walk_right")
	else:                                     # Y 轴移动量 > X 轴 → 上下方向
		if dir.y < 0:
			_sprite.play("walk_up")
		else:
			_sprite.play("walk_down")


## _process(delta)：与渲染帧同步（可能是60fps~144fps不等），用于非物理逻辑
## 骰子自动滚动（DiceEntity 内部管理冷却），这里只需更新 UI 标签
func _process(_delta: float) -> void:
	_update_labels()                          # 每帧更新 HP/骰子标签


## 获取键盘输入方向（WASD / 方向键 双套方案）
func _get_input_dir() -> Vector2:
	var dir: Vector2 = Vector2.ZERO            # Vector2.ZERO：(0, 0)
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1                            # 左方向
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1                            # 右方向
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1                            # 上方向（Godot 中 Y 轴向下为正，所以减）
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1                            # 下方向
	return dir


## 骰子投掷结果处理 — 根据骰子 attack_type 分派结算逻辑
## dice 参数由 bind() 传入，指向实际投掷的骰子节点（非活跃骰子）
##
## 架构说明：
##   - DiceProjectileFX（_dice_fx）：视觉演绎层，播放骰子飞行动画
##   - AttackEffect：伤害计算层，计算最终伤害值
##   - 两者结合：用 DiceProjectileFX.play() 播放动画，在命中回调里用 AttackEffect 计算伤害
func _on_dice_rolled(face: FaceData, is_crit: bool, dice: Node) -> void:
	if face == null:
		return
	var dice_data: DiceData = dice.get("dice_data") as DiceData
	if dice_data == null:
		return

	## 根据 attack_type 分派（保留原来的 DiceProjectileFX 视觉演绎）
	match dice_data.attack_type:
		DiceData.AttackType.AOE_IMPACT:
			_resolve_aoe_impact(face, is_crit, dice_data)
		DiceData.AttackType.PENETRATING_BULLET:
			_resolve_penetrating_bullet(face, dice_data)
		_:  # SINGLE_TARGET / 默认
			_resolve_single_target(face, is_crit, dice_data)


## 查找距离玩家最近的敌人
func _find_nearest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e: Node in enemies:
		var e2d: Node2D = e as Node2D
		if e2d == null:
			continue
		var dist: float = global_position.distance_to(e2d.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = e2d
	return nearest


## 查找指定半径内的所有敌人（用于 AOE 骰子）
func _find_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var e2d: Node2D = e as Node2D
		if e2d == null:
			continue
		if center.distance_to(e2d.global_position) <= radius:
			result.append(e2d)
	return result


## ─── 单目标攻击结算（标准/火焰/冰霜等骰子）────────────────
func _resolve_single_target(face: FaceData, is_crit: bool, dice_data: DiceData) -> void:
	var enemy: Node2D = _find_nearest_enemy()
	if enemy == null:
		return
	_spawn_dice_projectile_with_payload(face, enemy, is_crit, dice_data)


## ─── AOE 范围冲击结算（山岳骰子）────────────────────────
func _resolve_aoe_impact(face: FaceData, is_crit: bool, dice_data: DiceData) -> void:
	var enemy: Node2D = _find_nearest_enemy()
	if enemy == null:
		return

	if _dice_fx == null:
		# 降级：无特效节点时直接 AOE 结算
		for e in _find_enemies_in_radius(enemy.global_position, dice_data.aoe_radius):
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(face.damage, is_crit, face)
		return

	var material: DiceMaterial = dice_data.dice_material
	var target_pos: Vector2 = enemy.global_position
	var radius: float = dice_data.aoe_radius

	# 预先计算最终伤害（用 AttackEffect if available）
	var final_dmg: int = face.damage
	var attack_effect: AttackEffect = dice_data.get_attack_effect()
	if attack_effect != null:
		final_dmg = attack_effect.calculate_damage(face.damage)
	if face.is_crit:
		final_dmg *= 2

	# 命中回调：冲击波 + 范围伤害 + hitstop + 震动
	_dice_fx.play(global_position, target_pos, face, material, func():
		# 1. 冲击波视觉
		DiceProjectileFX.show_impact_ring(target_pos, radius)
		# 2. 更大的 hitstop
		_apply_hitstop(0.06, 0.1)
		# 3. 更强的屏幕震动
		_screen_shake(8.0, 0.12)
		# 4. 范围伤害（每个半径内的敌人都受伤）
		for e in _find_enemies_in_radius(target_pos, radius):
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(final_dmg, is_crit, face)
				_show_damage_number(e.global_position, final_dmg, is_crit)
	)


## 穿透子弹结算（枪手角色专属）
## 1点：无限穿透 + 伤害×1.5 + 金色拖尾
## 2~3点：不穿透
## 4~6点：穿透1个额外敌人
func _resolve_penetrating_bullet(face: FaceData, dice_data: DiceData) -> void:
	var enemy: Node2D = _find_nearest_enemy()
	if enemy == null:
		return

	var pen_result: Array = Bullet.calc_penetration(face.value)
	var penetration: int = pen_result[0] as int
	var damage_mult: float = pen_result[1] as float

	var direction: Vector2 = (enemy.global_position - global_position).normalized()
	if direction.length() == 0:
		direction = Vector2.RIGHT

	## 计算最终伤害（使用 AttackEffect  if available）
	var final_damage: int = face.damage
	var attack_effect: AttackEffect = dice_data.get_attack_effect()
	if attack_effect != null:
		final_damage = attack_effect.calculate_damage(face.damage)
	if face.is_crit:
		final_damage *= 2

	## setup() 必须在 add_child 前调用（_ready() 依赖这些值设置光效）
	var bullet: Bullet = BULLET_SCENE.instantiate() as Bullet
	bullet.setup(direction, final_damage, face, penetration, damage_mult, attack_effect if attack_effect is ProjectileEffect else null)
	bullet.global_position = global_position + direction * 20.0
	get_tree().current_scene.add_child(bullet)

	if _sprite:
		_sprite.play("attack")

	_apply_hitstop(0.03, 0.2)
	_screen_shake(2.0, 0.05)


## 显示伤害数字（浮起并渐隐消失）
func _show_damage_number(pos: Vector2, dmg: int, is_crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = ("💥 " if is_crit else "") + str(dmg)
	lbl.add_theme_color_override("font_color", Color.YELLOW if is_crit else Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 32 if is_crit else 22)
	lbl.modulate.a = 0.0

	## 挂到场景根节点，用全局坐标定位
	var scene_root: Node = get_tree().current_scene
	if scene_root != null:
		scene_root.add_child(lbl)
		lbl.global_position = pos + Vector2(randf_range(-20, 20), -30)
	else:
		add_child(lbl)
		lbl.global_position = pos + Vector2(randf_range(-20, 20), -30)

	## 在 lbl 自身上创建 Tween，确保 lbl 入树后 Tween 能正常执行
	var tween := lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.1)
	tween.tween_property(lbl, "global_position:y", lbl.global_position.y - 60, 0.6)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4)
	tween.tween_callback(lbl.queue_free)


## 发射骰子投射物 — 伤害结算在命中时触发（业界标准攻击时序）
func _spawn_dice_projectile_with_payload(face: FaceData, enemy: Node2D, is_crit: bool, dice_data: DiceData) -> void:
	if _dice_fx == null:
		# 降级：无特效节点时直接结算
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var dmg: int = face.damage
			var effect: AttackEffect = dice_data.get_attack_effect()
			if effect != null:
				dmg = effect.calculate_damage(face.damage)
			if face.is_crit:
				dmg *= 2
			enemy.take_damage(dmg, is_crit, face)
		return

	var material: DiceMaterial = dice_data.dice_material
	var target_pos: Vector2 = enemy.global_position

	# 预先计算最终伤害（用 AttackEffect if available）
	var final_dmg: int = face.damage
	var attack_effect: AttackEffect = dice_data.get_attack_effect()
	if attack_effect != null:
		final_dmg = attack_effect.calculate_damage(face.damage)
	if face.is_crit:
		final_dmg *= 2

	# 命中回调：所有伤害结算 + 反馈效果在同一帧触发
	_dice_fx.play(global_position, target_pos, face, material, func():
		# 1. Hitstop 停帧 — 放大打击感
		_apply_hitstop(0.04, 0.15)
		# 2. 屏幕微震
		_screen_shake(3.0, 0.06)
		# 3. 结算伤害（is_instance_valid 防御：飞行期间敌人可能已被其他骰子杀死）
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(final_dmg, is_crit, face)
		# 4. 弹出伤害数字（用捕获的 target_pos，即使敌人已死也显示在命中位置）
		_show_damage_number(target_pos, final_dmg, is_crit)
		# 5. 应用元素效果（if available）
		if is_instance_valid(enemy) and attack_effect is ProjectileEffect:
			var status_comp = enemy.get_node_or_null("StatusComponent")
			if status_comp != null:
				# 火焰效果：点燃
				if attack_effect.burn_duration > 0.0:
					status_comp.apply_burn(attack_effect.burn_duration, attack_effect.burn_tick_interval, attack_effect.burn_damage)
				# 冰霜效果：减速 + 冰冻
				if attack_effect.freeze_chance > 0.0:
					status_comp.apply_slow(attack_effect.slow_duration, attack_effect.slow_factor)
					status_comp.apply_freeze(attack_effect.freeze_duration, attack_effect.freeze_chance)
	)


## Hitstop 停帧 — 命中瞬间时间减速，放大打击感
## real_seconds: 真实世界停顿时长（秒），不受 time_scale 影响
## time_scale: 减速比例（0.15 = 画面减速到15%速度）
func _apply_hitstop(real_seconds: float = 0.04, time_scale: float = 0.15) -> void:
	Engine.time_scale = time_scale
	get_tree().create_timer(real_seconds, false, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0,
		CONNECT_ONE_SHOT
	)


## 屏幕震动 — 随机抖动 Camera2D offset
func _screen_shake(intensity: float = 3.0, duration: float = 0.08) -> void:
	if _camera == null:
		return
	var tw := create_tween()
	tw.set_loops(4)  # 来回抖动 4 次
	tw.tween_method(
		func(v: float): _camera.offset = Vector2(randf_range(-v, v), randf_range(-v, v)),
		intensity,
		0.0,
		duration
	)


## 玩家受到伤害（由敌人 ContactDamage/_on_body_entered 调用）
func take_damage(dmg: int, _is_crit: bool = false) -> void:
	_health.take_damage(dmg, _is_crit)        # 委托给 HealthComponent 处理（组件模式）


## 受伤瞬间回调（HealthComponent.damaged 信号触发）
func _on_damaged(dmg: int, _is_crit: bool) -> void:
	## 弹出伤害数字（显示在玩家位置上方）
	_show_damage_number(global_position, dmg, _is_crit)

	## 受伤闪烁：将精灵调色为红色，短暂延迟后恢复
	if _sprite:
		_sprite.modulate = Color.RED          # modulate：颜色调制，此处设为纯红
		## await get_tree().create_timer(secs).timeout：
		## 创建一个一次性 Timer，await 等待其 timeout 信号
		## 实现协程式延迟（不阻塞主线程/不卡帧），0.06秒后恢复颜色
		await get_tree().create_timer(0.06).timeout
		if _sprite:                           # 防御性检查：等待期间 _sprite 可能被释放
			_sprite.modulate = Color(1, 1, 1, 1) # 恢复原始颜色


## 死亡回调（HealthComponent.died 信号触发）
func _on_died() -> void:
	print("💀 玩家阵亡！")
	set_physics_process(false)
	EventBus.player_died.emit()
	# 通过 GameManager 进入结算流程（短暂延迟后跳转主菜单）
	await get_tree().create_timer(1.5).timeout
	GameManager.transition_to(GameManager.Phase.GAME_OVER)


## 切换骰子（Q 键触发）
func cycle_dice() -> void:
	if RunState.dice_pool.is_empty():         # RunState：全局运行状态，dice_pool 是骰子数据池
		return
	## 简单的骰子切换：销毁旧骰子，用骰子池第一个数据创建新骰子
	## TODO M2：改为 UI 选择骰子（当前临时实现）
	var new_data: DiceData = RunState.dice_pool[0] # 临时：始终用骰子池第一个

	## 销毁所有旧骰子
	for d in dice_slots:
		if is_instance_valid(d):              # is_instance_valid：安全检查，避免操作已释放的骰子
			d.queue_free()                    # queue_free()：安全删除（推迟到帧末），
											  # 避免在循环中 free() 导致数组索引错乱
	dice_slots.clear()                        # Array.clear()：清空数组

	## 创建新骰子实例
	var dice: Node2D = DiceEntityScene.instantiate() # instantiate()：从预加载的场景创建实例
	dice.position = Vector2(0, -80)           # 骰子显示在玩家头顶
	add_child(dice)                           # 先 add_child，触发 _ready() 初始化 @onready 变量
	if dice.has_method("setup"):              # has_method 泛型检查
		dice.setup(new_data, self)            # 传递骰子数据和 owner（玩家自己）
	## has_signal("signal_name")：运行时检查是否有指定信号
	if dice.has_signal("rolled"):
		dice.rolled.connect(_on_dice_rolled.bind(dice))  # 连接骰子投掷信号
	dice_slots.append(dice)
	print("🔄 切换骰子 → %s" % new_data.dice_name)


## 游戏开始时生成初始骰子（在 _ready 中调用）
func _spawn_starting_dice() -> void:
	print("🎲 _spawn_starting_dice 开始")
	var dice: Node2D = DiceEntityScene.instantiate()
	dice.position = Vector2(0, -80)
	add_child(dice)
	var data: DiceData = DiceManager.get_standard_d6()
	print("🎲 骰子数据：%s，面数：%d" % [data.dice_name, data.combat_faces.size()])
	if dice.has_method("setup"):
		dice.setup(data, self)
	if dice.has_signal("rolled"):
		dice.rolled.connect(_on_dice_rolled.bind(dice))
	dice_slots.append(dice)
	print("🎲 骰子生成完毕，dice_slots 数量：%d" % dice_slots.size())


## 给玩家添加一颗新骰子（升级选择/拾取时调用）
func add_dice(data: DiceData) -> void:
	print("🎲 add_dice: %s（当前骰子数：%d）" % [data.dice_name, dice_slots.size()])
	var dice: Node2D = DiceEntityScene.instantiate()
	dice_slots.append(dice)
	add_child(dice)
	if dice.has_method("setup"):
		dice.setup(data, self)
	if dice.has_signal("rolled"):
		dice.rolled.connect(_on_dice_rolled.bind(dice))
	# 重新排布所有骰子位置（对称排列）
	_rearrange_dice_positions()
	print("🎲 骰子添加完毕，dice_slots 数量：%d" % dice_slots.size())


## 将所有骰子排列在玩家头顶，支持多行换行
## 布局规则（与升级 UI 一致）：
##   - 1~4 个骰子：单行居中
##   - 5 个以上：双行，上行 floor(N/2) 个，下行 N-floor(N/2) 个
## 每行内部居中对齐，行间距 28px
func _rearrange_dice_positions() -> void:
	var count: int = dice_slots.size()
	if count == 0:
		return

	# 决定行数和每行骰子数
	# 规则：<=4 单行，>=5 双行
	# 双行时上行 = floor(N/2)，下行 = N - 上行
	var is_double_row: bool = count >= 5
	var top_count: int = count / 2  # int 除法自动 floor：5→2, 6→3, 7→3, 8→4, 9→4

	# 构建行列表：每个元素是该行的骰子索引列表
	var rows: Array[Array] = []
	if not is_double_row:
		# 单行：所有骰子在同一行
		var row: Array[int] = []
		for i in range(count):
			row.append(i)
		rows.append(row)
	else:
		# 双行：上行 + 下行
		var top_row: Array[int] = []
		var bottom_row: Array[int] = []
		for i in range(top_count):
			top_row.append(i)
		for i in range(top_count, count):
			bottom_row.append(i)
		rows.append(top_row)
		rows.append(bottom_row)

	# 行间距（垂直方向）
	var row_spacing: float = 28.0
	# 骰子水平间距
	var spacing: float = 22.0
	# 基准 Y 坐标（第一行骰子的 Y，向下递增）
	# 双行时：第一行在 y=-80，第二行在 y=-80+row_spacing
	# 单行时：所有骰子都在 y=-80
	var base_y: float = -80.0

	for row_idx in range(rows.size()):
		var row: Array[int] = rows[row_idx]
		var row_count: int = row.size()
		# 该行起始 X（居中排列）
		var start_x: float = -(row_count - 1) * spacing * 0.5
		# 该行 Y 坐标（第一行在 base_y，后续行往下偏移）
		var row_y: float = base_y + row_idx * row_spacing

		for col_idx in range(row_count):
			var dice_idx: int = row[col_idx]
			var dice: Node2D = dice_slots[dice_idx]
			if dice != null:
				dice.position.x = start_x + col_idx * spacing
				dice.position.y = row_y


## 更新 UI 标签（每帧调用）
func _update_labels() -> void:
	if _label == null or _hp_label == null:   # 防御性检查
		return
	_hp_label.text = "HP: %d / %d" % [_health.current_hp, _health.max_hp] # % 格式化字符串
	if dice_slots.size() > active_dice_index: # 确保激活索引在数组范围内
		var d: DiceData = dice_slots[active_dice_index].get("dice_data") # get()：通过属性名字符串获取值
		if d != null:
			var cd: float = 0.0
			## has_method 泛型回调：检查 get_cooldown_remaining 方法是否存在
			if dice_slots[active_dice_index].has_method("get_cooldown_remaining"):
				cd = dice_slots[active_dice_index].get_cooldown_remaining()
			var broken_str: String = "是" if d.is_broken() else "否"
			_label.text = "🎲 %s  CD:%.1fs  破:%s" % [d.dice_name, cd, broken_str] # %.1f 格式化 cooldown
		else:
			_label.text = "👤 玩家（无骰子）"
