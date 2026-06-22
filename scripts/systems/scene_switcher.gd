## 场景切换调试面板（Autoload / Singleton）
##
## 在 project.godot 中注册为 Autoload，按 F1 键切换面板显示/隐藏。
## 提供一个右上角浮动面板，包含所有核心场景的快捷跳转按钮，
## 方便开发调试时在幸存者 / 村庄 / 骰盅赌斗之间快速切换。
##
## 使用方式：
##   1. 游戏运行时按 F1 展开面板
##   2. 点击场景按钮立即跳转（change_scene_to_file）
##   3. 再按 F1 或点击收起按钮可隐藏面板
##
## 架构：
##   - CanvasLayer layer=127（确保在所有游戏 UI 之上，DebugConsole 128 之下）
##   - process_mode = PROCESS_MODE_ALWAYS（暂停时也能操作）
##   - 按钮列表集中定义在 _scene_entries 数组中，增删场景只需改数组
##
extends CanvasLayer


## ========== 场景条目定义 ==========
##
## 每一条记录一个可切换的场景。
## key: 按钮显示文本
## path: 场景文件路径（res:// 开头）
## color: 按钮色号（PICO-8 调色板风格：蓝/绿/红/灰）
##
const _SCENE_ENTRIES: Array[Dictionary] = [
	{ "key": "Main (幸存者)",   "path": "res://scenes/Main.tscn",               "color": Color(0.29, 0.53, 0.83) },
	{ "key": "Village (村庄)",  "path": "res://scenes/world/village.tscn",       "color": Color(0.11, 0.62, 0.47) },
	{ "key": "骰盅赌斗",        "path": "res://scenes/minigames/dice_cup_duel.tscn", "color": Color(0.82, 0.20, 0.40) },
	{ "key": "MainMenu (主菜单)","path": "res://scenes/ui/main_menu.tscn",        "color": Color(0.40, 0.40, 0.40) },
]

## ========== UI 节点引用 ==========

var _panel: Control = null           ## 展开面板根节点
var _toggle_btn: Button = null       ## 收起状态下的切换按钮
var _current_label: Label = null     ## 当前场景名称标签
var _toast_label: Label = null       ## 切换提示标签
var _is_expanded: bool = false
var _toast_tween: Tween = null


func _ready() -> void:
	## 确保暂停状态下仍可接收输入和更改场景
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 127  ## 低于 DebugConsole (128)，高于游戏 UI
	_create_ui()


func _input(event: InputEvent) -> void:
	## F1 键切换面板的展开/收起
	if event.is_action_pressed(&"scene_switcher"):
		_toggle_panel()


## ========== 面板切换 ==========

func _toggle_panel() -> void:
	_is_expanded = not _is_expanded
	_panel.visible = _is_expanded
	_toggle_btn.visible = not _is_expanded
	if _is_expanded:
		_update_current_label()


## ========== UI 创建 ==========

