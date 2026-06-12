## 波次配置数据（纯资源）
##
## 每一波敌人出生配置，由 GameManager 在战斗中加载。
## 对应 ARCHITECTURE.md §二、data/waves/
##
## 数据依赖关系：
##   - WaveData 引用 EnemyData（boss_data 字段类型为 EnemyData）
##   - WaveData 的 enemy_groups 通过 enemy_id（StringName）间接引用 EnemyData
##   - WaveData 被 GameManager 加载，用于控制每一波敌人的生成
##
## 波次系统工作流程：
##   1. GameManager 按顺序加载 WaveData 列表
##   2. 根据 enemy_groups 中的配置，在屏幕边缘生成敌人
##   3. duration=-1 时：清完所有敌人才进入下一波（标准生存模式）
##   4. duration>0 时：时间到了自动进下一波（限时模式）
##   5. is_boss_wave=true 时：生成本波的 BOSS 敌人
##
@tool  # @tool 注释：让脚本在编辑器中运行，策划可在检查器面板中配置每一波敌人
class_name WaveData  # class_name 关键字：将 WaveData 注册为全局类型，GameManager 中声明 var waves: Array[WaveData]
extends Resource  # extends Resource 关键字：继承 Resource，波次配置以 .tres 文件保存在 data/waves/ 目录下
# 为什么用 Resource 而非 Node：波次配置是关卡数据，不需要挂场景树、不需要每帧执行；每个 .tres 文件代表一个波次，策划可独立编辑


@export_group("Identity")  # Identity 组：波次身份标识
@export var wave_id: StringName = &""  # @export 导出到检查器面板；StringName 类型：波次唯一 ID，如 &"wave_1"、&"boss_final"
@export var wave_index: int = 0  # int 类型：波次序号（0 开始），GameManager 按 wave_index 顺序加载，数值越小越先出现

@export_group("Spawn")  # Spawn 组：敌人出生配置
## 本波敌人组：[{ "enemy_id": &"skeleton_basic", "count": 5 }, ...]
## 数组中每个 Dictionary 包含：
##   - enemy_id (StringName)：敌人类型 ID，对应 EnemyData 的 enemy_id
##   - count (int)：该类型敌人的数量
## 例如：[{"enemy_id": &"skeleton_basic", "count": 3}, {"enemy_id": &"skeleton_ranged", "count": 2}] 表示生 3 个骷髅兵 + 2 个远程骷髅
@export var enemy_groups: Array[Dictionary] = []  # Array[Dictionary]：泛型数组，元素类型为 Dictionary；空数组 [] 表示不生成敌人

## 波次持续时间（秒，-1 表示清完才结束）
## -1：生存模式，必须清完所有这一波的敌人才进入下一波
## 正数：限时模式，时间到了自动进入下一波（即使场内还有敌人）
@export var duration: float = -1.0  # float 类型：-1.0 为默认值，表示必须清完所有敌人

## 是否是 BOSS 波，true 时此波为 BOSS 关卡
@export var is_boss_wave: bool = false  # bool 类型：标记此波是否为 BOSS 波；BOSS 波通常只生成一个强力敌人，且显示 BOSS 血条

## BOSS 数据（仅 is_boss_wave=true 时有效），直接引用 EnemyData 资源
@export var boss_data: EnemyData  # EnemyData 类型：在检查器中显示为 EnemyData 资源拖放区域；WaveData 依赖 EnemyData，当 is_boss_wave=true 时 GameManager 读取此字段生成 BOSS
