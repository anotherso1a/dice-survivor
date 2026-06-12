# data/dice/ — 骰子数据

## 目录职责

存放所有骰子的 `.tres` Resource 配置文件。每个 `.tres` 文件定义一种骰子的完整属性：面数、冷却、元素、耐久、战斗面/赌博面。

## 数据结构

对应脚本类：`scripts/core/dice_data.gd`（`DiceData`）和 `scripts/core/face_data.gd`（`FaceData`）

### DiceData 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `dice_id` | StringName | 唯一标识，如 `&"standard_d6"` |
| `dice_name` | String | 显示名称，如 "标准骰子" |
| `sides` | int | 面数（通常为 6） |
| `cooldown` | float | 投掷冷却（秒） |
| `element` | StringName | 元素属性（`&"fire"` / `&"ice"` / `&"thunder"` / `&""`） |
| `durability` | int | 使用次数（-1 = 无限） |
| `combat_faces` | Array[FaceData] | 战斗模式下的各面定义 |
| `gamble_faces` | Array[FaceData] | 赌博模式下的各面定义 |
| `icon` | Texture2D | 骰子图标 |

### FaceData 核心字段（骰面最小单元）

| 字段 | 类型 | 说明 |
|------|------|------|
| `face_type` | FaceType | NORMAL / ENHANCED / ELEMENTAL / CURSED |
| `value` | int | 面值（1-6） |
| `damage` | int | 伤害值 |
| `multiplier` | float | 伤害倍率 |
| `is_crit` | bool | 是否暴击面 |
| `element` | StringName | 元素类型 |
| `element_power` | int | 元素效果强度 |
| `self_damage` | int | 诅咒面自伤值 |
| `gamble_value` | int | 赌博模式点数 |

## 开发方式

### 新增骰子

1. 右键此目录 → 新建资源 → 选 `DiceData`
2. 填写 `dice_id`、`dice_name` 等基础属性
3. 在 `combat_faces` 数组中添加 6 个 `FaceData`
4. （如需赌博模式）在 `gamble_faces` 中添加对应面
5. 保存为 `xxx_d6.tres`

### 已有骰子类型（来自设计文档）

| 文件名 | 名称 | 说明 |
|--------|------|------|
| `standard_d6.tres` | 标准骰子 | 基础 1-6 面 |
| `leaded_d6.tres` | 铅骰子 | 偏向高面值，有自伤面 |
| `glass_d6.tres` | 玻璃骰子 | 高伤低耐久 |
| `fire_d6.tres` | 火焰骰子 | 火元素面，触发燃烧 |
| `ice_d6.tres` | 冰霜骰子 | 冰元素面，触发冻结 |
| `thunder_d6.tres` | 雷电骰子 | 雷元素面，触发弹射 |

## 注意事项

- 每种骰子的 `combat_faces` 数组长度应与 `sides` 一致
- `FaceData` 是嵌套资源，编辑时展开 DiceData 的 `combat_faces` 数组逐个编辑
- 骰面修改（技能改写/附魔）由 `DiceManager` 在运行时处理，不修改 `.tres` 原文件
