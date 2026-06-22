## 小游戏基类（MinigameBase）
##
## 所有休息站小游戏的统一接口。
## 继承此类，实现 _on_start() / _on_force_end()，
## 游戏结束时调用 _end_minigame(won, reward)。
##
## 生命周期：
##   start() → [玩游戏] → _end_minigame() → 发出 minigame_finished 信号 → 外部接收结果
##
class_name MinigameBase
extends Control

## 小游戏结束时发出，携带胜负与奖励字典
signal minigame_finished(result: Dictionary)

@export var minigame_name: String = ""
@export var difficulty: int = 0  ## 0=简单 1=普通 2=地狱

var _is_running: bool = false


## 外部调用开始小游戏
func start(player_dice: Array[DiceData], bet: int) -> void:
	_is_running = true
	_on_start(player_dice, bet)


## 强制结束（ESC/B 退出）
func force_end() -> void:
	if not _is_running:
		return
	_is_running = false
	_on_force_end()
	minigame_finished.emit({"won": false, "reward": {}})


## 子类实现：游戏正式开始逻辑
func _on_start(_player_dice: Array[DiceData], _bet: int) -> void:
	pass


## 子类实现：强制退出时清理逻辑（可选覆写）
func _on_force_end() -> void:
	pass


## 子类在游戏自然结束时调用此方法
func _end_minigame(won: bool, reward: Dictionary) -> void:
	if not _is_running:
		return
	_is_running = false
	minigame_finished.emit({"won": won, "reward": reward})
