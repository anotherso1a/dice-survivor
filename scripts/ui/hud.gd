## HUD 界面脚本
##
## 本脚本负责游戏中所有 UI 信息的显示，挂载在 HUD 节点上。
## 核心设计原则：HUD 不直接引用 Player 或 Enemy 节点，而是通过订阅
## EventBus 的信号来获取游戏数据，实现 UI 与游戏逻辑的完全解耦。
## 挂载节点：scenes/ui/HUD.tscn
## 对应旧文件：scripts/HUD.gd
## 迁移要点：
##   - 击杀计数 → 订阅 EventBus.kill_count_changed
##   - 后续 M2 加入 HP 条、骰子 CD 显示等
##
## CanvasLayer 说明：
##   CanvasLayer 是 Godot 中专门用于 UI 的节点基类，它会创建一个
##   独立的渲染图层，确保 HUD 永远渲染在游戏世界的最上层，
##   不受摄像机缩放、移动或旋转的影响，是 UI 节点的标准挂载方式。
##
extends CanvasLayer  # 继承 CanvasLayer，使 HUD 始终渲染在最上层，不受摄像机影响


# ========== 节点引用（@onready 在 _ready() 前自动赋值）==========
# @onready：节点进入场景树时自动初始化，等价于在 _ready() 里手动 get_node()
# $ScoreLabel：通过节点路径获取子节点，等价于 get_node("ScoreLabel")
# : Label：类型注解，Godot 4 静态类型系统，提供代码补全和错误检查
@onready var _score_label: Label = $ScoreLabel  # 绑定场景树中的 ScoreLabel 节点，用于显示击杀数
@onready var _instructions: Label = $Instructions  # 绑定 Instructions 节点，显示操作提示文字
@onready var _tip: Label = $Tip  # 绑定 Tip 节点，显示额外的提示信息


## _ready() 是 Godot 的生命周期回调，节点首次进入场景树时自动调用一次
## 这里的职责是订阅 EventBus 信号，建立 HUD 与游戏逻辑的通信桥梁
func _ready() -> void:
	# EventBus.kill_count_changed 是游戏全局事件总线上的信号
	# HUD 通过 connect() 订阅此信号，当击杀数变化时 EventBus 会自动通知 HUD
	# _on_kill_count_changed 是本脚本中的回调函数，信号触发时自动调用
	EventBus.kill_count_changed.connect(_on_kill_count_changed)  # 订阅击杀数变化信号
	# 订阅玩家 HP 变化信号，当玩家受伤或治疗时 HUD 收到通知，目前留空待 M2 实现血条
	EventBus.player_hp_changed.connect(_on_player_hp_changed)  # 订阅玩家 HP 变化信号
	print("✅ HUD ready")  # 控制台输出调试信息，确认 HUD 初始化完成


## 击杀计数更新回调
## 当 EventBus 发出 kill_count_changed 信号时，此函数被自动调用
## new_count: 最新的击杀总数，由 EventBus 在 emit 时传入
func _on_kill_count_changed(new_count: int) -> void:
	# 更新 ScoreLabel 的文本内容，"击杀: %d" 是格式化字符串，%d 会被 new_count 替换
	_score_label.text = "击杀: %d" % new_count  # 将最新击杀数显示到 UI 标签上


## 玩家 HP 更新回调（后续 M2 接入血条 UI）
## _new_hp: 玩家当前生命值；_max_hp: 玩家最大生命值
## 前缀 _ 表示参数在函数体内未被使用，仅用于匹配信号签名，避免编译器警告
func _on_player_hp_changed(_new_hp: int, _max_hp: int) -> void:
	pass  # 留待 M2 实现血条，目前暂不处理 HP 变化


## 外部调用（兼容旧逻辑，后续移除）
## 供其他节点直接调用以增加击杀计数，是旧架构的兼容接口
## 新架构应通过 EventBus.kill_count_changed 信号驱动
func add_kill() -> void:
	# RunState 是全局单例（Autoload），存储当前游戏运行状态（击杀数、时长等）
	# kill_count += 1 等价于 kill_count = kill_count + 1
	RunState.kill_count += 1  # 全局击杀计数 +1
