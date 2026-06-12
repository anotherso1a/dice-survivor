## 骰子状态面板脚本
##
## 挂载节点：scenes/ui/dice_status_ui.tscn
## 职责：展示玩家骰子背包中所有骰子的详细信息。
##       包括骰子名称、骰面数据（战斗面/赌博面）、冷却时间、耐久度、元素属性。
##       按 D 键打开/关闭。
##
## 数据来源：RunState.dice_pool（Array[DiceData]）
## 刷新机制：通过 EventBus.dice_added / dice_removed 信号，以及每帧轮询更新冷却显示
##
## 设计：每个骰子一张"卡片"，显示6个骰面分布 + 属性面板
##   - 战斗面：高亮 1（暴击面），其余灰色
##   - 赌博面：高亮 6（赌局面），其余灰色
##   - 耐久度条：绿色→黄色→红色渐变
##   - 冷却圆环或进度条
##
extends CanvasLayer


# ========== 节点引用 ==========
@onready var _panel: ColorRect = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _dice_grid: VBoxContainer = %DiceGrid
@onready var _close_button: Button = %CloseButton
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_close_button.pressed.connect(_on_close_pressed)

	EventBus.dice_added.connect(_on_dice_pool_changed)
	EventBus.dice_removed.connect(_on_dice_pool_changed)

	print("✅ DiceStatus ready")


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_dice_list()
		_close_button.grab_focus()


func _on_close_pressed() -> void:
	visible = false


func _on_dice_pool_changed(_dice: DiceData) -> void:
	if visible:
		_refresh_dice_list()


## 每帧更新冷却和耐久显示（仅在面板可见时执行）
func _process(_delta: float) -> void:
	if not visible:
		return
	# 更新所有骰子条目的实时数据
	for i in _dice_grid.get_child_count():
		var child := _dice_grid.get_child(i)
		if child.has_method("refresh"):
			child.refresh()


## 完全重建骰子列表
func _refresh_dice_list() -> void:
	for child in _dice_grid.get_children():
		child.queue_free()

	var dice_pool: Array[DiceData] = RunState.dice_pool

	if dice_pool.is_empty():
		_empty_label.visible = true
		_title_label.text = "🎲 骰子背包 (0)"
		return

	_empty_label.visible = false
	_title_label.text = "🎲 骰子背包 (%d)" % dice_pool.size()

	for i in dice_pool.size():
		var dice_data: DiceData = dice_pool[i]
		var card := _create_dice_card(dice_data, i)
		_dice_grid.add_child(card)


