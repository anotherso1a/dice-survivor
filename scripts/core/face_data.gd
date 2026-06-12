## 单个骰面数据（最小数据单元）
##
## 每个骰面是一个独立的 Resource，可以在编辑器中直接创建和编辑。
## 设计参考：ARCHITECTURE.md §4.1，同时兼容当前游戏实际使用的字段。
##
## 当前游戏用到的骰面字段：
##   - damage（伤害）
##   - is_crit（暴击）
##   - burn（燃烧层数，对应 element_power，当 element=="fire" 时生效）
##   - value（骰子面值）
##   - effect（描述文本，对应 description）
##   - gamble_value（赌博模式点数）
##   - label（赌博模式显示文本）
##
@tool  # @tool 注释：让此脚本在 Godot 编辑器内也能运行（不仅是游戏运行时），编辑器中修改骰面后可直接预览效果
class_name FaceData  # class_name 关键字：将 FaceData 注册为 Godot 全局类型，在其他脚本中可以直接声明 var face: FaceData 而无需 preload
extends Resource  # extends Resource 关键字：继承 Resource 类而非 Node 类
# Resource 是纯数据容器，不挂在场景树里（不用 add_child），占用内存极小
# 每个 FaceData 实例可以保存为独立的 .tres 文件，在编辑器中右键→新建资源→FaceData 来创建
# 对比 Node：Node 需要挂场景树、有 _process/_physics_process 开销，不适合纯数据
## 骰面类型：普通 / 强化 / 元素 / 诅咒
enum FaceType { NORMAL, ENHANCED, ELEMENTAL, CURSED }  # enum 关键字：定义枚举，这里声明 4 种骰面类型

## ========== 基础字段 ==========
@export_group("Basic")  # @export_group 关键字：在编辑器检查器面板中将下面几个属性归为一组，组名为 "Basic"，方便策划在编辑器中查看和编辑
## 骰面类型（默认为普通面）：普通面只有基础伤害 / 强化面有额外倍率 / 元素面带元素效果 / 诅咒面带自伤
@export var face_type: FaceType = FaceType.NORMAL  # @export 关键字：将此属性导出到 Godot 编辑器检查器面板，策划可以在编辑器中直接修改；GDScript 2.0 强制标注变量类型为 FaceType
## 骰子面值（1~6），表示投掷出的点数，同时影响伤害计算公式
@export var value: int = 1  # @export var x: int 含义：在编辑器中可见的整型属性，默认值为 1
## 基础伤害值，投出此面时对敌人造成的基础伤害（暴击会翻倍）
@export var damage: int = 0  # 伤害值，0 表示此面无伤害（例如纯功能面）
## 伤害倍率（遗物/技能可加成），默认 1.0 表示无额外加成
@export var multiplier: float = 1.0  # float 类型：浮点数，表示倍率，1.0 即 100%
## 是否暴击，true 时此面的伤害会翻倍（由 get_final_damage 方法计算暴击加成）
@export var is_crit: bool = false  # bool 类型：布尔值，默认 false（不暴击）

## ========== 元素字段 ==========
@export_group("Element")  # 在检查器面板中归类为 "Element" 组，以下属性与元素效果相关
## 元素类型（&"fire" / &"ice" / &"thunder" / &"" 表示无元素）
## StringName 比 String 更高效：它是 Godot 内部通过字符串哈希查找的不可变字符串，适合频繁比较的场景
@export var element: StringName = &""  # &"" 是 StringName 的字面量写法，& 前缀表示编译时创建 StringName；空字符串表示无元素
## 元素效果强度（fire=燃烧层数, ice=冻结秒数, thunder=弹射目标数）
@export var element_power: int = 0  # 不同的 element 类型对此值的解读不同：火焰=附加燃烧dot层数，冰=冻结持续时间（秒），雷电=连锁弹射的目标数量

## ========== 诅咒字段 ==========
@export_group("Curse")  # 在检查器面板中归类为 "Curse" 组，诅咒面独有属性
## 诅咒面自伤值，投出诅咒面时对玩家自身造成的伤害
@export var self_damage: int = 0  # self_damage > 0 表示此面会反伤玩家，属于负面骰面

## ========== 赌博字段 ==========
@export_group("Gamble")  # 在检查器面板中归类为 "Gamble" 组，赌博模式专用属性
## 赌博模式点数，投骰子时赌博面使用的独立数值（不同于战斗面的 value）
@export var gamble_value: int = 0  # 赌博模式下，此值替换 value 来判断输赢
## 赌博模式显示标签，例如 "大"、"小"、"+5G" 等，在 UI 中展示给玩家
@export var gamble_label: String = ""  # String 类型：普通字符串，用于 UI 文本显示

## ========== 描述 ==========
@export_group("Display")  # 在检查器面板中归类为 "Display" 组，UI 显示相关属性
## 骰面描述（显示在 UI 或 tooltip），用多行文本编辑器编辑
@export_multiline var description: String = ""  # @export_multiline 关键字：和 @export 类似，但在检查器中显示为多行文本输入框（而非单行），适合长文本


## 运行时计算最终伤害（含暴击 + 倍率）
## multiplier_bonus 来自外部加成（如遗物、技能），会加到骰面自身的 multiplier 上
func get_final_damage(multiplier_bonus: float = 0.0) -> int:  # func 关键字：定义方法；-> int 表示返回值必须是 int 类型（GDScript 2.0 强制标注返回类型）
	var final_mult: float = multiplier + multiplier_bonus  # var 关键字：声明局部变量；将骰面自身倍率 + 外部加成得到最终倍率
	return int(damage * final_mult)  # return 关键字：返回最终伤害值；int() 强制转换为整数（伤害不能有小数）


## 构造函数 _init，用于在代码中动态创建 FaceData 实例时快速赋值
## 注意：在编辑器中创建的 .tres 文件不会调用 _init，而是通过反序列化直接设置属性值
func _init(  # _init 是 GDScript 的内置构造函数，等价于其他语言的 constructor
		p_value: int = 1,  # p_ 前缀表示 parameter（参数）命名惯例；默认值 1 表示默认骰面点数为 1
		p_damage: int = 0,  # 默认伤害为 0：无伤害的功能面
		p_is_crit: bool = false,  # 默认不暴击
		p_element: StringName = &"",  # 默认无元素属性
		p_element_power: int = 0,  # 默认无元素效果强度
) -> void:  # -> void 表示此方法无返回值
	value = p_value  # 将构造函数参数赋值给实例属性 value
	damage = p_damage  # 将构造函数参数赋值给实例属性 damage
	is_crit = p_is_crit  # 将构造函数参数赋值给实例属性 is_crit
	element = p_element  # 将构造函数参数赋值给实例属性 element
	element_power = p_element_power  # 将构造函数参数赋值给实例属性 element_power
