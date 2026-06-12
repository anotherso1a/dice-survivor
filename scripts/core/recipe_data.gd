## 合成配方数据（纯资源）
##
## 定义哪些骰子可以合成为新骰子，每个配方是一个独立的 .tres Resource。
## 对应 ARCHITECTURE.md §二、data/recipes/
##
## 数据依赖关系：
##   - RecipeData 通过 inputs/output 中的 StringName（骰子 ID）间接引用 DiceData
##   - 合成系统运行时：读取 RecipeData → 用 inputs 中的 dice_id 查找玩家手中的 DiceData → 验证是否满足合成条件
##
## 合成系统工作流程：
##   1. 玩家拥有 2 个（或更多）骰子
##   2. 合成系统遍历所有 RecipeData，检查 inputs 中的骰子 ID 是否与玩家拥有的骰子匹配
##   3. 配方 inputs 是无序的：A+B 和 B+A 视为同一个配方
##   4. 匹配成功后消耗 inputs 中的骰子，给予玩家 output 对应的新骰子
##   5. 扣除 cost 数量的金币
##
@tool  # @tool 注释：让脚本在编辑器中运行，策划可在检查器面板中配置合成配方
class_name RecipeData  # class_name 关键字：将 RecipeData 注册为全局类型，合成系统可声明 var recipes: Array[RecipeData]
extends Resource  # extends Resource 关键字：继承 Resource，配方配置以 .tres 文件保存在 data/recipes/ 目录下
# 为什么用 Resource 而非 Node：合成配方是静态配置数据，不参与场景树渲染；每个 .tres 文件代表一个独立的合成规则


@export_group("Identity")  # Identity 组：配方身份标识
@export var recipe_id: StringName = &""  # @export 导出到检查器面板；StringName 类型：配方唯一标识 ID，如 &"merge_fire_and_ice"

@export_group("Inputs")  # Inputs 组：合成输入（需要的骰子）
## 输入骰子 ID 列表（无序，A+B == B+A），合成系统不关心骰子的排列顺序
## StringName 类型数组，每个元素是 DiceData 的 dice_id，如 [&"d6_fire", &"d6_ice"]
@export var inputs: Array[StringName] = []  # Array[StringName]：泛型数组，元素类型为 StringName；空数组 [] 表示无需输入（理论上至少需要 2 个骰子）

@export_group("Output")  # Output 组：合成输出（获得的新骰子）
## 输出骰子 ID，对应 DiceData 的 dice_id，如 &"d6_fire_ice"
@export var output: StringName = ""  # StringName 类型：合成后给予玩家的骰子 ID；合成系统根据此 ID 查找对应的 DiceData 资源并实例化

@export_group("Cost")  # Cost 组：合成消耗
## 合成金币消耗，执行合成时从玩家金币中扣除
@export var cost: int = 0  # int 类型：合成所需金币数量，0 表示免费合成（通常会设置一定消耗来平衡游戏）

@export_group("Display")  # Display 组：配方 UI 显示
@export_multiline var description: String = ""  # @export_multiline 关键字：多行文本输入框；配方描述文本，在合成界面中向玩家展示合成结果预览
