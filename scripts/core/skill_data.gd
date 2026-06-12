## 技能数据（纯资源）
##
## 定义玩家可使用的技能配置，每个技能是一个独立的 .tres Resource。
## 对应 ARCHITECTURE.md §4.3
## 当前游戏尚未实现技能系统，此为骨架，后续 M5 填充。
##
## 技能作用目标：
##   - DICE_FACE：作用于单个骰面（如强化某个面）
##   - DICE_WHOLE：作用于整个骰子（如降低冷却时间）
##   - PLAYER：作用于玩家（如回血、护盾）
##   - ALL_DICE：作用于所有骰子（如群体 buff）
##
@tool  # @tool 注释：让脚本在编辑器中运行，策划可在检查器面板中配置技能属性
class_name SkillData  # class_name 关键字：将 SkillData 注册为全局类型，其他脚本可声明 var skill: SkillData
extends Resource  # extends Resource 关键字：继承 Resource，技能配置以 .tres 文件保存
# 为什么用 Resource 而非 Node：技能是静态配置数据，不需要挂场景树、不需要每帧 update，Resource 可直接序列化且占内存极小

enum SkillTarget { DICE_FACE, DICE_WHOLE, PLAYER, ALL_DICE }  # enum 关键字：定义技能作用目标枚举；DICE_FACE=单个骰面, DICE_WHOLE=整个骰子, PLAYER=玩家, ALL_DICE=所有骰子
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }  # enum 关键字：定义稀有度枚举；COMMON=普通, UNCOMMON=非凡, RARE=稀有, EPIC=史诗, LEGENDARY=传说


@export_group("Identity")  # Identity 组：技能身份标识
@export var skill_id: StringName = &""  # @export 导出到检查器面板；StringName 类型（比 String 高效）：技能唯一标识 ID，用于代码中引用和查找技能
@export var skill_name: String = ""  # String 类型：技能显示名称，例如 "精准打击"、"火焰附魔"，显示在 UI 中
@export_multiline var description: String = ""  # @export_multiline 关键字：多行文本输入框；技能详细描述，显示在 tooltip 中

@export_group("Display")  # Display 组：技能 UI 显示
@export var rarity: Rarity = Rarity.COMMON  # @export var x: Rarity：导出稀有度枚举到检查器面板，策划可通过下拉菜单选择；默认值为 COMMON（普通）
@export var icon: Texture2D  # Texture2D 类型：技能图标纹理，在检查器中显示为图片拖放区域

@export_group("Effect")  # Effect 组：技能效果配置
## 作用目标，决定技能影响范围：单个骰面 / 整个骰子 / 玩家 / 所有骰子
@export var target: SkillTarget = SkillTarget.DICE_FACE  # 默认为 DICE_FACE（作用于单个骰面），通常情况下技能都是强化某个特定的骰面
## 效果参数（每个技能按需解读），使用 Dictionary 存储，灵活性高，不同技能可包含不同的 key
## 常见 key：
##   damage_bonus: int    — 伤害加成，例如 +3 伤害
##   cooldown_reduce: float — 冷却缩短，例如 -0.5 秒
##   burn_bonus: int       — 燃烧加成，例如额外 +2 燃烧层数
##   reroll_count: int     — 重投次数，例如可重投 1 次
##   face_overwrite: Dictionary — 覆写骰面，将某个面的属性直接替换为指定值
@export var params: Dictionary = {}  # Dictionary 类型：键值对字典，{} 表示空字典；运行时由技能系统根据 skill_id 查找对应效果逻辑代码来解读这些参数
