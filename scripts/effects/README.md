# scripts/effects/ — 视觉特效

## 目录职责

存放纯视觉特效脚本，负责伤害数字、出生警告、元素特效等视觉反馈。特效脚本是**只读观察者**——它们读取游戏状态来决定显示什么，但不影响游戏逻辑。

> **核心原则**：特效是果，不是因。特效脚本不改变任何游戏数据，只负责"让玩家看到发生了什么"。

## 包含文件

| 文件 | 类名 | 说明 |
|------|------|------|
| `damage_number.gd` | DamageNumber | 飘字（伤害数值 + 暴击/元素标记） |
| `spawn_warning.gd` | SpawnWarning | 出生点黄色闪烁警告 |
| `element_vfx.gd` | ElementVFX | 元素特效（火焰/冰霜/雷电） |
| `exp_orb.gd` | ExpOrb | 经验光芒（敌人死亡 → 抛物线飞向玩家，带拖尾 + 发光 shader） |
| `exp_orb_spawner.gd` | ExpOrbSpawner | 经验光芒生成器（监听 enemy_died 自动批量生成） |

## 与 EventBus 的关系

特效脚本通常通过订阅 EventBus 信号来触发：

```gdscript
# damage_number.gd
func _ready() -> void:
    EventBus.crit_triggered.connect(_on_crit)

func _on_crit(target: Node2D, damage: int) -> void:
    # 在目标位置创建飘字
    var label: Label = _create_label(str(damage), target.global_position)
    label.modulate = Color.YELLOW  # 暴击用黄色
```

## 依赖规则

```
effects 可以引用：core、utils
effects 不可引用：systems、components、entities
effects 通过 EventBus 监听事件，不直接引用游戏实体
```

## 新增特效流程

1. 创建 `.gd` 脚本，定义特效行为
2. 创建对应 `.tscn` 场景（`scenes/effects/`）
3. 在 EventBus 中添加触发信号（如需要）
4. 在需要触发特效的地方 emit 信号
5. 特效脚本订阅信号并创建视觉反馈

## 注意事项

- 特效节点用 `queue_free()` 自行回收，不需要外部管理
- 特效不应持有对游戏实体的长期引用（用完即释放）
- 性能敏感：大量同屏特效时注意对象池化（`_disable` → 重用而不是 `queue_free` → `instantiate`）
