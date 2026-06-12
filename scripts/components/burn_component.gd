## 燃烧组件（可复用）— 持续伤害 DOT(Damage Over Time)
## 设计思想：将燃烧逻辑从 Enemy 中抽出为独立组件(Composition)，
## 适用于任何可被点燃的实体（敌人/Boss/甚至玩家）。
## 好处：组件可独立测试、可在不同实体间复用、修改燃烧机制不影响敌人基础逻辑。
##
## 挂载方式：作为实体的子节点。
## 实体脚本在收到含 fire 元素的骰面时调用 apply()。
##
## 逻辑：
##   - burn_stacks: 燃烧层数（骰面火元素每触发一次 +1）
##   - burn_timer: 距离下次跳伤害的倒计时（按 burn_interval 重置）
##   - 每层每 tick 造成 burn_damage 伤害（总伤害 = burn_stacks × burn_damage）
##
## 依赖：HealthComponent（通过 get_parent() 查找兄弟节点）
##
@tool                                          # @tool：编辑器模式下也运行
class_name BurnComponent                      # 注册为全局类型
extends Node                                  # 继承 Node：组件通常继承 Node 而非复杂类型


signal burn_ticked(damage: int)               # 每次燃烧跳伤害时发出（参数：本次伤害值）


@export_group("Config")
## 每层每 tick 造成的伤害（Inspector 中可调）
@export var burn_damage: int = 1
## 跳伤害间隔（秒），即两次燃烧伤害之间的时间
@export var burn_interval: float = 1.0

## 当前燃烧层数
## setter 写法：值被修改时自动执行 set 块
var burn_stacks: int = 0:
	set(v):
		burn_stacks = v                         # 先执行实际赋值
		if burn_stacks > 0 and burn_timer <= 0.0: # 有新层数且计时器未启动
			burn_timer = burn_interval          # 立即开始倒计时

## 计时器：距离下次跳伤害的剩余时间（秒），_physics_process 中每帧递减
var burn_timer: float = 0.0

## 对兄弟节点 HealthComponent 的缓存引用
## 在 _ready() 中通过 get_parent().get_node_or_null() 查找并赋值
var _health: HealthComponent                  # 类型声明为 HealthComponent，获得智能补全


func _ready() -> void:                        # 节点进入场景树时调用
	## 在父实体（如 Enemy）中查找 HealthComponent 兄弟节点
	var parent: Node = get_parent()           # get_parent()：获取当前节点的父节点
	_health = parent.get_node_or_null("HealthComponent") as HealthComponent # get_node_or_null：安全查找，找不到返回 null 而不报错
	if _health == null:                       # 找不到 HealthComponent 时的处理
		push_warning("BurnComponent: 父节点中找不到 HealthComponent，燃烧伤害将无法生效") # push_warning：输出黄色警告到控制台


func _physics_process(delta: float) -> void:  # _physics_process：与物理帧同步（默认60fps），用于游戏逻辑计时
	if burn_stacks <= 0:                      # 无燃烧层数 → 直接返回
		return
	if _health == null:                       # 没有 HealthComponent 引用 → 无法造成伤害，直接返回
		return

	burn_timer -= delta                       # delta：距上一物理帧的秒数，乘/减实现帧率无关计时
	if burn_timer <= 0.0:                     # 计时器归零：该跳伤害了
		burn_timer = burn_interval            # 重置计时器
		var dmg: int = burn_damage * burn_stacks # 伤害 = 每层伤害 × 层数
		_health.take_damage(dmg, false)       # 调用 HealthComponent 的受伤方法（非暴击）
		burn_ticked.emit(dmg)                 # 发射燃烧伤害信号（可用于特效/统计）
		## 层数随时间递减（可选，当前游戏未实现）
		## burn_stacks = max(0, burn_stacks - 1)


## 施加燃烧（由骰面 face.element == "fire" 触发）
## stacks：本次添加的燃烧层数（由 FaceData.element_power 决定）
func apply(stacks: int) -> void:
	burn_stacks += stacks                     # 累加层数
	burn_timer = burn_interval                # 立即开始第一跳倒计时（不等下次计时器归零）
	print("🔥 燃烧层数 +%d，当前 %d 层" % [stacks, burn_stacks]) # % 格式化字符串：[stacks, burn_stacks] 对应 %d, %d
