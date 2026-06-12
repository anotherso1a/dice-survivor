# data/ — 数据资源目录

## 目录职责

存放所有 `.tres` Resource 数据文件，是整个游戏**数据驱动**架构的核心。策划可以在 Godot 编辑器中直接创建、编辑这些资源，无需修改代码。

> **核心理念**：数据与逻辑分离。改数值改 `.tres`，改行为改 `.gd`。

## 子目录

| 子目录 | 内容 | 数据类 |
|--------|------|--------|
| `dice/` | 骰子配置 | `DiceData` + `FaceData` |
| `skills/` | 技能配置 | `SkillData` |
| `relics/` | 遗物配置 | `RelicData` |
| `enemies/` | 敌人配置 | `EnemyData` |
| `waves/` | 波次配置 | `WaveData` |
| `recipes/` | 合成配方 | `RecipeData` |

## 开发方式

### 新增数据资源

1. 在 Godot 编辑器中右键点击对应子目录 → **新建资源 (New Resource)**
2. 选择对应的 `class_name`（如 `DiceData`、`EnemyData`）
3. 在 Inspector 面板中填写属性
4. 保存为 `.tres` 文件

### 引用数据资源

```gdscript
# 在场景节点中导出引用
@export var enemy_data: EnemyData

# 或在代码中按路径加载
var dice: DiceData = load("res://data/dice/standard_d6.tres")
```

### 命名规范

- 文件名使用 `snake_case`，如 `standard_d6.tres`、`skeleton_basic.tres`
- 文件名应与数据中的 `id` 字段对应，方便查找
- 同类资源有变体时用下划线区分，如 `fire_d6.tres`、`ice_d6.tres`

## 注意事项

- `.tres` 文件是文本格式，可以被 Git 追踪和 diff
- 不要在 `.tres` 中存储运行时状态（如 `current_hp`），只存静态配置
- 运行时状态由 `RunState`（Autoload）和组件管理
- 如果后续需要 Mod 支持，可通过 `json_loader.gd` 将 `.tres` 导出为 JSON
