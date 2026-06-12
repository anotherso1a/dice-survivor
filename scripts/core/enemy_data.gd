## 敌人配置数据（纯资源）
##
## 定义敌人的所有属性配置，每个敌人类型一个独立的 .tres Resource。
## 对应 ARCHITECTURE.md §4.5
## 当前游戏只有一个 Skeleton 敌人，此为骨架 + 实际字段。
##
## 数据依赖关系：
##   - EnemyData 被 WaveData 引用（WaveData.boss_data 字段类型是 EnemyData）
##   - EnemyData 的 scene 字段引用 PackedScene（.tscn 文件），关联实际的敌人 3D 模型场景
##
@tool  # @tool 注释：让脚本在编辑器中运行，策划可在检查器面板中配置敌人属性
class_name EnemyData  # class_name 关键字：将 EnemyData 注册为全局类型，其他脚本可声明 var enemy: EnemyData
extends Resource  # extends Resource 关键字：继承 Resource，敌人配置以 .tres 文件保存
# 为什么用 Resource 而非 Node：敌人配置是静态数据（HP、移速等），不是场景节点；实际敌人节点由 .tscn 场景文件 + EnemyData 配置共同初始化

enum EnemyType { BASIC, RANGED, TANK, SUICIDE, ELITE, BOSS }  # enum 关键字：定义敌人类型枚举
# BASIC=普通近战小怪, RANGED=远程攻击敌人, TANK=高血量坦克型, SUICIDE=自爆型敌人, ELITE=精英怪（比普通怪强）, BOSS=首领敌人


@export_group("Identity")  # Identity 组：敌人身份标识
@export var enemy_id: StringName = &""  # @export 导出到检查器面板；StringName 类型：敌人唯一标识 ID，如 "skeleton_basic"，用于波次配置中引用
@export var display_name: String = ""  # String 类型：敌人显示名称，如 "骷髅兵"、"火焰骷髅"，显示在血条上方

@export_group("Stats")  # Stats 组：敌人属性数值
@export var enemy_type: EnemyType = EnemyType.BASIC  # @export var x: EnemyType：导出敌人类型枚举到检查器面板；BASIC 表示普通近战小怪
@export var max_hp: int = 6  # int 类型：最大生命值，玩家投出伤害面后扣减敌人 HP，HP 归零则敌人死亡
@export var move_speed: float = 80.0  # float 类型：移动速度（像素/秒），决定敌人向玩家移动的快慢
@export var contact_damage: int = 3  # int 类型：接触伤害，敌人碰到玩家时对玩家造成的伤害值

@export_group("Resistance")  # Resistance 组：敌人抗性（对元素伤害的减免）
## 抗性元素（&"fire" / &"ice" / &"thunder" / &""）
## 表示此敌人对哪种元素有抗性，例如 &"fire" 表示火元素伤害会被减免
@export var resist_element: StringName = &""  # StringName 类型：&"" 表示无元素抗性；设置后对应元素伤害会按 resist_percent 减免
## 抗性百分比（0.0 ~ 1.0），例如 0.5 表示减免 50% 对应元素伤害
@export var resist_percent: float = 0.0  # float 类型：0.0 表示无减免，1.0 表示免疫该元素伤害；只在 resist_element 非空时生效

@export_group("Scene")  # Scene 组：敌人场景关联
## 对应的敌人场景 .tscn 路径，例如 "res://scenes/enemies/skeleton.tscn"
## 战斗系统通过此路径实例化（instantiate）敌人节点到场景中
@export var scene: PackedScene  # PackedScene 类型：Godot 的场景资源类型，在检查器中显示为 .tscn 文件拖放区域；运行时通过 scene.instantiate() 创建敌人节点

@export_group("Drop")  # Drop 组：敌人掉落配置
## 掉落表：{ "coins": 1, "exp": 2 } 等，敌人死亡后根据此字典随机掉落物品
## key 是掉落物类型 ID，value 是掉落数量/概率
## 常见 key：coins=金币, exp=经验值, heal=治疗药水, dice=骰子碎片
@export var drop_table: Dictionary = {}  # Dictionary 类型：{} 为空字典表示不掉落任何物品；运行时由掉落系统根据此表计算实际掉落
