## 遗物数据（纯资源）
##
## 定义遗物（被动道具）的配置数据，每个遗物是一个独立的 .tres Resource。
## 遗物提供全局被动效果，例如：伤害加成、暴击率提升、额外金币掉落等。
## 对应 ARCHITECTURE.md §4.4
## 当前游戏尚未实现遗物系统，此为骨架。
##
@tool  # @tool 注释：让脚本在编辑器中运行，策划可在检查器面板中配置遗物属性
class_name RelicData  # class_name 关键字：将 RelicData 注册为全局类型，其他脚本可声明 var relic: RelicData
extends Resource  # extends Resource 关键字：继承 Resource，遗物配置以 .tres 文件保存
# 为什么用 Resource 而非 Node：遗物是静态被动效果配置，不参与场景树渲染，继承 Resource 更轻量、可序列化、可在编辑器中直接创建和编辑

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }  # enum 关键字：定义稀有度枚举；COMMON=普通（白色边框）, UNCOMMON=非凡（绿色边框）, RARE=稀有（蓝色边框）, EPIC=史诗（紫色边框）, LEGENDARY=传说（金色边框）


@export_group("Identity")  # Identity 组：遗物身份标识
@export var relic_id: StringName = &""  # @export 导出到检查器面板；StringName 类型（比 String 高效）：遗物唯一标识 ID，代码中通过此 ID 查找遗物效果
@export var relic_name: String = ""  # String 类型：遗物显示名称，例如 "力量护符"、"幸运硬币"，显示在遗物背包 UI 中
@export_multiline var description: String = ""  # @export_multiline 关键字：多行文本输入框；遗物效果描述文本，显示在 tooltip 中解释此遗物的具体效果

@export_group("Display")  # Display 组：遗物 UI 显示
@export var rarity: Rarity = Rarity.COMMON  # @export var x: Rarity：导出稀有度枚举到检查器面板，策划通过下拉菜单选择稀有度；影响遗物边框颜色和掉落概率
@export var icon: Texture2D  # Texture2D 类型：遗物图标纹理，在检查器中显示为图片拖放区域

@export_group("Effect")  # Effect 组：遗物效果配置
## 作用模式："combat" / "gamble" / "both"——决定遗物在哪种模式下生效
## - "combat"：仅在战斗模式生效（如伤害加成）
## - "gamble"：仅在赌博模式生效（如提升赌博赔率）
## - "both"：两种模式都生效（如全局属性加成）
@export var applies_to: StringName = &"both"  # StringName 类型：默认 "both" 表示两种模式都生效

## 效果逻辑脚本（可选，复杂遗物用 GDScript 实现）
## 当遗物效果比较复杂（如条件触发、多层判断）时，用独立的 GDScript 脚本实现效果逻辑
## 简单遗物只需要用下面的 params 字典配置即可，此字段留空
@export var effect_script: GDScript  # GDScript 类型：在检查器中显示为脚本资源拖放区域；复杂遗物挂载脚本，运行时调用脚本中的方法执

## 效果参数（简单遗物用 Dictionary 配置）
## 简单遗物（如纯数值加成）不需要单独写脚本，直接用以下 key-value 配置即可
## 常见 key：
##   damage_bonus: int    — 伤害加成，例如 +5 基础伤害
##   cooldown_reduce: float — 冷却缩短，例如 -0.3 秒冷却时间
##   burn_bonus: int       — 燃烧加成，例如 +2 燃烧层数
##   crit_chance: float     — 暴击率提升，例如 0.15 表示 +15% 暴击率
@export var params: Dictionary = {}  # Dictionary 类型：键值对字典，{} 表示空字典；运行时由遗物系统读取 params 中的 key 并应用对应效果
