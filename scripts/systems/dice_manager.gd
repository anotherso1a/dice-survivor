## 骰子池管理（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 DiceManager.xxx 直接访问。
##
## 负责：
##   1. 创建 / 获取骰子数据（替代旧的 DiceDatabase 静态方法）
##   2. 管理骰面数据构造（FaceData 替代 Dictionary）
##   3. 后续 M5 加入骰子池 CRUD、骰面修改、合成配方
##
## 对应旧文件：scripts/Data/DiceDatabase.gd
## 迁移要点：
##   - get_xxx_d6() 返回 DiceData（含 FaceData 数组）
##   - 不再用 Dictionary 表示骰面
##
extends Node  # 继承 Node 基类；作为 Autoload 挂载到场景树根节点下


## 获取标准 d6（初始骰子）
func get_standard_d6() -> DiceData:  # 返回 DiceData 类型的标准六面骰子数据
	var d: DiceData = DiceData.new()  # 创建 DiceData 实例（Godot 中 .new() 调用类的构造函数）
	d.dice_id = &"d6_standard"  # 设置骰子唯一标识，&"..." 是 StringName 字面量语法（比 String 更高效，适合做键名）
	d.dice_name = "标准骰子 d6"  # 设置骰子显示名称，用普通 String 因为需要国际化
	d.cooldown = 1.0  # 设置投掷冷却时间（秒），1.0 秒可再次投掷
	d.element = &""  # 设置元素类型为空（无元素），StringName 类型
	d.durability = -1  # 设置耐久度为 -1，表示永不损坏（标准骰子无耐久限制）
	d.combat_faces = [  # 设置战斗骰面数组：6 个面，每个面对应投掷结果 1-6
		_create_face(1, 10, true, &"", 0),   ## 1 暴击：面值1、伤害10、是暴击、无元素、元素强度0
		_create_face(2, 2, false, &"", 0),   ## 面值2、伤害2、非暴击
		_create_face(3, 2, false, &"", 0),   ## 面值3、伤害2、非暴击
		_create_face(4, 2, false, &"", 0),   ## 面值4、伤害2、非暴击
		_create_face(5, 2, false, &"", 0),   ## 面值5、伤害2、非暴击
		_create_face(6, 3, false, &"", 0),   ## 面值6、伤害3、非暴击（6点稍高伤害）
	]
	d.gamble_faces = [  # 设置赌博骰面数组：6 个面，用于赌博小游戏
		_create_gamble_face(1, 1, "烂"),   ## 面值1、赌值1、标签"烂"（最差结果）
		_create_gamble_face(2, 2, "烂"),   ## 面值2、赌值2、标签"烂"
		_create_gamble_face(3, 3, "中"),   ## 面值3、赌值3、标签"中"（中等结果）
		_create_gamble_face(4, 4, "中"),   ## 面值4、赌值4、标签"中"
		_create_gamble_face(5, 5, "好"),   ## 面值5、赌值5、标签"好"（较好结果）
		_create_gamble_face(6, 6, "顶"),   ## 面值6、赌值6、标签"顶"（最佳结果）
	]
	return d  # 返回构造完成的骰子数据


## 获取灌铅 d6
func get_leaded_d6() -> DiceData:  # 返回 DiceData 类型的灌铅六面骰子数据
	var d: DiceData = DiceData.new()  # 创建 DiceData 实例
	d.dice_id = &"d6_leaded"  # 设置骰子唯一标识为灌铅骰子
	d.dice_name = "灌铅骰子 d6"  # 设置骰子显示名称
	d.cooldown = 2.0  # 设置投掷冷却时间 2.0 秒（比标准骰子慢一倍，代价是更高伤害）
	d.durability = -1  # 耐久度为 -1，永不损坏
	d.combat_faces = [  # 设置战斗骰面数组：6 个面，伤害比标准骰子更高
		_create_face(1, 15, true, &"", 0),   ## 1 暴击（灌铅强化）：面值1、伤害15、暴击
		_create_face(2, 3, false, &"", 0),   ## 面值2、伤害3（比标准骰子的2高）
		_create_face(3, 3, false, &"", 0),   ## 面值3、伤害3
		_create_face(4, 3, false, &"", 0),   ## 面值4、伤害3
		_create_face(5, 3, false, &"", 0),   ## 面值5、伤害3
		_create_face(6, 4, false, &"", 0),   ## 面值6、伤害4
	]
	return d  # 返回构造完成的灌铅骰子数据（注意：无赌博面，灌铅骰子不参与赌博）


