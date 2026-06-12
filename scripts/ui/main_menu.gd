## 主菜单界面脚本
##
## 挂载节点：scenes/ui/main_menu.tscn
## 职责：游戏启动时的标题画面，包含"开始游戏"和"退出"按钮。
## 像素风暗色调设计，与游戏整体 8-bit 复古美学统一。
##
## 通信方式：
##   - 点击"开始游戏" → 切换到战斗场景（Main.tscn）
##   - 点击"退出游戏" → 退出应用程序
##   - 所有按钮事件通过信号连接，不直接操作场景树
##
extends CanvasLayer


# ========== 节点引用 ==========
@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton
@onready var _title_label: Label = %TitleLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	# 连接按钮信号
	_start_button.pressed.connect(_on_start_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	# 设置版本号
	_version_label.text = "v0.1 MVP — Godot 4"

	# 标题闪烁动画（像素风呼吸效果）
	_animate_title()

	print("✅ MainMenu ready")


## 开始游戏 — 切换到战斗场景
func _on_start_pressed() -> void:
	print("▶ 开始游戏")

	# 初始化当局运行状态
	RunState.reset()
	RunState.init_dice_pool()

	# 切换到战斗场景
	# 使用 change_scene_to_file 避免路径硬编码问题
	var err := get_tree().change_scene_to_file("res://scenes/Main.tscn")
	if err != OK:
		push_error("⚠ 无法加载战斗场景: %d" % err)


## 退出游戏
func _on_quit_pressed() -> void:
	print("👋 退出游戏")
	get_tree().quit()


## 标题呼吸灯动画 — 像素风微妙闪烁
func _animate_title() -> void:
	var tween := create_tween()
	tween.set_loops()  # 无限循环
	tween.tween_property(_title_label, "modulate:a", 0.6, 1.5)
	tween.tween_property(_title_label, "modulate:a", 1.0, 1.5)
