# data/recipes/ — 合成配方

## 目录职责

存放骰子合成配方的 `.tres` Resource 文件。定义哪些骰子可以合成为新骰子，以及合成结果。

## 数据结构

对应脚本类：`scripts/core/recipe_data.gd`（`RecipeData`）

### RecipeData 核心字段（预期）

| 字段 | 类型 | 说明 |
|------|------|------|
| `recipe_id` | StringName | 唯一标识 |
| `inputs` | Array[StringName] | 输入骰子 ID 列表 |
| `output` | StringName | 输出骰子 ID |
| `cost` | int | 合成金币消耗 |
| `description` | String | 配方描述 |

### 示例配方

```
火骰子 + 雷骰子 → 等离子骰子（fire_d6 + thunder_d6 → plasma_d6）
冰骰子 + 火骰子 → 蒸汽骰子（ice_d6 + fire_d6 → steam_d6）
铅骰子 + 铅骰子 → 钢骰子（leaded_d6 + leaded_d6 → steel_d6）
```

## 开发方式

### 新增配方

1. 右键此目录 → 新建资源 → 选 `RecipeData`
2. 设定 `inputs`（参与合成的骰子 ID 列表）
3. 设定 `output`（合成结果骰子 ID）
4. 设定 `cost`（合成金币消耗）
5. 保存为 `xxx.tres`

### 合成触发流程

```
玩家在合成台选择骰子
  → CraftingUI 发送合成请求
  → DiceManager.check_recipe(dice_a, dice_b)
  → 匹配 RecipeData
  → 扣除金币 + 移除输入骰子 + 添加输出骰子
```

## 注意事项

- 配方是**无序的**：A+B 和 B+A 应匹配同一条配方
- 合成消耗由 `RunState` 扣除金币、`DiceManager` 管理骰子池
- 合成台 UI 在 `scripts/ui/crafting_ui.gd`，场景在 `scenes/ui/crafting_ui.tscn`
