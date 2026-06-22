## 状态组件 - 管理敌人的元素效果（冰冻、点燃、减速等）
## 挂载到 EnemyBase 作为子节点
class_name StatusComponent
extends Node

signal status_changed(status_type: StringName, is_active: bool)
signal burn_tick(damage: int)

@export_group("调试")
@export var debug: bool = false

var _active_status: Dictionary = {}  # {status_type: StatusData}
var _timers: Dictionary = {}  # {status_type: Timer}

## 应用冰冻效果
func apply_freeze(duration: float, chance: float = 1.0) -> void:
	if randf() > chance:
		return  # 概率失败
	
	if debug:
		print("[Status] 应用冰冻 | 持续时间: %.1fs | 概率: %.0f%%" % [duration, chance * 100])
	
	_add_status(&"freeze", duration)

## 应用点燃效果
func apply_burn(duration: float, tick_interval: float = 0.5, damage: int = 1) -> void:
	if debug:
		print("[Status] 应用点燃 | 持续时间: %.1fs | 伤害: %d/%.1fs" % [duration, damage, tick_interval])
	
	_add_status(&"burn", duration, {tick_interval: tick_interval, damage: damage})

## 应用减速效果
func apply_slow(duration: float, factor: float = 0.5) -> void:
	if debug:
		print("[Status] 应用减速 | 持续时间: %.1fs | 减速因子: %.0f%%" % [duration, factor * 100])
	
	_add_status(&"slow", duration, {factor: factor})

## 添加状态
func _add_status(status_type: StringName, duration: float, extra_data: Dictionary = {}) -> void:
	# 如果状态已存在，刷新持续时间
	if _active_status.has(status_type):
		_active_status[status_type].duration = duration
		_timers[status_type].wait_time = duration
		_timers[status_type].start()
		if debug:
			print("[Status] 刷新状态: %s | 新持续时间: %.1fs" % [status_type, duration])
		return
	
	# 创建新状态
	var status_data: Dictionary = {
		duration = duration,
		start_time = Time.get_time_dict_from_system()
	}
	status_data.merge(extra_data)
	_active_status[status_type] = status_data
	
	# 创建计时器
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_status_timeout.bind(status_type))
	add_child(timer)
	timer.start()
	_timers[status_type] = timer
	
	# 应用状态效果
	_apply_status_effect(status_type, true)
	
	status_changed.emit(status_type, true)
	
	if debug:
		print("[Status] 新状态: %s | 持续时间: %.1fs" % [status_type, duration])

## 移除状态
func _remove_status(status_type: StringName) -> void:
	if not _active_status.has(status_type):
		return
	
	# 移除状态效果
	_apply_status_effect(status_type, false)
	
	# 清理计时器
	if _timers.has(status_type):
		_timers[status_type].queue_free()
		_timers.erase(status_type)
	
	# 清理状态数据
	_active_status.erase(status_type)
	
	status_changed.emit(status_type, false)
	
	if debug:
		print("[Status] 状态结束: %s" % status_type)

## 应用/移除状态效果
func _apply_status_effect(status_type: StringName, is_apply: bool) -> void:
	var parent = get_parent()
	if not parent or not parent.has_method("set"):
		return
	
	match status_type:
		&"freeze":
			# 冰冻：暂停敌人的移动和攻击
			if parent.has_method("set_physics_process"):
				parent.set_physics_process(not is_apply)
			if debug:
				print("[Status] 冰冻 %s" % ("应用" if is_apply else "移除"))
		
		&"slow":
			# 减速：修改敌人的移动速度
			if parent.has_method("get") and parent.has_method("set"):
				var current_speed = parent.get("move_speed") if parent.get("move_speed") else 150.0
				if is_apply:
					var factor = _active_status[status_type].get("factor", 0.5)
					parent.set("move_speed", current_speed * factor)
				else:
					# TODO: 需要保存原始速度，这里简化为重置为 150
					parent.set("move_speed", 150.0)
				if debug:
					print("[Status] 减速 %s | 速度: %.0f" % ["应用" if is_apply else "移除", parent.get("move_speed")])
		
		&"burn":
			# 点燃：启动/停止 Tick 计时器
			if is_apply:
				_start_burn_tick()
			else:
				_stop_burn_tick()

## 启动点燃 Tick
func _start_burn_tick() -> void:
	if not _active_status.has(&"burn"):
		return
	
	var tick_interval: float = _active_status[&"burn"].get("tick_interval", 0.5)
	
	# 创建 Tick 计时器（如果不存在）
	if not _timers.has(&"burn_tick"):
		var tick_timer: Timer = Timer.new()
		tick_timer.wait_time = tick_interval
		tick_timer.timeout.connect(_on_burn_tick)
		add_child(tick_timer)
		tick_timer.start()
		_timers[&"burn_tick"] = tick_timer
	else:
		_timers[&"burn_tick"].wait_time = tick_interval
		_timers[&"burn_tick"].start()

## 停止点燃 Tick
func _stop_burn_tick() -> void:
	if _timers.has(&"burn_tick"):
		_timers[&"burn_tick"].stop()

## 点燃 Tick
func _on_burn_tick() -> void:
	if not _active_status.has(&"burn"):
		_stop_burn_tick()
		return
	
	var damage: int = _active_status[&"burn"].get("damage", 1)
	burn_tick.emit(damage)
	
	if debug:
		print("[Status] 点燃伤害: %d" % damage)

## 状态超时
func _on_status_timeout(status_type: StringName) -> void:
	_remove_status(status_type)

## 获取状态信息
func has_status(status_type: StringName) -> bool:
	return _active_status.has(status_type)

func get_status_duration(status_type: StringName) -> float:
	if _active_status.has(status_type):
		return _active_status[status_type].get("duration", 0.0)
	return 0.0

## 清理
func _exit_tree() -> void:
	for status_type in _active_status.keys():
		_remove_status(status_type)
