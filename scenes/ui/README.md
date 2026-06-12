# scenes/ui/ — UI 场景

## 目录职责

存放所有 UI 界面的 `.tscn` 场景文件。UI 场景的根节点是 Control，由脚本订阅 EventBus 信号来更新展示内容。

## 场景文件

| 文件 | 脚本 | 说明 |
|------|------|------|
| `hud.tscn` | `scripts/ui/hud.gd` | 战斗 HUD（血条/骰子槽/波次/金币） |
| `level_up_ui.tscn` | `scripts/ui/level_up_ui.gd` | 三选一升级弹窗 |
| `rest_station_ui.tscn` | `scripts/ui/rest_station_ui.gd` | 休息站主界面 |
| `dice_inventory_ui.tscn` | `scripts/ui/dice_inventory_ui.gd` | 骰子背包 |
| `crafting_ui.tscn` | `scripts/ui/crafting_ui.gd` | 合成台 |
| `game_over_ui.tscn` | `scripts/ui/game_over_ui.gd` | 结算/死亡 |

## 开发方式

### 新增 UI 场景

1. 在此目录创建 `.tscn`，根节点 Control + 对应脚本
2. 使用 Godot 的 Container 布局节点（VBoxContainer / HBoxContainer / MarginContainer）
3. 在脚本 `_ready()` 中订阅 EventBus 信号
4. 在脚本 `_exit_tree()` 中断开信号
5. 按钮操作通过调用系统方法或发射 EventBus 信号

## 注意事项

- UI 场景不直接引用游戏实体节点，所有数据来自 EventBus 信号
- 布局使用 Container 自动管理，避免手动定位
- 动画使用 Tween 或 AnimationPlayer
