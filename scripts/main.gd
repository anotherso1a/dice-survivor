## 主场景控制器脚本
##
## 本脚本是游戏的入口场景（Main 场景）的核心逻辑，挂载在 Main 节点上。
## 主要职责：
##   1. 管理游戏主循环（刷怪、游戏阶段切换）
##   2. 持有对 Player、Enemies 容器、HUD 等核心节点的引用
##   3. 实现敌人随机出生算法（含警告色块预判机制）
##   4. 后续将游戏阶段逻辑委托给 GameManager 单例，本脚本只保留刷怪相关代码
##
## Node2D 说明：
##   Node2D 是 Godot 中 2D 游戏的基础节点类型，具有 position、rotation、
##   scale 等 2D 变换属性，适合作为 2D 场景的根节点。
##   与 Node 不同，Node2D 可以出现在游戏世界中，能被渲染和物理系统感知。
##
extends Node2D  # 继承 Node2D，作为 2D 主场景根节点，具备位置/变换属性


# ========== @onready 节点引用 ==========
# @onready 说明：
#   带有 @onready 的变量会在 _ready() 回调执行之前自动初始化，
#   等价于在 _ready() 里手动写 _player = get_node("Player")。
#   使用 @onready 可以避免在 _ready() 里写一堆 get_node() 调用，
#   让节点引用声明更集中、代码更清晰。
# $ 语法说明：
#   $Player 是 get_node("Player") 的语法糖，Godot 会在当前节点的子节点中
#   查找名为 "Player" 的节点并返回引用。
# : 类型注解说明（Godot 4）：
#   在变量后加 : 类型名 可以进行静态类型检查，
#   提供代码补全、类型错误提示，并提升运行时性能。
@onready var _player: Node2D = $Player  # 获取子节点 Player（玩家节点），用于获取玩家位置等信息
@onready var _enemies: Node2D = $Enemies  # 获取子节点 Enemies（敌人容器），新敌人将 add_child 到此处
@onready var _hud: CanvasLayer = $HUD  # 获取子节点 HUD（UI 层），CanvasLayer 类型确保 UI 始终在最上层
@onready var _bg: ColorRect = $BG  # 获取子节点 BG（背景色块），ColorRect 用于绘制纯色背景


# ========== 刷怪相关常量 ==========
# 敌人生成位置距视口边缘的内缩距离
# 防止敌人出生在屏幕最边缘，给玩家反应时间
const SPAWN_MARGIN: float = 60.0  # 出生点距视口四边的内缩距离（像素）
# 出现警告色块到敌人实际生成的延迟（秒）
# 玩家看到黄色警告方块后，有 0.5 秒时间移动到安全位置
const WARNING_DURATION: float = 0.5  # 警告显示后、敌人生成的延迟时间（秒）
# 敌人距玩家的最小安全距离（像素）
# 防止敌人直接出生在玩家旁边，保障玩家生存空间
const MIN_PLAYER_DIST: float = 150.0  # 出生点距玩家的最小安全距离
# 视口尺寸（与 BG ColorRect 一致）
# 用于计算随机出生点的坐标范围，应与项目设置的窗口尺寸保持一致
const VIEWPORT_W: float = 1280.0  # 视口宽度（像素）
const VIEWPORT_H: float = 720.0  # 视口高度（像素）


# ========== @export 导出变量 ==========
# @export 说明：
#   带有 @export 的变量会出现在 Godot 编辑器的"检查器"面板中，
#   设计师可以在不修改代码的情况下，直接在编辑器里调整参数值，
#   并且修改后立刻生效（编辑器内运行时会热更新）。
#   这是 Godot 实现"程序员-设计师"工作流分离的核心机制。
# PackedScene 说明：
#   PackedScene 是 Godot 中场景的资源类型，相当于一个"场景模板"。
#   通过 instantiate() 方法可以将 PackedScene 实例化为真实的节点树，
#   添加到当前场景中使用。在编辑器中，将敌人场景文件拖入此变量即可完成赋值。
@export var enemy_scene: PackedScene  # 导出敌人场景资源，在检查器中拖入敌方场景文件（如 Enemy.tscn）


## _ready() 是 Godot 的核心生命周期回调
## 当此节点首次进入场景树时，Godot 自动调用此方法一次。
## 此时所有 @onready 变量已完成初始化，子节点均可安全访问。
## 本函数职责：创建刷怪定时器，建立定时刷怪机制。
func _ready() -> void:
	# 创建 Timer 节点（Godot 内置节点，用于定时触发 timeout 信号）
	# Timer.new() 在运行时动态创建节点，与在编辑器中添加节点效果相同
	var spawner: Timer = Timer.new()  # 新建一个 Timer 节点，用于定时触发刷怪
	spawner.wait_time = 1.0  # 设置定时器等待时间为 1.0 秒（初始刷怪间隔）
	spawner.autostart = true  # 设置定时器自动启动，无需手动调用 start()
	# add_child() 将新创建的 Timer 节点添加为当前节点的子节点
	# 只有添加到场景树中的节点才会执行 _process、_physics_process 等回调
	# Timer 节点也必须 add_child() 后才会开始计时
	add_child(spawner)  # 将 Timer 添加为子节点，使其生效并开始计时
	# connect() 将 Timer 的 timeout 信号连接到 _spawn_enemy 函数
	# 每隔 wait_time 秒，Timer 发出 timeout 信号，触发 _spawn_enemy() 执行一次刷怪
	spawner.timeout.connect(_spawn_enemy)  # 定时器到期时调用刷怪函数


