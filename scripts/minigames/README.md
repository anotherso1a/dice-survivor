# scripts/minigames/ — 休息站小游戏

## 目录职责

存放休息站中所有赌博小游戏的脚本。每个小游戏是一个独立场景，通过 `MinigameBase` 基类统一接口，由休息站场景动态加载和管理。

> **核心原则**：小游戏之间完全独立，互不知道对方存在。统一通过 MinigameBase 接口与休息站通信。

## 包含文件

| 文件 | 类名 | 说明 |
|------|------|------|
| `minigame_base.gd` | MinigameBase | 基类：定义 start()/force_end() 接口和 minigame_finished 信号 |
| `baccarat.gd` | Baccarat | 比大小（百家乐简化版） |
| `liars_dice.gd` | LiarsDice | 吹牛骰子 |
| `gold_flower.gd` | GoldFlower | 炸金花 |
| `blackjack.gd` | Blackjack | 21 点 |

## 基类接口

```gdscript
class_name MinigameBase
extends Control

signal minigame_finished(result: Dictionary)

@export var minigame_name: String = ""
@export var difficulty: int = 0    # 0=简单 1=普通 2=地狱

var _is_running: bool = false

## 开始游戏 — 子类必须实现
func start(player_dice: Array[DiceData], bet: int) -> void:
    _is_running = true

## 强制结束（玩家退出休息站时调用）
func force_end() -> void:
    _is_running = false
    minigame_finished.emit({"won": false, "reward": {}})

## 子类在游戏结束时必须调用
func _end_minigame(won: bool, reward: Dictionary) -> void:
    _is_running = false
    minigame_finished.emit({"won": won, "reward": reward})
```

## 休息站加载流程

```
休息站 UI
  ├─ 玩家选择小游戏
  ├─ 调用 _start_minigame("res://scenes/minigames/baccarat.tscn")
  │    ├─ instantiate() → MinigameBase
  │    ├─ add_child(minigame)
  │    ├─ 连接 minigame_finished 信号
  │    └─ minigame.start(RunState.dice_pool, RunState.coins)
  └─ _on_minigame_finished(result)
       ├─ result.won == true → 发放奖励
       └─ result.won == false → 扣血/扣钱
```

## result Dictionary 格式

```gdscript
{
    "won": true,                       # 是否赢了
    "reward": {
        "coins": 50,                   # 金币奖励
        "dice": [dice_data],           # 骰子奖励（可选）
        "relic": relic_data,           # 遗物奖励（可选）
    }
}
```

## 依赖规则

```
minigames 可以引用：core、systems（EventBus/RunState）、utils
minigames 不可引用：components、entities、effects
minigames 之间：不可互相引用
```

## 新增小游戏流程

1. 创建 `.gd` 文件，`extends MinigameBase`
2. 实现 `start()` 方法（初始化游戏状态）
3. 在游戏结束时调用 `_end_minigame(won, reward)`
4. 创建对应 `.tscn` 场景（`scenes/minigames/`）
5. 在休息站 UI 中注册入口

## 注意事项

- 小游戏是**独立场景**，可以在编辑器中 F6 单独调试
- `force_end()` 必须正确清理所有定时器和动画
- 小游戏中不直接修改 RunState，通过 `minigame_finished` 信号返回结果，由休息站统一处理
- 赌博模式使用的骰面（`gamble_faces`）由 `DiceData` 定义，小游戏脚本按规则解读
