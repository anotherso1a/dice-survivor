# data/skills/ — 技能数据

## 目录职责

存放所有技能的 `.tres` Resource 配置文件。技能是升级三选一的核心内容，每个技能定义了如何修改骰面、骰子或玩家属性。

## 数据结构

对应脚本类：`scripts/core/skill_data.gd`（`SkillData`）

### SkillData 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `skill_id` | StringName | 唯一标识 |
| `skill_name` | String | 显示名称 |
| `description` | String | 技能描述文本 |
| `rarity` | Rarity | 稀有度：COMMON / UNCOMMON / RARE / EPIC / LEGENDARY |
| `target` | SkillTarget | 作用目标：DICE_FACE / DICE_WHOLE / PLAYER / ALL_DICE |
| `icon` | Texture2D | 技能图标 |
| `params` | Dictionary | 效果参数（每个技能按需解读） |

## 技能目标类型说明

| SkillTarget | 说明 | 示例 |
|-------------|------|------|
| `DICE_FACE` | 修改单个骰面 | "锁定"：将指定面锁定为固定值 |
| `DICE_WHOLE` | 修改整颗骰子 | "强化"：所有面伤害 +1 |
| `PLAYER` | 修改玩家属性 | "快速投掷"：冷却 -0.3s |
| `ALL_DICE` | 影响所有骰子 | "元素共鸣"：所有骰子附加元素伤害 |

## 开发方式

### 新增技能

1. 右键此目录 → 新建资源 → 选 `SkillData`
2. 填写 `skill_id`、名称、描述
3. 设定稀有度和目标类型
4. 在 `params` 中定义效果参数（如 `{"damage_bonus": 2, "element": "fire"}`）
5. 保存为 `xxx.tres`
6. 在 `DiceManager` 的技能注册表中引用

### 已有技能（来自设计文档）

| 文件名 | 名称 | 目标 | 说明 |
|--------|------|------|------|
| `one_lock.tres` | 锁定 | DICE_FACE | 锁定指定面为固定值 |
| `one_enhance.tres` | 强化 | DICE_FACE | 指定面伤害 +2 |
| `fast_throw.tres` | 快速投掷 | PLAYER | 所有骰子冷却 -0.3s |
| `element_add.tres` | 元素附魔 | DICE_FACE | 给指定面添加元素属性 |
| `reroll.tres` | 重投 | DICE_WHOLE | 可选择重投一次 |
| `face_swap.tres` | 面交换 | DICE_FACE | 交换两个面的位置 |

## 注意事项

- `params` 是 Dictionary 类型，不同技能的参数结构不同，需要在 `DiceManager` 的技能处理逻辑中按 `skill_id` 分别解读
- 技能的实际执行逻辑在 `scripts/systems/dice_manager.gd` 中，不在数据文件里
- 技能效果可以叠加，同一技能多次获得时由 DiceManager 决定是叠加还是替换