func _create_ui() -> void:
	## ─── 收起状态：右上角小按钮 ───
	_toggle_btn = Button.new()
	_toggle_btn.name = "SceneSwitcherToggle"
	_toggle_btn.text = "Scenes"
	_toggle_btn.flat = false
	_toggle_btn.custom_minimum_size = Vector2(80, 28)
	_toggle_btn.position = Vector2(_viewport_right() - 90, 8)

	# 半透明深色按钮样式
	var toggle_style := _make_button_style(Color(0.15, 0.15, 0.18, 0.75))
	_toggle_btn.add_theme_stylebox_override("normal", toggle_style)
	_toggle_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.25, 0.25, 0.30, 0.85)))
	_toggle_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.pressed.connect(_toggle_panel)

	add_child(_toggle_btn)

	## ─── 展开状态：场景按钮面板 ───
	_panel = Control.new()
	_panel.name = "SceneSwitcherPanel"
	_panel.visible = false
	add_child(_panel)

	# 半透明背景
	var bg := ColorRect.new()
	bg.name = "PanelBG"
	bg.color = Color(0.08, 0.08, 0.12, 0.88)
	bg.size = Vector2(190, 12 + _SCENE_ENTRIES.size() * 34 + 4 + 24)
	bg.position = Vector2(_viewport_right() - 200, 4)
	_panel.add_child(bg)

	# 标题行
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "F1 场景切换"
	title.position = Vector2(_viewport_right() - 196, 10)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title.add_theme_font_size_override("font_size", 11)
	_panel.add_child(title)

	# 当前场景标签
	_current_label = Label.new()
	_current_label.name = "CurrentSceneLabel"
	_current_label.position = Vector2(_viewport_right() - 196, 24)
	_current_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_current_label.add_theme_font_size_override("font_size", 10)
	_panel.add_child(_current_label)

	# 场景按钮列表
	var btn_y: float = 42.0
	for entry in _SCENE_ENTRIES:
		var btn := Button.new()
		btn.name = "Btn_" + entry["key"].replace(" ", "_")
		btn.text = entry["key"]
		btn.flat = false
		btn.custom_minimum_size = Vector2(180, 28)
		btn.position = Vector2(_viewport_right() - 194, btn_y)

		var col: Color = entry["color"]
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(col.r, col.g, col.b, 0.6)))
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(col.r, col.g, col.b, 0.85)))
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_font_size_override("font_size", 12)

		var scene_path: String = entry["path"]
		btn.pressed.connect(_change_scene.bind(scene_path))
		_panel.add_child(btn)
		btn_y += 34.0

	# 面板高度 = 最后一个按钮底部 + 一点间距
	bg.size.y = btn_y + 4

	# 收起按钮
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "收起 (F1)"
	close_btn.flat = false
	close_btn.custom_minimum_size = Vector2(180, 22)
	close_btn.position = Vector2(_viewport_right() - 194, btn_y)
	close_btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.2, 0.2, 0.25, 0.7)))
	close_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.35, 0.35, 0.40, 0.85)))
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(_toggle_panel)
	_panel.add_child(close_btn)

	# 面板高度 = 最后一个按钮底部 + 间距
	bg.size.y = btn_y + 28

	## ─── Toast 提示标签（切换成功/失败时的短暂提示）───────────
	_toast_label = Label.new()
	_toast_label.name = "ToastLabel"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.custom_minimum_size = Vector2(300, 0)
	_toast_label.position = Vector2((_viewport_right() - 300) / 2, _viewport_bottom() - 80)
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)


## ========== 场景切换 ==========

func _change_scene(scene_path: String) -> void:
	## 先确保游戏不处于暂停状态（DebugConsole 打开会暂停）
	if get_tree().paused:
		get_tree().paused = false

	print("[SceneSwitcher] 切换场景 → %s" % scene_path)
	_show_toast("切换中...", Color(0.6, 0.6, 0.6))

	# 延迟一帧执行，避免按钮 press 信号与场景切换冲突
	call_deferred("_deferred_change_scene", scene_path)


func _deferred_change_scene(scene_path: String) -> void:
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		var msg: String = "失败 (err=%d): %s" % [err, scene_path.get_file()]
		push_error("[SceneSwitcher] " + msg)
		_show_toast(msg, Color(1.0, 0.3, 0.3), 3.0)
	else:
		_show_toast("已切换: " + scene_path.get_file(), Color(0.3, 1.0, 0.3), 1.5)


## ========== Toast 提示 ==========

func _show_toast(text: String, col: Color, duration: float = 1.5) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", col)
	_toast_label.modulate.a = 1.0

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)


func _update_current_label() -> void:
	var path: String = get_tree().current_scene.scene_file_path
	_current_label.text = "当前: " + path.get_file()


func _viewport_bottom() -> float:
	return get_viewport().get_visible_rect().size.y


## ========== 工具方法 ==========

func _viewport_right() -> float:
	return get_viewport().get_visible_rect().size.x


func _make_button_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	return sb
