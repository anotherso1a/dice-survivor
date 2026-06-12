## 当局运行时状态（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 RunState.xxx 直接访问。
##
## 持有单局游戏的所有运行时数据。
## 重开新局时调用 reset() 清零。
##
## 对应旧代码中的数据：
##   - Player.gd 中的 hp、_dice_pool
##   - Main.gd 中的 _kills（通过 EventBus 间接）
##   - 后续 M2 加入的金币、遗物等
##
extends Node  # 继承 Node 基类；作为 Autoload 挂载到场景树根节点下


signal state_reseted  # 自定义信号：当运行时状态被重置时触发，供各 UI 订阅以刷新显示


## ========== 玩家状态 ==========
## 【setter 函数模式】
## var x: int = 0: set(v): x = v; signal.emit()
## 当外部对 player_hp 赋值时，set 函数自动执行：
##   1. 将新值写入 player_hp
##   2. 通过 EventBus 发射 player_hp_changed 信号
## 这样任何地方修改 HP 都会自动通知血条 UI 刷新，无需手动调用更新。
var player_hp: int = Constants.PLAYER_MAX_HP:  # 玩家当前血量，初始值为常量中的最大血量
	set(v):  # setter：当 player_hp 被赋值时自动调用，参数 v 为新值
		player_hp = v  # 将新值写入 player_hp
		EventBus.player_hp_changed.emit(player_hp, player_max_hp)  # 通过信号总线发射血量变化信号，血条 UI 等监听方自动响应

var player_max_hp: int = Constants.PLAYER_MAX_HP  # 玩家最大血量，初始值为常量中的最大血量（无 setter，不自动发信号）

## ========== 骰子背包 ==========
## 玩家当前持有的骰子数据列表（运行时）
var dice_pool: Array[DiceData] = []  # 骰子背包：存储 DiceData 类型的数组，初始为空

## ========== 经济 ==========
var coins: int = 0:  # 玩家当前金币数，初始为 0
	set(v):  # setter：当 coins 被赋值时自动调用
		coins = v  # 将新值写入 coins
		EventBus.coins_changed.emit(coins)  # 通过信号总线发射金币变化信号，金币 UI 等监听方自动响应

## ========== 击杀计数 ==========
var kill_count: int = 0:  # 玩家当前击杀数，初始为 0
	set(v):  # setter：当 kill_count 被赋值时自动调用
		kill_count = v  # 将新值写入 kill_count
		EventBus.kill_count_changed.emit(kill_count)  # 通过信号总线发射击杀数变化信号，HUD 击杀计数显示自动响应

## ========== 遗物列表 ==========
var relics: Array[RelicData] = []  # 玩家当前持有的遗物列表，初始为空


## 【_ready() 生命周期】
## 节点进入场景树后自动调用。此处调用 reset() 确保运行时状态从零开始。
func _ready() -> void:
	reset()  # 初始化所有运行时状态


## 重开新局时调用，清零所有运行时状态
func reset() -> void:
	player_hp = Constants.PLAYER_MAX_HP  # 重置玩家当前血量为最大值（通过 setter 自动发射 player_hp_changed 信号）
	player_max_hp = Constants.PLAYER_MAX_HP  # 重置玩家最大血量
	dice_pool.clear()  # 清空骰子背包
	coins = 0  # 重置金币为 0（通过 setter 自动发射 coins_changed 信号）
	kill_count = 0  # 重置击杀数为 0（通过 setter 自动发射 kill_count_changed 信号）
	relics.clear()  # 清空遗物列表
	state_reseted.emit()  # 发射状态重置信号，通知所有订阅方刷新显示


## 初始化骰子池（MVP 从 DiceManager 获取初始骰子）
func init_dice_pool() -> void:
	dice_pool.clear()  # 先清空骰子背包，防止重复添加
	dice_pool.append(DiceManager.get_standard_d6())  # 添加标准骰子（通过 DiceManager Autoload 单例获取）
	dice_pool.append(DiceManager.get_leaded_d6())  # 添加灌铅骰子
	dice_pool.append(DiceManager.get_glass_d6())  # 添加玻璃骰子
	dice_pool.append(DiceManager.get_fire_d6())  # 添加火焰骰子
	print("✅ RunState：骰子池初始化完成，共 %d 个" % dice_pool.size())  # 控制台输出日志，显示骰子池大小
