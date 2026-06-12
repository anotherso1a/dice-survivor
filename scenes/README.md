# scenes/ — 场景文件目录

## 目录职责

存放所有 Godot `.tscn` 场景文件。每个场景是一个可独立实例化的节点树，由脚本（`scripts/`）驱动逻辑，由数据（`data/`）提供配置。

> **核心原则**：每个场景可 F6 独立运行。不依赖父节点上下文，不假设兄弟节点的存在。

## 子目录

| 子目录 | 内容 | 对应脚本 |
|--------|------|---------|
| （根目录） | 主场景和流程场景 | `scripts/systems/` |
| `entities/` | 游戏实体场景 | `scripts/entities/` |
| `entities/enemies/` | 各种敌人场景 | `scripts/entities/enemy_base.gd` |
| `minigames/` | 小游戏场景 | `scripts/minigames/` |
| `ui/` | UI 界面场景 | `scripts/ui/` |
| `effects/` | 视觉特效场景 | `scripts/effects/` |

## 场景与脚本的对应关系

```
scenes/entities/player.tscn       ← scripts/entities/player.gd
scenes/entities/enemies/skeleton_basic.tscn ← scripts/entities/enemy_base.gd
scenes/ui/hud.tscn                 ← scripts/ui/hud.gd
scenes/minigames/baccarat.tscn     ← scripts/minigames/baccarat.gd
```

**规则**：每个 `.tscn` 必须有对应的 `.gd` 脚本，反向不强制（纯数据类不需要场景）。

## 开发方式

### 创建新场景

1. 在对应子目录中新建场景
2. 选择根节点类型（CharacterBody2D / Control / Node2D 等）
3. 挂载组件节点（从 `scenes/entities/` 中把组件场景拖入，或直接添加 Node + 脚本）
4. 连接信号（编辑器中或代码中）
5. F6 独立运行测试

### 场景实例化

```gdscript
# 在代码中实例化场景
var enemy_scene: PackedScene = load("res://scenes/entities/enemies/skeleton_basic.tscn")
var enemy: EnemyBase = enemy_scene.instantiate()
add_child(enemy)
enemy.global_position = spawn_pos
```

### 命名规范

- 场景文件用 `snake_case`：`skeleton_basic.tscn`、`level_up_ui.tscn`
- 与脚本文件名保持一致：`player.tscn` + `player.gd`
- 与数据文件名保持对应：`skeleton_basic.tscn` + `skeleton_basic.tres`

## 注意事项

- 场景中不应有硬编码的节点路径（用 `@onready` + `$NodeName` 替代）
- 组件节点的名称用 PascalCase：`HealthComponent`、`MovementComponent`
- 场景切换由 `GameManager` 管理，不要在其他地方调用 `get_tree().change_scene()`
