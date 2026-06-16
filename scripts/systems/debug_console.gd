## 调试控制台（Autoload / Singleton）
##
## 在 project.godot 中注册为 Autoload，按 ~ 键切换显示/隐藏。
## 功能类似杀戮尖塔的内置控制台，通过文本命令操控游戏状态，
## 方便开发阶段的调试、测试和快速迭代。
##
## 使用方式：
##   1. 游戏运行时按 ~ 键打开控制台
##   2. 输入命令（如 `hp 50`、`god`、`kill_all`）
##   3. 按 Enter 执行，按 ~ 再次关闭
##
## 命令系统说明：
##   每个命令是一个 Callable + 描述文本，注册在 _commands 字典中。
##   新增命令只需在 _register_commands() 中添加一行即可。
##
## 架构：
##   - 命令注册与执行 → 本 Autoload 负责
##   - UI 展示 → 程序化创建 CanvasLayer + 控件节点
##   - 输入映射 → project.godot 中注册 debug_console action
extends Node


## ========== 命令注册 ==========

## 命令字典：key=命令名（String），value={ "callable": Callable, "desc": "描述", "usage": "用法" }
var _commands: Dictionary = {}

## 命令历史（用于上下键翻找）
var _history: Array[String] = []
var _history_index: int = -1

## ========== UI 节点引用 ==========

var _ui_layer: CanvasLayer = null
var _output: RichTextLabel = null
var _input: LineEdit = null
var _is_open: bool = false

## 常驻日志缓冲区（控制台关闭期间也在记录，打开后能看到历史）
var _log_buffer: Array[String] = []
const MAX_LOG_LINES: int = 200


func _ready() -> void:
	# 设为 PROCESS_MODE_ALWAYS：暂停游戏后 _unhandled_input 依然能接收输入，
	# 否则 ~ 键无法关闭控制台，等于死锁。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_commands()
	_create_ui()
	_console_log("[系统] 调试控制台就绪。输入 help 查看可用命令。")


## 帧循环：检测 ~ 键切换控制台，以及在控制台打开时处理上下键历史翻找

## _unhandled_input 只接收未被 UI 控件消费的输入事件。
## LineEdit 有焦点时会自动消费键盘事件，所以打字时的 ~ / ↑↓ 不会触发这里，
## 从而彻底避免控制台快捷键与输入内容冲突。
func _unhandled_input(event: InputEvent) -> void:
	# ~ 键切换（仅当事件未被 LineEdit 消费时才触发）
	if event.is_action_pressed("debug_console"):
		_toggle()
		get_viewport().set_input_as_handled()  # 彻底吞掉，防止穿透
		return

	# 控制台关闭时不处理其余快捷键
	if not _is_open:
		return

	# ↑ 上一个命令（仅当输入框不在焦点时，否则 LineEdit 用它移动光标）
	if event.is_action_pressed("ui_up") and not _input.has_focus():
		if _history.size() > 0:
			_history_index = max(0, _history_index - 1)
			_input.text = _history[_history_index]
			_input.caret_column = _input.text.length()
			get_viewport().set_input_as_handled()

	# ↓ 下一个命令
	if event.is_action_pressed("ui_down") and not _input.has_focus():
		if _history_index < _history.size() - 1:
			_history_index += 1
			_input.text = _history[_history_index]
			_input.caret_column = _input.text.length()
			get_viewport().set_input_as_handled()
		else:
			_history_index = _history.size()
			_input.text = ""
			get_viewport().set_input_as_handled()


## ========== 公共 API ==========

## 向控制台输出一行文本（无论控制台是否打开）
func _console_log(msg: String) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	var line: String = "[%s] %s" % [timestamp, msg]
	_log_buffer.append(line)

	# 限制缓冲区大小
	while _log_buffer.size() > MAX_LOG_LINES:
		_log_buffer.pop_front()

	# 如果 UI 已打开且输出控件就绪，实时追加
	if _output != null and _is_open:
		_output.append_text(line + "\n")


## 切换控制台开关
func _toggle() -> void:
	_is_open = not _is_open
	_ui_layer.visible = _is_open

	if _is_open:
		_open()
	else:
		_close()


