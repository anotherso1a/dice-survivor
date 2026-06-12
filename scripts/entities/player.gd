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
## 这里用来检测骰子冷却和更新标签显示
func _process(_delta: float) -> void:
	_try_roll_active_dice()                   # 每帧尝试投掷当前激活的骰子（如果冷却完毕）
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


## 尝试投掷当前激活的骰子（每帧调用，骰子冷却完毕后自动投掷）
func _try_roll_active_dice() -> void:
	if dice_slots.is_empty():                 # 没有骰子 → 跳过
		return
	var dice: Node2D = dice_slots[active_dice_index] # 获取当前激活骰子
	if dice == null:                          # 防御性检查
		return
	## has_method("method_name")：运行时检查对象是否有指定方法
	## 泛型回调：不依赖具体类型，只要对象有 is_ready/roll 方法就能用
	if not dice.has_method("is_ready"):       # 检查骰子是否有 is_ready() 方法
		return
	if not dice.is_ready():                   # 骰子冷却未完毕 → 跳过
		return
	if dice.has_method("roll"):               # 检查是否有 roll() 方法
		dice.roll()                           # 投掷骰子 → 发出 rolled 信号


## 骰子投掷结果处理（接收骰子的 rolled 信号发射的 FaceData）
## face：骰面数据（伤害值、元素类型、元素强度等）
## is_crit：是否暴击
func _on_dice_rolled(face: FaceData, is_crit: bool) -> void:
	if face == null:                          # 防御性检查
		return
	var enemy: Node2D = _find_nearest_enemy() # 查找最近的敌人
	if enemy == null:                         # 没有敌人 → 跳过
		return
	## has_method()：运行时类型检查，确认敌人有 take_damage 方法
	if enemy.has_method("take_damage"):
		enemy.take_damage(face.damage, is_crit, face) # 调用敌人的受伤方法（传递骰面数据）
		_show_damage_number(enemy.global_position, face.damage, is_crit) # 显示伤害数字
	## 元素效果：火 → 燃烧（由 Enemy 的 take_damage 自行处理 BurnComponent）
	## 后续在这里可以加入全局元素特效触发


## 查找距离玩家最近的敌人
func _find_nearest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies") # get_nodes_in_group：获取组内所有节点
	if enemies.is_empty():
		return null
	var nearest: Node2D = null
	var nearest_dist: float = INF              # INF：正无穷，确保第一个敌人一定被选中
	for e: Node in enemies:
		var e2d: Node2D = e as Node2D         # as 安全转换，失败返回 null 而非报错
		if e2d == null:
			continue                          # 跳过非 Node2D 节点
		var dist: float = global_position.distance_to(e2d.global_position) # distance_to()：计算两点距离
		if dist < nearest_dist:               # 找最近
			nearest_dist = dist
			nearest = e2d
	return nearest


## 显示伤害数字（浮起并渐隐消失）
func _show_damage_number(pos: Vector2, dmg: int, is_crit: bool) -> void:
	var lbl: Label = Label.new()               # Label.new()：代码动态创建 Label 节点（不依赖场景文件）
	lbl.text = ("💥 " if is_crit else "") + str(dmg) # 暴击时加爆炸图标前缀
	lbl.add_theme_color_override("font_color", Color.YELLOW if is_crit else Color.WHITE) # 暴击=黄色，普通=白色
	lbl.add_theme_font_size_override("font_size", 32 if is_crit else 22) # 暴击字体更大
	lbl.position = pos + Vector2(randf_range(-20, 20), -20) # randf_range：随机位置偏移，避免数字叠加
	get_tree().current_scene.add_child(lbl)    # current_scene：当前关卡场景根节点，add_child 添加到场景
	var tween: Tween = create_tween()          # create_tween()：创建 Tween 动画对象
	tween.tween_property(lbl, "position:y", lbl.position.y - 60, Constants.DAMAGE_NUMBER_DURATION) # 向上浮动60像素
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, Constants.DAMAGE_NUMBER_DURATION) # parallel() 并行：同时渐隐
	tween.tween_callback(lbl.queue_free)       # queue_free()：动画结束后安全删除 Label，
	                                           # 使用 queue_free() 而非 free()：推迟到帧末删除，避免 Tween 回调中访问已释放对象


## 玩家受到伤害（由敌人 ContactDamage/_on_body_entered 调用）
func take_damage(dmg: int, _is_crit: bool = false) -> void:
	_health.take_damage(dmg, _is_crit)        # 委托给 HealthComponent 处理（组件模式）


## 受伤瞬间回调（HealthComponent.damaged 信号触发）
func _on_damaged(_dmg: int, _is_crit: bool) -> void:
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
		dice.rolled.connect(_on_dice_rolled)  # 连接骰子投掷信号
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
		dice.rolled.connect(_on_dice_rolled)
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
		dice.rolled.connect(_on_dice_rolled)
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
