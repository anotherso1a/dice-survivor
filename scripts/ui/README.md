# scripts/ui/ — UI 脚本

## 目录职责

存放所有 UI 界面的控制脚本。UI 脚本只负责**展示数据和转发用户操作**，不包含任何游戏逻辑。数据来源是 EventBus 信号和 RunState，用户操作通过信号或调用系统方法转发。

> **核心原则**：UI 是镜子，不是大脑。UI 只反映状态，不产生状态。按按钮 → 发信号/调方法 → 逻辑在别处执行。

## 包含文件

| 文件 | 类名 | 说明 |
|------|------|------|
| `hud.gd` | HUD | 战斗 HUD（血条/骰子槽/波次信息） |
| `level_up_ui.gd` | LevelUpUI | 三选一升级界面 |
| `rest_station_ui.gd` | RestStationUI | 休息站主界面 |
| `dice_inventory_ui.gd` | DiceInventoryUI | 骰子背包查看/管理 |
| `crafting_ui.gd` | CraftingUI | 合成台界面 |
| `game_over_ui.gd` | GameOverUI | 结算/死亡界面 |

## UI 数据绑定模式

```gdscript
# hud.gd 示例
extends Control

@onready var hp_bar: ProgressBar = $HpBar
@onready var coins_label: Label = $CoinsLabel

func _ready() -> void:
    # 订阅 EventBus 获取数据更新
    EventBus.player_hp_changed.connect(_on_hp_changed)
    EventBus.coins_changed.connect(_on_coins_changed)

func _on_hp_changed(new_hp: int, max_hp: int) -> void:
    hp_bar.max_value = max_hp
    hp_bar.value = new_hp

func _on_coins_changed(new_amount: int) -> void:
    coins_label.text = str(new_amount)
```

## 依赖规则

```
ui 可以引用：core、systems（EventBus/RunState）、utils
ui 不可引用：components、entities、effects、minigames
ui 绝不可：直接引用或 get_node() 到游戏实体节点
```

## 新增 UI 流程

1. 创建 `.gd` 脚本，`extends Control`
2. 创建对应 `.tscn` 场景（`scenes/ui/`）
3. 在 `_ready()` 中订阅需要的 EventBus 信号
4. 在 `_exit_tree()` 中断开信号连接
5. 按钮操作通过 EventBus 发信号或调用系统方法

## 注意事项

- UI 场景应该能在编辑器中 F6 独立打开（不崩溃）
- 避免在 UI 脚本中做游戏逻辑计算，委托给 systems 或 components
- 动画用 Tween 或 AnimationPlayer，不用 `_process` 轮询
- 退出界面时必须断开所有 EventBus 信号连接，防止内存泄漏
