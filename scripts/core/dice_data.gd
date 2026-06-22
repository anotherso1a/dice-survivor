## 骰子数据（纯资源，无逻辑）
##
## 每个骰子是一个独立的 .tres Resource，在编辑器中直接编辑。
## 骰面使用 FaceData 资源（不再是 Dictionary），支持类型安全和编辑器预览。
## DiceData 依赖 FaceData：combat_faces 和 gamble_faces 数组的元素类型都是 FaceData
##
## 对应旧文件：scripts/Data/DiceData.gd
## 迁移要点：
##   - combat_faces / gamble_faces 从 Array[Dictionary] → Array[FaceData]
##   - roll_combat() / roll_gamble() 返回 FaceData 而非 Dictionary
##
@tool  # @tool 注释：让此脚本在编辑器中也可运行，支持在检查器面板中编辑骰子属性并实时预览
class_name DiceData  # class_name 关键字：将 DiceData 注册为 Godot 全局类型，其他脚本可直接声明 var dice: DiceData
extends Resource  # extends Resource 关键字：继承 Resource，骰子数据以 .tres 文件保存在磁盘，可在编辑器中右键→新建资源→DiceData 创建
# Resource vs Node：DiceData 是骰子的配置数据而非场景节点，不需要 _process 每帧更新，继承 Resource 更轻量且可序列化

signal durability_changed(new_value: int, max_value: int)  # signal 关键字：定义信号；耐久度变化时发出，UI 可以连接此信号来更新耐久条显示；new_value 当前耐久，max_value 最大耐久
signal broken  # signal 关键字：定义信号；骰子耐久耗尽（损坏）时发出，战斗系统监听此信号来处理骰子移除逻辑

enum DiceMode { COMBAT, GAMBLE }  # enum 关键字：定义骰子模式枚举；COMBAT=战斗模式（投伤害面），GAMBLE=赌博模式（投赌博面）

## 骰子攻击类型（决定结算方式）
enum AttackType {
	SINGLE_TARGET = 0,  ## 单目标投射物（标准/火焰/冰霜等普通骰子）
	AOE_IMPACT = 1,     ## 范围冲击（山岳骰子 — 命中后爆炸伤害范围内所有敌人）
	PENETRATING_BULLET = 2,  ## 穿透子弹（枪手角色 — 直线飞行，根据点数决定穿透次数）
}


## ========== 基础字段 ==========
@export_group("Identity")  # Identity 组：骰子的身份标识字段
## 骰子唯一 ID（用于合成配方引用，如 "d6_standard"），StringName 用于高效字符串比较和哈希查找
@export var dice_id: StringName = &""  # @export 导出到检查器面板；StringName 类型：Godot 优化过的不可变字符串，比 String 更适合做 ID 索引
## 骰子显示名称，例如 "标准骰子"、"火焰骰子"，显示在游戏 UI 中
@export var dice_name: String = ""  # String 类型：普通字符串，用于 UI 显示
## 面数（通常为 6），即这个骰子有多少个面，combat_faces 和 gamble_faces 数组长度应与此值相等
@export var sides: int = 6  # int 类型：骰子面数，默认 6 面（标准六面骰子）
## 投掷冷却时间（秒），每次投掷后需要等待 cooldown 秒才能再次投掷
@export var cooldown: float = 1.0  # float 类型：冷却时间秒数，1.0 表示每次投掷后冷却 1 秒

@export_group("Element")  # Element 组：骰子元素属性
## 骰子默认元素（面可以覆盖此值），当骰面自身没有设置 element 时使用此默认值
@export var element: StringName = &""  # 骰子级别的元素设置，如果 FaceData 的 element 为空则使用此值

@export_group("Durability")  # Durability 组：骰子耐久度系统
## 耐久上限（-1 表示无限），每次投掷消耗 1 点耐久，耐久归零后骰子损坏
@export var durability: int = -1  # -1 表示无限耐久（不会损坏），正数表示可投掷次数
## 当前耐久（运行时），游戏过程中动态变化的剩余耐久值
var current_durability: int = -1  # var（无 @export）：运行时变量，不显示在检查器面板中；在 _init 中初始化为 durability 的值
## 当前模式（运行时），记录骰子当前处于战斗模式还是赌博模式
var current_mode: DiceMode = DiceMode.COMBAT  # 运行时变量，默认是战斗模式（游戏开始时骰子进入战斗模式）


## ========== 骰面数据 ==========
@export_group("Faces")  # Faces 组：骰子的骰面配置（核心数据）
## 战斗模式骰面（长度应 == sides），即每个面对应的战斗效果数据
@export var combat_faces: Array[FaceData] = []  # Array[FaceData] 是 GDScript 2.0 的泛型数组写法：声明数组元素类型必须是 FaceData，编辑器只允许拖入 FaceData 资源
# DiceData 依赖 FaceData：数组的每个元素都是 FaceData 实例，roll_combat() 从中随机取一个面返回
## 赌博模式骰面（长度应 == sides），即每个面对应的赌博效果数据
@export var gamble_faces: Array[FaceData] = []  # 赌博模式下使用的骰面数组，roll_gamble() 从此数组中随机选择骰面

@export_group("Display")  # Display 组：骰子 UI 显示
## 骰子图标（在 UI 中显示），例如骰子背包栏中的缩略图
@export var icon: Texture2D  # Texture2D 类型：2D 纹理贴图，在检查器中显示为图片拖放区域
## 骰子材质（决定骰体外观和点数图案样式）
@export var dice_material: DiceMaterial