func _open() -> void:
	# 暂停游戏：即时战斗中打开控制台必须暂停，否则敌人继续攻击、玩家可能死亡
	get_tree().paused = true

	# 刷新历史输出到界面
	_output.clear()
	for line in _log_buffer:
		_output.append_text(line + "\n")

	# 聚焦输入框
	_input.text = ""
	_history_index = _history.size()
	_input.grab_focus()


func _close() -> void:
	get_tree().paused = false
	_input.release_focus()


## ========== UI 创建（程序化，不依赖 .tscn 文件）==========

func _create_ui() -> void:
	# CanvasLayer：确保 UI 渲染在最上层，不受游戏摄像机影响
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "DebugConsoleLayer"
	_ui_layer.layer = 128  # 最高层，确保在所有 UI 之上
	_ui_layer.visible = false
	add_child(_ui_layer)

	# 获取视口尺寸，以此为基准计算布局（避免 anchor 和手动 position 冲突）
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var console_h: float = 320.0      # 控制台总高度
	var input_h: float = 36.0          # 输入框高度
	var pad: float = 6.0               # 内边距
	var output_h: float = console_h - input_h - pad * 3  # 输出区域高度

	# 半透明背景面板（固定在屏幕底部）
	var bg: ColorRect = ColorRect.new()
	bg.name = "ConsoleBG"
	bg.color = Color(0, 0, 0, 0.75)
	bg.position = Vector2(0, view_size.y - console_h)
	bg.size = Vector2(view_size.x, console_h)
	_ui_layer.add_child(bg)

	# 输出区域（上方大头，滚动显示日志）
	_output = RichTextLabel.new()
	_output.name = "ConsoleOutput"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.context_menu_enabled = true
	_output.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	_output.add_theme_font_size_override("normal_font_size", 14)
	_output.position = Vector2(pad, pad)
	_output.size = Vector2(view_size.x - pad * 2, output_h)
	bg.add_child(_output)  # 作为 bg 子节点，坐标系相对 bg

	# 输入框（底部一行，绿色文字）
	_input = LineEdit.new()
	_input.name = "ConsoleInput"
	_input.placeholder_text = "输入命令，Enter 执行，~ 关闭..."
	_input.position = Vector2(pad, console_h - input_h - pad)
	_input.size = Vector2(view_size.x - pad * 2, input_h)
	_input.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.5))
	_input.add_theme_font_size_override("font_size", 16)
	_input.text_changed.connect(_on_input_changed)
	_input.text_submitted.connect(_on_command_entered)
	bg.add_child(_input)  # 作为 bg 子节点，坐标系相对 bg


## 输入框文本变化时（用于 Tab 自动补全等未来扩展）
func _on_input_changed(_new_text: String) -> void:
	pass  # 预留：自动补全、语法高亮等


## Enter 键触发命令执行
func _on_command_entered(cmd: String) -> void:
	cmd = cmd.strip_edges()
	if cmd.is_empty():
		return

	# 记录到历史
	_history.append(cmd)
	_history_index = _history.size()
	_input.text = ""
	# 延迟抢回焦点 — text_submitted 信号处理中直接 grab_focus 会失败，
	# call_deferred 将调用推迟到下一帧，此时 LineEdit 已完成内部状态重置
	_input.call_deferred("grab_focus")

	# 输出用户输入的命令
	_console_log("[color=#88ff88]> %s[/color]" % cmd)

	# 解析并执行
	var parts: PackedStringArray = cmd.split(" ", false, 1)
	var cmd_name: String = parts[0].to_lower()
	var args: String = parts[1] if parts.size() > 1 else ""

	_execute(cmd_name, args)


## ========== 命令执行 ==========

func _execute(cmd_name: String, args: String) -> void:
	if not _commands.has(cmd_name):
		_console_log("[color=#ff6666]未知命令: %s。输入 help 查看可用命令。[/color]" % cmd_name)
		return

	var cmd_info: Dictionary = _commands[cmd_name]
	cmd_info["callable"].call(args)


## ========== 命令注册（新增命令只需在此函数中添加）==========

