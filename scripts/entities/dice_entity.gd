## 骰子实体（场景中的骰子实例）
## 继承 Node2D：骰子是 2D 空间中的可见节点（需要位置/旋转）。
##
## 挂载在玩家节点下（作为子节点），跟随玩家移动。
## 职责：冷却管理 + 投掷逻辑 + 发出骰面数据。
## 对应旧文件：scripts/Dice.gd
## 迁移要点：
##   - rolled 信号：参数从 Dictionary → FaceData（强类型）
##   - 不再直接操作 DiceData 的 current_durability
##     （由 DiceData.roll_combat() 内部自管耐久度递减）
##   - DiceData.is_broken() 替代手动比较 durability <= 0
##
extends Node2D                              # 继承 Node2D：2D 空间中的基本节点


## rolled 信号：骰子投掷完成后发出，携带骰面数据和暴击标记
## 信号向上通信：骰子发出信号 → 玩家（父节点）连接并处理（如查找敌人、造成伤害）
signal rolled(face_data: FaceData, is_crit: bool)
signal cooldown_ready()                      # 冷却完毕信号（可用于 UI 提示）
signal broken()                              # 骰子损坏信号（耐久度归零）


## @onready：等价于 _ready() 中获取子节点引用，确保子节点就绪后才赋值
@onready var _dice_rect: Polygon2D = $DiceRect # 骰子外观（多边形绘制）
@onready var _label: Label = $DiceLabel        # 骰子冷却标签（显示倒计时）

var dice_data: DiceData:                    # 骰子数据引用（DiceData 是资源/数据类）
	set(v):                                  # setter：值被修改时自动执行
		dice_data = v                        # 执行赋值
		_update_label()                      # 自动更新标签显示

var owner_node: Node2D                      # 骰子的拥有者（通常是 Player 节点）

var _cooldown_timer: float = 0.0             # 冷却计时器（秒），> 0 表示冷却中，不能投掷


## 初始化骰子（由玩家在 _spawn_starting_dice 或 cycle_dice 中调用）
## data：骰子数据（DiceData）
## owner：骰子拥有者（Player 节点）
func setup(data: DiceData, owner: Node2D) -> void:
	dice_data = data                         # 绑定骰子数据（触发 setter → 更新标签）
	owner_node = owner                       # 记录拥有者引用
	_update_label()                          # 更新标签


## _process(delta)：与渲染帧同步，用于冷却计时和 UI 更新
## 这里用 _process 而非 _physics_process，因为冷却计时不需要物理帧同步精度
func _process(_delta: float) -> void:
	if dice_data == null:                    # 防御性检查：数据可能未绑定
		return
	if _cooldown_timer > 0:                  # 冷却中
		_cooldown_timer -= get_process_delta_time() # get_process_delta_time()：获取当前帧的 delta 值
		                                           # 在 _process 中用此方法代替 _delta 参数更准确
		if _cooldown_timer <= 0:             # 冷却刚好结束
			_cooldown_timer = 0              # 归零（防止出现微小的负数）
			cooldown_ready.emit()            # 发射冷却就绪信号（通知 UI 等）
	_update_label()                          # 每帧更新标签（显示倒计时）


## 更新骰子标签（显示当前冷却秒数）
func _update_label() -> void:
	if _label == null or dice_data == null:   # 防御性检查
		return
	_label.text = "🎲%.1f" % _cooldown_timer # %.1f：格式化浮点数为一位小数（如 "🎲2.3"）


## 检查骰子是否可以投掷（冷却完毕 + 未损坏）
func is_ready() -> bool:
	if dice_data == null:                    # 数据未绑定
		return false
	return _cooldown_timer <= 0              # 冷却计时器已归零


## 投掷骰子（核心逻辑）
## 返回：随机到的骰面数据（FaceData），如果冷却中/已损坏则返回 null
func roll() -> FaceData:
	if not is_ready():                        # 冷却中 → 不能投掷
		return null
	if dice_data.is_broken():                # is_broken()：检查骰子是否已损坏（耐久度≤0）
		return null

	_cooldown_timer = dice_data.cooldown     # 开始冷却（cooldown 是从 DiceData 读取的冷却时间）
	var face: FaceData = dice_data.roll_combat() # roll_combat()：随机一个骰面并扣除耐久度
	var is_crit: bool = face.is_crit if face != null else false # 三元表达式：判空后取暴击标记

	## 掷骰后检查是否损坏（耐久度用完 → 发射 broken 信号）
	if dice_data.durability > 0:             # 有耐久度上限（非无限骰子）
		if dice_data.is_broken():            # 本次掷骰后损坏
			broken.emit()                    # 发射损坏信号（通知玩家/UI）

	rolled.emit(face, is_crit)               # 发射投掷信号，携带骰面和暴击标记
	return face                              # 返回骰面数据供直接调用方使用


## 获取剩余冷却时间（供 UI 显示用）
func get_cooldown_remaining() -> float:
	return _cooldown_timer
