## 暂停菜单脚本
##
## 挂载节点：scenes/ui/pause_menu.tscn
## 职责：游戏内按 ESC 呼出的暂停面板，提供继续/重启/返回主菜单功能。
## 暂停时游戏时间停止，恢复后继续。
##
## 通信方式：
##   - ESC 键 → toggle() 切换显示/隐藏
##   - "继续"按钮 → 关闭暂停菜单，恢复游戏
##   - "重新开始" → 重置 RunState 并重载当前场景
##   - "返回主菜单" → 切换到主菜单场景
##
extends CanvasLayer


# ========== 节点引用 ==========
@onready var _panel: ColorRect = %Panel
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitToMenuButton


func _ready() -> void:
	# 初始隐藏
	visible = false

	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# 暂停时停止游戏时间
	process_mode = Node.PROCESS_MODE_ALWAYS

	print("✅ PauseMenu ready")


## 切换暂停状态（由 Main 场景在 ESC 按下时调用）
func toggle() -> void:
	visible = not visible
	if visible:
		_show()
	else:
		_hide()


## 显示暂停菜单
func _show() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()
	print("⏸ 游戏暂停")


## 隐藏暂停菜单（继续游戏）
func _hide() -> void:
	visible = false
	get_tree().paused = false
	print("▶ 游戏继续")


func _on_resume_pressed() -> void:
	_hide()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	RunState.reset()
	RunState.init_dice_pool()
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_error("⚠ 重新加载场景失败: %d" % err)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	var err := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if err != OK:
		push_error("⚠ 无法返回主菜单: %d" % err)
