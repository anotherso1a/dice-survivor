# scenes/minigames/ — 小游戏场景

## 目录职责

存放休息站中各赌博小游戏的 `.tscn` 场景文件。每个小游戏是独立的 Control 场景，由休息站动态加载。

## 场景文件

| 文件 | 脚本 | 说明 |
|------|------|------|
| `baccarat.tscn` | `scripts/minigames/baccarat.gd` | 比大小（百家乐简化版） |
| `liars_dice.tscn` | `scripts/minigames/liars_dice.gd` | 吹牛骰子 |
| `gold_flower.tscn` | `scripts/minigames/gold_flower.gd` | 炸金花 |
| `blackjack.tscn` | `scripts/minigames/blackjack.gd` | 21 点 |

## 开发方式

### 新增小游戏场景

1. 在此目录创建 `.tscn`，根节点 Control + 对应脚本
2. 设计 UI 布局（按钮/骰子展示区/结果显示区）
3. 在脚本中实现 `start()` 和 `_end_minigame()` 逻辑
4. 在休息站 UI 中添加入口按钮

### 休息站加载流程

```gdscript
# 休息站脚本中
func _start_minigame(scene_path: String) -> void:
    var scene: PackedScene = load(scene_path)
    var minigame: MinigameBase = scene.instantiate()
    add_child(minigame)
    minigame.minigame_finished.connect(_on_minigame_finished)
    minigame.start(RunState.dice_pool, RunState.coins)
```

## 注意事项

- 小游戏场景必须可 F6 独立运行（不依赖休息站上下文）
- 场景根节点必须是 Control（MinigameBase extends Control）
- 游戏结束只通过 `minigame_finished` 信号通知，不直接操作 RunState
