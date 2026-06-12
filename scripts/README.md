# scripts/ — 脚本目录

## 目录职责

存放所有 GDScript 脚本文件，按功能职责划分为 8 个子目录。每个子目录有明确的职责边界，脚本之间通过信号和导出引用通信，不直接跨目录引用内部实现。

## 子目录总览

| 子目录 | 职责 | 基类约束 | 可引用 | 被引用 |
|--------|------|---------|--------|--------|
| `core/` | 纯数据类（Resource/RefCounted） | 必须 extends Resource | 无限制 | 所有目录 |
| `systems/` | Autoload 全局单例 | 必须 extends Node | core, utils | 所有目录 |
| `components/` | 可复用行为组件 | 必须 extends Node | core, utils | entities |
| `entities/` | 游戏实体主脚本 | CharacterBody2D / Area2D | core, components, utils | scenes |
| `minigames/` | 休息站小游戏 | 必须 extends MinigameBase | core, systems, utils | scenes/minigames |
| `effects/` | 视觉特效 | Node2D / Control | core, utils | scenes/effects |
| `ui/` | UI 脚本 | Control | core, systems | scenes/ui |
| `utils/` | 工具函数（静态为主） | RefCounted / Object | 无 | 所有目录 |

## 依赖规则（重要！）

```
core ← systems ← entities
       ↑           ↑
     utils ← components
                ↑
             effects / ui / minigames
```

- **core** 和 **utils** 是最底层，不依赖任何其他脚本目录
- **systems**（Autoload）可以引用 core 和 utils，但不能引用 entities / components
- **components** 可以引用 core 和 utils，但不能引用 entities / systems
- **entities** 可以引用 core / components / utils，但不直接引用 systems（通过 EventBus 通信）
- **ui / effects / minigames** 可以引用 core / systems / utils

## 开发规范

### 文件命名

- 全部 `snake_case`：`health_component.gd`、`enemy_base.gd`
- `class_name` 用 `PascalCase`：`HealthComponent`、`EnemyBase`
- 文件名与 class_name 对应：`health_component.gd` → `class_name HealthComponent`

### 代码规范

- 所有变量、参数、返回值必须显式类型标注
- 信号参数必须带类型：`signal hp_changed(new_hp: int, max_hp: int)`
- `@onready` 引用节点必须带类型：`@onready var health: HealthComponent = $HealthComponent`
- 常量用 `SCREAMING_SNAKE_CASE`：`MAX_HP`、`SPAWN_MARGIN`

### 新增脚本流程

1. 确定职责归属哪个子目录
2. 创建 `.gd` 文件，声明 `class_name`
3. 选择正确的 `extends` 基类
4. 只引用允许依赖的目录中的类
5. 跨目录通信通过信号或 EventBus，不直接 `get_node()` 跨目录节点
