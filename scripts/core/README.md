# scripts/core/ — 核心数据类

## 目录职责

存放纯数据类（`extends Resource`），是整个游戏数据驱动架构的基础。这些类只定义**数据结构和计算方法**，不包含任何游戏逻辑、节点操作或 I/O。

> **核心原则**：core 目录下的脚本不知道"游戏世界"的存在。它们不知道场景树、不知道 Autoload、不知道任何 Node。

## 包含文件

| 文件 | 类名 | 说明 |
|------|------|------|
| `face_data.gd` | FaceData | 骰面最小数据单元（伤害/元素/暴击/诅咒） |
| `dice_data.gd` | DiceData | 骰子数据（面数组/冷却/耐久/模式切换） |
| `skill_data.gd` | SkillData | 技能数据（目标类型/稀有度/效果参数） |
| `relic_data.gd` | RelicData | 遗物数据（生效场景/效果脚本/参数） |
| `enemy_data.gd` | EnemyData | 敌人配置（类型/属性/掉落表） |
| `wave_data.gd` | WaveData | 波次配置（敌人组/间隔/BOSS 波标记） |
| `recipe_data.gd` | RecipeData | 合成配方（输入骰子/输出骰子/消耗） |

## 设计规则

### 允许做的事

- 定义 `@export` 属性供编辑器编辑
- 定义枚举（如 `FaceType`、`EnemyType`、`Rarity`）
- 实现纯计算方法（如 `get_final_damage()`）
- 定义信号（用于 Resource 内部状态通知）

### 禁止做的事

- ❌ `extends Node` 或任何场景节点
- ❌ `get_tree()`、`get_node()` 等场景树操作
- ❌ 引用 `EventBus`、`GameManager` 等 Autoload
- ❌ 文件 I/O（`load`、`save` 等）
- ❌ 任何 `_process`、`_physics_process` 生命周期

### 引用依赖

```
core 可以引用：core 内部的其他类、utils
core 不可引用：systems、components、entities、effects、ui、minigames
```

## 与 .tres 文件的关系

```
core/face_data.gd  ← 定义数据结构
data/dice/xxx.tres ← 存储具体数据实例（编辑器创建）
```

- `.gd` 是类定义（模板）
- `.tres` 是类的实例（数据）
- 在编辑器中新建 Resource → 选择 class_name → 填写属性 → 保存为 `.tres`

## 示例

```gdscript
# face_data.gd — 纯数据，无副作用
class_name FaceData
extends Resource

enum FaceType { NORMAL, ENHANCED, ELEMENTAL, CURSED }

@export var face_type: FaceType = FaceType.NORMAL
@export var value: int = 1
@export var damage: int = 1
@export var multiplier: float = 1.0
@export var is_crit: bool = false
@export var element: StringName = &""
@export var element_power: int = 0
@export var self_damage: int = 0
@export var gamble_value: int = 0
@export var description: String = ""

func get_final_damage(multiplier_bonus: float = 0.0) -> int:
    var final_mult: float = multiplier + multiplier_bonus
    return int(damage * final_mult)
```