@export_group("Attack")  # Attack 组：攻击行为
## 攻击效果配置（新系统 - 优先使用）
@export var attack_effect: AttackEffect  # 引用一个 AttackEffect Resource（ProjectileEffect/MeleeEffect/SpellEffect等）
## 攻击类型（旧系统 - 仅用于向后兼容，新骰子应使用 attack_effect）
@export var attack_type: AttackType = AttackType.SINGLE_TARGET
## AOE 爆炸半径（仅 attack_type == AOE_IMPACT 时生效）
@export var aoe_radius: float = 120.0


func _init() -> void:  # _init 构造函数：在 DiceData 实例创建时调用（包括编辑器加载 .tres 文件时）
	current_durability = durability  # 将当前耐久初始化为最大耐久值，确保新骰子耐久是满的


## 投掷战斗面，返回 FaceData（含暴击判定）
## 在战斗系统中调用此方法，随机选择一个战斗骰面并消耗 1 点耐久
func roll_combat() -> FaceData:  # func roll_combat() 返回 FaceData：战斗投掷方法，返回值用于战斗伤害计算
	if combat_faces.is_empty():  # .is_empty() 检查数组是否为空；如果战斗骰面未配置则报错
		push_error("DiceData: combat_faces 为空，无法投掷")  # push_error() 在 Godot 调试器中输出红色错误信息，帮助开发者排查
		return null  # return null：骰面为空时返回 null，调用方需要判空处理
	if is_broken():  # 检查骰子是否已损坏（耐久耗尽）
		return null  # 已损坏的骰子不能投掷，返回 null

	_consume_durability()  # 调用私有方法消耗 1 点耐久（仅在前两个检查通过后才消耗）
	var face: FaceData = combat_faces.pick_random()  # .pick_random() 是 Array 的内置方法：从数组中随机选取一个元素返回；这里是随机选取一个战斗骰面
	return face  # 返回随机选中的 FaceData，调用方通过 face.damage / face.is_crit 等属性计算最终伤害


## 投掷赌博面，返回 FaceData
## 逻辑与 roll_combat 完全相同，只是从 gamble_faces 数组中随机选取
func roll_gamble() -> FaceData:  # 赌博模式投掷方法，在赌博阶段调用
	if gamble_faces.is_empty():  # 检查赌博骰面数组是否为空
		push_error("DiceData: gamble_faces 为空，无法投掷")  # 输出错误信息到调试器
		return null  # 骰面为空返回 null
	if is_broken():  # 损坏检查
		return null  # 损坏返回 null

	_consume_durability()  # 消耗耐久
	var face: FaceData = gamble_faces.pick_random()  # 从赌博骰面数组中随机选一个
	return face  # 返回选中的赌博骰面


## 切换战斗/赌博模式，由游戏状态机调用（例如进入赌博阶段时切换到 GAMBLE 模式）
func set_mode(mode: DiceMode) -> void:  # 参数 mode 是 DiceMode 枚举类型，-> void 表示无返回值
	current_mode = mode  # 更新当前模式，后续投掷方法根据此值决定从哪个数组选面（实际由调用方决定调用 roll_combat 还是 roll_gamble）


## 是否已损坏（耐久耗尽）
## 当 durability > 0（非无限耐久）且 current_durability <= 0（剩余耐久用完）时返回 true
func is_broken() -> bool:  # -> bool 表示该方法返回布尔值
	return durability > 0 and current_durability <= 0  # 两个条件同时满足才算损坏：1) 不是无限耐久 2) 当前耐久归零


## 消耗耐久（内部使用），每次投掷后自动调用
func _consume_durability() -> void:  # _ 前缀是 GDScript 命名惯例：表示私有方法（仅供内部使用，外部不应直接调用）
	if durability > 0:  # 只有非无限耐久的骰子才需要消耗耐久
		current_durability -= 1  # 当前耐久减 1
		durability_changed.emit(current_durability, durability)  # .emit() 发出 durability_changed 信号，通知 UI 更新耐久条显示；传递参数格式与 signal 声明一致
		if is_broken():  # 消耗后再次检查是否损坏
			broken.emit()  # 如果已损坏，发出 broken 信号，战斗系统监听此信号将骰子从骰子区移除


## 获取有效的攻击效果（优先使用新系统，fallback 到旧系统）
func get_attack_effect() -> AttackEffect:
	# 如果配置了新系统的 AttackEffect，直接使用
	if attack_effect != null:
		return attack_effect
	
	# Fallback: 根据旧的 attack_type 创建对应的 AttackEffect
	return _create_effect_from_old_type()


## 从旧系统创建 AttackEffect（向后兼容）
## 注意：base_damage = 0，实际伤害由 FaceData.damage 决定
func _create_effect_from_old_type() -> AttackEffect:
	match attack_type:
		AttackType.PENETRATING_BULLET:
			var effect: ProjectileEffect = ProjectileEffect.new()
			effect.effect_name = "穿透子弹"
			effect.base_damage = 0  # 实际伤害用 FaceData.damage
			effect.projectile_count = 1
			effect.penetration = 1  # 4-6点穿透1个额外敌人
			effect.speed = 500.0
			return effect
		
		AttackType.AOE_IMPACT:
			var effect: SpellEffect = SpellEffect.new()
			effect.effect_name = "范围冲击"
			effect.base_damage = 0  # 实际伤害用 FaceData.damage
			effect.aoe_radius = aoe_radius
			effect.delay = 0.2
			return effect
		
		_:  # SINGLE_TARGET 或其他
			var effect: ProjectileEffect = ProjectileEffect.new()
			effect.effect_name = "单目标投射物"
			effect.base_damage = 0  # 实际伤害用 FaceData.damage
			effect.projectile_count = 1
			effect.penetration = 0
			effect.speed = 600.0
			return effect
