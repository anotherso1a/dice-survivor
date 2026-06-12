# scenes/effects/ — 视觉特效场景

## 目录职责

存放视觉特效的 `.tscn` 场景文件。特效场景通常是轻量级的，由代码动态实例化和回收。

## 场景文件

| 文件 | 脚本 | 说明 |
|------|------|------|
| `damage_number.tscn` | `scripts/effects/damage_number.gd` | 伤害飘字 |
| `spawn_warning.tscn` | `scripts/effects/spawn_warning.gd` | 出生点黄色警告 |

## 开发方式

特效场景通常在代码中按需实例化：

```gdscript
var damage_scene: PackedScene = load("res://scenes/effects/damage_number.tscn")
var dmg_num: DamageNumber = damage_scene.instantiate()
add_child(dmg_num)
dmg_num.global_position = target_pos
dmg_num.show_damage(42, true)  # 42 暴击
```

## 注意事项

- 特效播完后由脚本自动 `queue_free()`
- 高频特效（如大量飘字）考虑对象池化