## 在视口内随机选一个生成点，并避开玩家周围 MIN_PLAYER_DIST 范围
## 这是敌人出生系统的核心算法，采用"重试机制"确保出生点安全性。
## 返回值：一个 Vector2，表示选中的出生点坐标
##
## 随机出生算法说明：
##   1. 先获取玩家当前位置（若玩家不存在则使用屏幕中心作为参考点）
##   2. 在视口范围内（扣除边缘 margin）随机生成一个点
##   3. 检查该点距玩家是否 >= MIN_PLAYER_DIST
##   4. 若不满足，最多重试 20 次；若 20 次均未找到安全点，则返回最后一次生成的点
##   5. 重试机制防止无限循环，同时保证大多数情况下出生点都在安全区域
func _get_random_spawn_position() -> Vector2:  # 返回随机出生点坐标
	# 三元运算符：若 _player 存在则取其全局位置，否则使用屏幕中心作为参考
	# global_position 是 Node2D 的属性，表示节点在世界坐标系中的位置
	# Vector2(VIEWPORT_W/2, VIEWPORT_H/2) 即屏幕中心点坐标
	var player_pos: Vector2 = _player.global_position if _player else Vector2(VIEWPORT_W / 2, VIEWPORT_H / 2)  # 玩家位置（或屏幕中心）
	var pos: Vector2 = Vector2.ZERO  # 声明 pos 变量，初始化为零向量，用于存储候选出生点
	# range(20) 生成 0~19 的整数序列，即最多重试 20 次
	# _attempt 前缀 _ 表示此变量在循环体内未被使用，仅用于限制循环次数
	for _attempt in range(20):  # 最多尝试 20 次寻找安全出生点
		# 在视口范围内（扣除边缘 SPAWN_MARGIN）随机生成一个点
		pos = Vector2(  # 将随机坐标赋值给 pos
			randf_range(SPAWN_MARGIN, VIEWPORT_W - SPAWN_MARGIN),  # x 坐标：在 [左边距, 右边距] 范围内随机
			randf_range(SPAWN_MARGIN, VIEWPORT_H - SPAWN_MARGIN),  # y 坐标：在 [上边距, 下边距] 范围内随机
		)
		# distance_to() 计算两个 Vector2 之间的欧几里得距离（像素）
		# 若候选点距玩家 >= 最小安全距离，则认为此点安全，直接返回
		if pos.distance_to(player_pos) >= MIN_PLAYER_DIST:  # 当前点与玩家距离足够远，安全
			return pos  # 返回安全的出生点，结束函数
	# 若 20 次尝试后仍未找到安全点（如玩家被困在角落），返回最后一次生成的点
	# 这是降级方案，虽然可能不够理想，但保证函数一定有返回值
	return pos  # 返回最后生成的出生点（可能是不安全的，但保证有返回值）