func _register_commands() -> void:
	# 每个命令是一个 Dictionary，包含 callable（执行的函数）和 desc（描述）
	# callable 接收一个 String 参数（命令的参数部分）

	_add_cmd("help", _cmd_help, "显示所有可用命令")
	_add_cmd("?", _cmd_help, "help 的简写")
	_add_cmd("hp", _cmd_hp, "设置玩家血量。用法: hp <数值>")
	_add_cmd("god", _cmd_god, "切换无敌模式（玩家不受伤害）")
	_add_cmd("kill_all", _cmd_kill_all, "杀死场上所有敌人")
	_add_cmd("dice", _cmd_dice, "给玩家添加骰子。用法: dice <standard|fire|frost|glass|lead>")
	_add_cmd("coins", _cmd_coins, "设置金币数量。用法: coins <数值>")
	_add_cmd("speed", _cmd_speed, "设置游戏速度倍率。用法: speed <数值>")
	_add_cmd("phase", _cmd_phase, "强制切换游戏阶段。用法: phase <menu|battle|wave_clear|level_up|rest|boss|game_over>")
	_add_cmd("pos", _cmd_pos, "显示玩家当前坐标")
	_add_cmd("clear", _cmd_clear, "清空控制台输出")
	_add_cmd("cls", _cmd_clear, "clear 的简写")
	_add_cmd("list", _cmd_list, "列出场景中的实体：玩家、敌人、骰子数量")
	_add_cmd("wave", _cmd_wave, "发射波次开始信号。用法: wave <波次序号>")
	_add_cmd("give_relic", _cmd_give_relic, "添加遗物（预留）。用法: give_relic <遗物id>")


func _add_cmd(name: String, callable: Callable, desc: String) -> void:
	_commands[name] = { "callable": callable, "desc": desc }


## ========== 命令实现 ==========

func _cmd_help(_args: String) -> void:
	_console_log("[b]===== 可用调试命令 =====")
	for cmd_name in _commands.keys():
		var info: Dictionary = _commands[cmd_name]
		_console_log("  [color=#88ccff]%s[/color] — %s" % [cmd_name, info["desc"]])
	_console_log("[b]=============================[/b]")


func _cmd_hp(args: String) -> void:
	var amount: int = args.to_int()
	if args.is_empty():
		_console_log("[color=#ffaa00]用法: hp <数值>。当前血量: %d / %d[/color]" % [RunState.player_hp, RunState.player_max_hp])
		return

	RunState.player_hp = clampi(amount, 0, RunState.player_max_hp)
	_console_log("玩家血量设为 %d / %d" % [RunState.player_hp, RunState.player_max_hp])

	# 如果设为 0，触发死亡流程
	if RunState.player_hp <= 0:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player: Node = players[0]
			if player.has_method("_on_died"):
				player._on_died()


var _god_mode: bool = false

func _cmd_god(_args: String) -> void:
	_god_mode = not _god_mode
	_console_log("[color=#ffdd44]无敌模式: %s[/color]" % ("[color=#88ff88]开启[/color]" if _god_mode else "关闭"))

	# 找玩家的 HealthComponent，设置无敌
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_node("HealthComponent"):
			var hc: Node = p.get_node("HealthComponent")
			if _god_mode:
				# 拦截伤害：把血量设为极大值或直接跳过 take_damage
				if hc.has_method("take_damage"):
					# 暂时不改原有逻辑，通过 setter 保护
					hc.set("max_hp", 99999)
					hc.set("current_hp", 99999)
					hc.set("_is_dead", false)
					_console_log("  玩家血量临时设为 99999")
			else:
				# 恢复正常血量
				hc.set("max_hp", Constants.PLAYER_MAX_HP)
				hc.set("current_hp", Constants.PLAYER_MAX_HP)
				hc.set("_is_dead", false)
				_console_log("  玩家血量恢复为 %d" % Constants.PLAYER_MAX_HP)


func _cmd_kill_all(_args: String) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var count: int = enemies.size()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	_console_log("已杀死 %d 个敌人" % count)