## 创建单个骰子卡片（含代码渲染的骰面缩略图）
func _create_dice_card(dice_data: DiceData, index: int) -> Control:
	var card := MarginContainer.new()
	card.add_theme_constant_override("margin_top", 4)
	card.add_theme_constant_override("margin_bottom", 4)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# --- 左侧：骰面缩略图（用 DiceFaceRenderer 渲染） ---
	if not dice_data.combat_faces.is_empty():
		var face_preview := TextureRect.new()
		# 渲染第 0 面作为预览（传入骰子材质）
		var preview_face: FaceData = dice_data.combat_faces[0]
		var mat: DiceMaterial = dice_data.dice_material
		face_preview.texture = DiceFaceRenderer.render(mat, preview_face)
		face_preview.custom_minimum_size = Vector2(48, 48)
		face_preview.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		face_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(face_preview)

	# --- 右侧：骰子信息 ---
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# --- 骰子头部：编号 + 名称 + 元素 ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var idx_label := Label.new()
	idx_label.text = "[%d]" % (index + 1)
	idx_label.add_theme_font_size_override("font_size", 14)
	idx_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1))
	header.add_child(idx_label)

	var name_label := Label.new()
	name_label.text = dice_data.dice_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 1))
	header.add_child(name_label)

	if dice_data.element != &"":
		var elem_label := Label.new()
		elem_label.text = _get_element_icon(dice_data.element)
		elem_label.add_theme_font_size_override("font_size", 16)
		header.add_child(elem_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# 面数标签
	var sides_label := Label.new()
	sides_label.text = "d%d" % dice_data.sides
	sides_label.add_theme_font_size_override("font_size", 14)
	sides_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
	header.add_child(sides_label)

	vbox.add_child(header)

	# --- 骰面分布行 ---
	var faces_hbox := HBoxContainer.new()
	faces_hbox.add_theme_constant_override("separation", 4)

	# 战斗面
	var combat_vbox := VBoxContainer.new()
	var combat_header := Label.new()
	combat_header.text = "⚔ 战斗面"
	combat_header.add_theme_font_size_override("font_size", 12)
	combat_header.add_theme_color_override("font_color", Color(0.8, 0.35, 0.35, 1))
	combat_vbox.add_child(combat_header)

	var combat_faces_str := _format_faces(dice_data.combat_faces, true)
	var combat_label := Label.new()
	combat_label.text = combat_faces_str
	combat_label.add_theme_font_size_override("font_size", 12)
	combat_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
	combat_vbox.add_child(combat_label)
	faces_hbox.add_child(combat_vbox)

	# 分隔
	var sep := VSeparator.new()
	faces_hbox.add_child(sep)

	# 赌博面
	var gamble_vbox := VBoxContainer.new()
	var gamble_header := Label.new()
	gamble_header.text = "🎰 赌博面"
	gamble_header.add_theme_font_size_override("font_size", 12)
	gamble_header.add_theme_color_override("font_color", Color(0.35, 0.7, 0.35, 1))
	gamble_vbox.add_child(gamble_header)

	var gamble_faces_str := _format_faces(dice_data.gamble_faces, false)
	var gamble_label := Label.new()
	gamble_label.text = gamble_faces_str
	gamble_label.add_theme_font_size_override("font_size", 12)
	gamble_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
	gamble_vbox.add_child(gamble_label)
	faces_hbox.add_child(gamble_vbox)

	vbox.add_child(faces_hbox)

	# --- 属性行：冷却 + 耐久 ---
	var attrs_hbox := HBoxContainer.new()
	attrs_hbox.add_theme_constant_override("separation", 20)

	var cd_label := Label.new()
	cd_label.text = "冷却: %.1fs" % dice_data.cooldown
	cd_label.add_theme_font_size_override("font_size", 13)
	cd_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1))
	attrs_hbox.add_child(cd_label)

	if dice_data.durability > 0:
		var dur_text := "耐久: %d/%d" % [dice_data.current_durability, dice_data.durability]
		var dur_color := Color.GREEN if dice_data.current_durability > dice_data.durability * 0.5 else (Color.YELLOW if dice_data.current_durability > 2 else Color.RED)
		var dur_label := Label.new()
		dur_label.text = dur_text
		dur_label.add_theme_font_size_override("font_size", 13)
		dur_label.add_theme_color_override("font_color", dur_color)
		attrs_hbox.add_child(dur_label)
	else:
		var dur_label := Label.new()
		dur_label.text = "耐久: ∞"
		dur_label.add_theme_font_size_override("font_size", 13)
		dur_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4, 1))
		attrs_hbox.add_child(dur_label)

	# 损坏标记
	if dice_data.is_broken():
		var broken_label := Label.new()
		broken_label.text = "💔 已损坏"
		broken_label.add_theme_font_size_override("font_size", 13)
		broken_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
		attrs_hbox.add_child(broken_label)

	vbox.add_child(attrs_hbox)

	# --- 分隔线 ---
	var hsep := HSeparator.new()
	vbox.add_child(hsep)

	return card


## 格式化骰面列表为可读字符串
func _format_faces(faces: Array[FaceData], is_combat: bool) -> String:
	if faces.is_empty():
		return "（无）"

	var parts: Array[String] = []
	for face in faces:
		var face_str := "[%d]" % face.value
		if is_combat and face.is_crit:
			face_str += " ⚡×%.0f" % face.multiplier
		if face.element != &"":
			face_str += _get_element_icon(face.element)
		parts.append(face_str)

	return " ".join(parts)


func _get_element_icon(element: StringName) -> String:
	match element:
		&"fire":     return "🔥"
		&"ice":      return "❄️"
		&"thunder":  return "⚡"
		&"poison":   return "☠️"
		&"holy":     return "✨"
		&"dark":     return "🌑"
		_:           return ""