## 获取玻璃 d6
func get_glass_d6() -> DiceData:  # 返回 DiceData 类型的玻璃六面骰子数据
	var d: DiceData = DiceData.new()  # 创建 DiceData 实例
	d.dice_id = &"d6_glass"  # 设置骰子唯一标识为玻璃骰子
	d.dice_name = "玻璃骰子 d6"  # 设置骰子显示名称
	d.cooldown = 0.8  # 设置投掷冷却时间 0.8 秒（比标准骰子更快，高频输出）
	d.durability = 10  # 设置当前耐久度为 10（玻璃骰子有使用次数限制）
	d.max_durability = 10  # 设置最大耐久度为 10，耐久归零后骰子损坏
	d.combat_faces = [  # 设置战斗骰面数组：6 个面，高伤害高风险
		_create_face(1, 20, true, &"", 0),   ## 1 暴击（高风险高回报）：面值1、伤害20、暴击
		_create_face(2, 5, false, &"", 0),   ## 面值2、伤害5（比标准骰子的2高很多）
		_create_face(3, 5, false, &"", 0),   ## 面值3、伤害5
		_create_face(4, 5, false, &"", 0),   ## 面值4、伤害5
		_create_face(5, 5, false, &"", 0),   ## 面值5、伤害5
		_create_face(6, 6, false, &"", 0),   ## 面值6、伤害6
	]
	return d  # 返回构造完成的玻璃骰子数据（无赌博面，且会消耗耐久度）


## 获取火焰 d6
func get_fire_d6() -> DiceData:  # 返回 DiceData 类型的火焰六面骰子数据
	var d: DiceData = DiceData.new()  # 创建 DiceData 实例
	d.dice_id = &"d6_fire"  # 设置骰子唯一标识为火焰骰子
	d.dice_name = "火焰骰子 d6"  # 设置骰子显示名称
	d.cooldown = 1.0  # 设置投掷冷却时间 1.0 秒（与标准骰子相同）
	d.element = &"fire"  # 设置元素类型为火焰（&"fire" 是 StringName），决定元素效果触发
	d.durability = -1  # 耐久度为 -1，永不损坏
	d.combat_faces = [  # 设置战斗骰面数组：6 个面，暴击面附带燃烧效果
		_create_face(1, 8, true, &"fire", 3),  ## 1 火暴击：面值1、伤害8、暴击、火元素、3层燃烧
		_create_face(2, 2, false, &"", 0),   ## 面值2、伤害2、非暴击、无元素
		_create_face(3, 2, false, &"", 0),   ## 面值3、伤害2、非暴击、无元素
		_create_face(4, 2, false, &"", 0),   ## 面值4、伤害2、非暴击、无元素
		_create_face(5, 2, false, &"", 0),   ## 面值5、伤害2、非暴击、无元素
		_create_face(6, 2, false, &"", 0),   ## 面值6、伤害2、非暴击、无元素（只有暴击面有元素效果）
	]
	return d  # 返回构造完成的火焰骰子数据（注意：只有暴击面带火元素，普通面无元素）


## ========== 内部构造方法 ==========

## 创建战斗骰面
func _create_face(  # 以下划线开头表示内部方法，不建议外部直接调用
	value: int,  # 骰面点数（1-6）
	damage: int,  # 该面造成的伤害值
	is_crit: bool,  # 该面是否为暴击
	element: StringName,  # 该面的元素类型（空 StringName 表示无元素）
	element_power: int,  # 元素强度（如燃烧层数）
) -> FaceData:  # 返回 FaceData 类型的骰面数据
	var f: FaceData = FaceData.new()  # 创建 FaceData 实例
	f.value = value  # 设置骰面点数
	f.damage = damage  # 设置伤害值
	f.is_crit = is_crit  # 设置是否暴击
	f.element = element  # 设置元素类型
	f.element_power = element_power  # 设置元素强度
	return f  # 返回构造完成的骰面数据


## 创建赌博骰面
func _create_gamble_face(value: int, gamble_value: int, label: String) -> FaceData:  # 创建赌博面：点数、赌值、标签
	var f: FaceData = FaceData.new()  # 创建 FaceData 实例
	f.value = value  # 设置骰面点数
	f.gamble_value = gamble_value  # 设置赌博值（决定赌博收益）
	f.gamble_label = label  # 设置赌博标签（显示"烂/中/好/顶"等品质文字）
	return f  # 返回构造完成的赌博骰面数据