func _cmd_dice(args: String) -> void:
	var dice_type: String = args.strip_edges().to_lower()
	var data: DiceData = null

	match dice_type:
		"standard", "标准", "":
			data = DiceManager.get_standard_d6()
		"fire", "火焰":
			data = DiceManager.get_fire_d6()
		"frost", "冰霜":
			data = DiceManager.get_frost_d6()
		"glass", "玻璃":
			data = DiceManager.get_glass_d6()
		"lead", "灌铅":
			data = DiceManager.get_leaded_d6()
		_:
			_console_log("[color=#ff6666]未知骰子类型: %s。可选: standard, fire, frost, glass, lead[/color]" % dice_type)
			return

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		_console_log("[color=#ff6666]找不到玩家节点[/color]")
		return

	var player: Node = players[0]
	if not player.has_method("add_dice"):
		_console_log("[color=#ff6666]玩家节点没有 add_dice 方法[/color]")
		return

	player.add_dice(data)
	_console_log("已添加骰子: [color=#88ccff]%s[/color]" % data.dice_name)


func _cmd_coins(args: String) -> void:
	if args.is_empty():
		_console_log("[color=#ffaa00]用法: coins <数值>。当前金币: %d[/color]" % RunState.coins)
		return
	var amount: int = args.to_int()
	RunState.coins = max(0, amount)
	_console_log("金币设为 %d" % RunState.coins)


func _cmd_speed(args: String) -> void:
	if args.is_empty():
		_console_log("[color=#ffaa00]用法: speed <数值>。当前速度倍率: %.1f[/color]" % Engine.time_scale)
		return
	var scale: float = args.to_float()
	scale = clampf(scale, 0.1, 10.0)
	Engine.time_scale = scale
	_console_log("游戏速度设为 %.1fx" % scale)


func _cmd_phase(args: String) -> void:
	var phase_name: String = args.strip_edges().to_lower()
	var target: int = -1

	match phase_name:
		"menu":
			target = GameManager.Phase.MENU
		"battle":
			target = GameManager.Phase.BATTLE
		"wave_clear":
			target = GameManager.Phase.WAVE_CLEAR
		"level_up":
			target = GameManager.Phase.LEVEL_UP
		"rest", "rest_station":
			target = GameManager.Phase.REST_STATION
		"boss":
			target = GameManager.Phase.BOSS
		"game_over":
			target = GameManager.Phase.GAME_OVER
		_:
			_console_log("[color=#ff6666]未知阶段: %s。可选: menu, battle, wave_clear, level_up, rest, boss, game_over[/color]" % phase_name)
			return

	GameManager.transition_to(target)
	_console_log("游戏阶段切换为: [color=#88ccff]%s[/color]" % phase_name)


func _cmd_pos(_args: String) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		_console_log("[color=#ff6666]找不到玩家节点[/color]")
		return
	var p: Node2D = players[0] as Node2D
	if p == null:
		_console_log("[color=#ff6666]玩家不是 Node2D 类型[/color]")
		return
	_console_log("玩家坐标: (%.0f, %.0f)" % [p.global_position.x, p.global_position.y])


func _cmd_clear(_args: String) -> void:
	# 清空缓冲区
	_log_buffer.clear()
	# 如果输出控件存在且打开，也清空
	if _output != null:
		_output.clear()


func _cmd_list(_args: String) -> void:
	var tree: SceneTree = get_tree()

	# 玩家
	var players: Array[Node] = tree.get_nodes_in_group("player")
	_console_log("[b]场景实体列表[/b]")
	_console_log("  玩家: %d 个" % players.size())

	# 敌人
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	_console_log("  敌人: %d 个" % enemies.size())

	# 运行状态
	_console_log("  血量: %d / %d" % [RunState.player_hp, RunState.player_max_hp])
	_console_log("  金币: %d" % RunState.coins)
	_console_log("  击杀: %d" % RunState.kill_count)
	_console_log("  骰子背包: %d 个" % RunState.dice_pool.size())
	_console_log("  遗物: %d 个" % RunState.relics.size())
	_console_log("  游戏阶段: [color=#88ccff]%s[/color]" % GameManager.Phase.keys()[GameManager.current_phase])


func _cmd_wave(args: String) -> void:
	var idx: int = args.to_int()
	if args.is_empty():
		_console_log("[color=#ffaa00]用法: wave <波次序号>[/color]")
		return
	EventBus.wave_started.emit(idx)
	_console_log("发射 wave_started 信号 (wave %d)" % idx)


func _cmd_give_relic(args: String) -> void:
	# TODO M4：遗物系统完善后实现
	_console_log("[color=#ffaa00]遗物系统暂未实现，预留接口。参数: %s[/color]" % args)
