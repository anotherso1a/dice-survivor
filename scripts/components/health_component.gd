## 血量组件（可复用）— 使用组件模式(Composition)而非继承
## 设计思想：将 HP 管理抽象为独立节点，挂载在 Player/Enemy 场景的子节点下。
## 为什么不用继承？如果 Player 继承 LivingEntity 基类，就不能再继承 CharacterBody2D，
## 而组件模式(Composition)可以让任意节点类型复用 HealthComponent，
## 并且组件可独立测试、可热插拔（运行时可替换）、符合"多用组合少用继承"的设计原则。
##
## 挂载方式：作为实体（Player/Enemy）的子节点。
## 实体脚本在 _ready() 中连接信号。
##
## 信号（信号向上通信）：
##   组件不直接调用 get_parent().do_something()，而是通过 signal 通知父节点。
##   父节点在 _ready() 中连接这些信号，实现了松耦合——组件不需要知道父节点是谁。
##   hp_changed(new_hp, max_hp) — HP 变化（含受伤/治疗）
##   died                       — HP 归零（只发一次，用 _is_dead 防止重复触发）
##   damaged(dmg, is_crit)     — 受伤瞬间（用于触发受击特效）
##
@tool                                          # @tool 标记：使脚本在编辑器中也运行，方便在 Inspector 中预览
class_name HealthComponent                    # class_name：注册为全局类型，其他地方可直接声明变量类型
extends Node                                  # 继承 Node：组件不一定需要继承特定类型，Node 足够


signal hp_changed(new_hp: int, max_hp: int)
signal died
signal damaged(dmg: int, is_crit: bool)


@export_group("Stats")                        # @export_group：在 Inspector 面板中创建分组标签
@export var max_hp: int = 10:                 # @export：变量暴露到 Inspector，值可调；setter 在值变更时执行
	set(v):                                   # setter 函数，v 是赋入的新值
		max_hp = v                            # 先执行实际赋值
		if current_hp > 0 and is_inside_tree(): # is_inside_tree()：判断节点是否在场景树中（_ready 之前为 false）
			hp_changed.emit(current_hp, max_hp) # 发射信号：通知 HP 条等 UI 刷新

## 当前 HP（运行时变量，不 @export，Inspector 中不可见）
var current_hp: int = 0

## 是否已死亡（防止重复触发 died 信号）
var _is_dead: bool = false                    # _ 前缀：GDScript 约定，表示私有变量（仅本脚本访问）


func _ready() -> void:                        # _ready()：节点进入场景树时调用一次，所有 @onready 变量在此时已就绪
	current_hp = max_hp                       # 初始化当前 HP 为最大 HP
	hp_changed.emit(current_hp, max_hp)       # 通知 UI 初始 HP 值


## 受到伤害（由外部调用，如玩家骰子命中敌人）
func take_damage(dmg: int, is_crit: bool = false) -> void: # 默认参数 is_crit=false，调用方可省略
	if _is_dead:                              # 已死亡则忽略伤害（防止死亡后继续扣血）
		return
	if dmg <= 0:                              # 伤害≤0 也忽略（防止负伤害=治疗绕过 heal()）
		return

	current_hp = max(0, current_hp - dmg)     # max(0, ...)：保证 HP 不低于 0（不会出现负 HP）
	hp_changed.emit(current_hp, max_hp)       # 发射 HP 变化信号 → UI 更新血条
	damaged.emit(dmg, is_crit)                # 发射受伤瞬间信号 → 触发受击闪红/特效

	if current_hp <= 0:                       # HP 归零
		_is_dead = true                       # 标记死亡，防止重复触发
		died.emit()                           # 发射死亡信号 → 父节点执行死亡流程


## 治疗（如拾取血瓶）
func heal(amount: int) -> void:
	if _is_dead:                              # 死亡后不能治疗
		return
	current_hp = min(max_hp, current_hp + amount) # min(max_hp, ...)：保证 HP 不超过上限
	hp_changed.emit(current_hp, max_hp)       # 通知 UI 刷新


## 重置为满血（重生/新关卡开始时调用）
func reset() -> void:
	_is_dead = false                          # 取消死亡标记
	current_hp = max_hp                       # HP 回满
	hp_changed.emit(current_hp, max_hp)       # 通知 UI 刷新