## 在指定位置显示黄色闪烁警告色块，预示敌人即将在此处生成
## 这是游戏体验设计的重要细节：给玩家 0.5 秒预判时间，
## 看到黄色方块后可以提前移动到安全位置，增加策略性而非纯反应速度。
## 实现方式：动态创建 Polygon2D 节点，用 Tween 动画实现闪烁效果，最后自动销毁。
##   pos: 警告色块显示的世界坐标位置
func _show_spawn_warning(pos: Vector2) -> void:  # 在指定位置显示黄色警告方块
	# 动态创建 Polygon2D 节点，用于显示黄色方块
	# Polygon2D 是 Godot 中用于绘制多边形的节点，可设置顶点、颜色、z_index 等
	var warning: Polygon2D = Polygon2D.new()  # 新建一个 Polygon2D 节点作为警告标记
	# 设置多边形的顶点数组，定义一个 20x20 像素的正方形（中心在 pos 处）
	# PackedVector2Array 是 Godot 中存储 Vector2 数组的高效类型
	# 四个顶点按顺时针顺序：左上(-10,-10) → 右上(10,-10) → 右下(10,10) → 左下(-10,10)
	warning.polygon = PackedVector2Array([  # 设置正方形四个顶点的坐标
		Vector2(-10, -10), Vector2(10, -10),  # 左上角、右上角
		Vector2(10, 10), Vector2(-10, 10)  # 右下角、左下角
	])
	warning.color = Color.YELLOW  # 设置多边形颜色为黄色，警示玩家注意
	# z_index 控制节点的渲染顺序，值越大越靠上（后渲染）
	# 设置为 5 确保警告方块渲染在大多数游戏对象之上，玩家能清楚看到
	warning.z_index = 5  # 设置渲染层级，确保警告显示在最上层
	# global_position 设置节点在世界坐标系中的位置，不受父节点 transform 影响
	warning.global_position = pos  # 将警告方块放置在指定的出生点位置
	# add_child() 将警告节点添加到当前场景，使其显示出来
	# 注意：这里直接用 Main 节点 add_child()，因为 Polygon2D 是临时视觉效果
	add_child(warning)  # 将警告方块添加为子节点，使其显示在屏幕上

	# 创建 Tween 动画对象，用于实现警告方块的闪烁效果
	# Tween 是 Godot 的补间动画系统，可以平滑地改变任意属性（如 modulate:a 控制透明度）
	# create_tween() 是 Node 的方法，为当前节点创建一个 Tween 实例
	var tw: Tween = create_tween()  # 创建补间动画对象，用于控制警告方块的闪烁
	# 循环 3 次：透明→显示→透明→显示→透明→显示，实现"闪烁 3 次"的效果
	for _i in range(3):  # 闪烁 3 次
		# tween_property() 将指定属性从当前值渐变到目标值
		# "modulate:a" 是 Node2D 的 modulate 属性的 a（alpha，透明度）分量，范围 0~1
		# 0.0 = 完全透明，1.0 = 完全不透明
		# 参数：目标对象、属性路径字符串、目标值、动画时长（秒）
		tw.tween_property(warning, "modulate:a", 0.0, 0.1)  # 0.1 秒内渐隐（透明）
		tw.tween_property(warning, "modulate:a", 1.0, 0.1)  # 0.1 秒内渐显（不透明）
	# 最后再渐隐一次，然后销毁节点（三次闪烁后完全消失）
	tw.tween_property(warning, "modulate:a", 0.0, 0.15)  # 最后一次渐隐，持续 0.15 秒
	# tween_callback() 在动画链的最后插入一个回调函数
	# queue_free() 是 Node 的方法，将节点标记为"待删除"，
	# 在下一帧的空闲时间自动从场景树中移除并释放内存
	# 这是 Godot 中安全删除节点的标准方式（避免在信号回调中直接 free() 导致崩溃）
	tw.tween_callback(warning.queue_free)  # 动画结束后自动销毁警告方块，释放内存


## 刷怪主函数，由 Timer 的 timeout 信号触发
## 负责：检查资源是否有效 → 获取随机出生点 → 显示警告 → 等待延迟 → 生成敌人
## await 说明：
##   await 是 Godot 4 的异步语法，会暂停当前函数的执行，
##   等待后面的信号或异步函数完成后，再继续执行后续代码。
##   这里用于实现"警告显示 → 等待 0.5 秒 → 生成敌人"的时序控制。
func _spawn_enemy() -> void:  # 刷怪主函数，定时器触发
	# 防御性检查：若 enemy_scene 未在编辑器中赋值，直接返回，避免崩溃
	# enemy_scene == null 的情况：设计师忘记在检查器中拖入敌人场景文件
	if enemy_scene == null:  # 敌人场景资源未设置，无法刷怪
		return  # 提前返回，不执行后续刷怪逻辑
	# 调用随机出生点算法，获取一个安全的出生位置
	var spawn_pos: Vector2 = _get_random_spawn_position()  # 获取随机安全的出生点坐标
	# 在出生点位置显示黄色警告色块，给玩家预判时间
	_show_spawn_warning(spawn_pos)  # 显示警告方块，玩家看到后可有 0.5 秒反应时间

	# await 暂停当前协程，等待定时器超时后再继续
	# get_tree() 返回当前场景的 SceneTree 实例（Godot 场景树的根）
	# create_timer(秒数) 创建一个一次性定时器，到期后发出 timeout 信号
	# await 等待此信号，实现"延迟生成敌人"的效果
	await get_tree().create_timer(WARNING_DURATION).timeout  # 等待 WARNING_DURATION 秒（0.5秒）

	# instantiate() 将 PackedScene（场景资源）实例化为真实的节点树
	# 返回类型为 Node，这里用 as CharacterBody2D 进行类型转换
	# 若 enemy_scene 实际不是 CharacterBody2D 类型，则 enemy 为 null
	var enemy := enemy_scene.instantiate() as CharacterBody2D  # 实例化敌人场景，转为 CharacterBody2D 类型
	# 防御性检查：若实例化失败（场景类型不匹配或资源损坏），直接返回
	if enemy == null:  # 敌人实例化失败，可能是场景类型错误或资源损坏
		return  # 提前返回，不执行后续逻辑
	# 设置敌人的世界坐标位置为之前计算的出生点
	# global_position 直接设置世界坐标，不受父节点的 transform 影响
	enemy.global_position = spawn_pos  # 将敌人放置在随机出生点位置
	# 将敌人节点添加为 _enemies 容器的子节点
	# _enemies 是一个 Node2D 容器节点，专门用于管理所有敌人
	# 使用容器节点的好处：可以统一管理（如一次性删除所有敌人）、保持场景树整洁
	_enemies.add_child(enemy)  # 将新敌人添加到敌人容器中，敌人正式出现在游戏中
