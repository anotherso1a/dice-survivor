## 骰子升级选择界面（三选一）
##
## 每击杀 3 只怪物后弹出，玩家从 3 个随机骰子中选 1 个。
## 选中后发出 dice_selected 信号，GameManager 恢复游戏并将新骰子加入玩家槽位。
##
extends CanvasLayer

## 玩家选定骰子后发出（参数：选中的骰子数据）
signal dice_selected(dice_data: DiceData)

@onready var _option_container: GridContainer = %OptionContainer

var _dice_options: Array[DiceData] = []


func _ready() -> void:
	_generate_options()
	_populate_ui()


## 生成 3 个随机骰子选项
func _generate_options() -> void:
	_dice_options.clear()
	var all_dice: Array[Callable] = [
		DiceManager.get_standard_d6,
		DiceManager.get_leaded_d6,
		DiceManager.get_glass_d6,
		DiceManager.get_fire_d6,
		DiceManager.get_frost_d6,
	]
	for i in range(3):
		var idx: int = randi() % all_dice.size()
		var data: DiceData = all_dice[idx].call()
		_dice_options.append(data)


## 将选项显示到 UI 中，GridContainer 自动换行
func _populate_ui() -> void:
	for child in _option_container.get_children():
		child.queue_free()

	var count: int = _dice_options.size()
	if count == 0:
		return

	# GridContainer 自动排列，columns 控制每行个数
	# <=4 时单行，>=5 时双行（columns=3 自动换行）
	_option_container.columns = clamp(count, 1, 3)

	for i in range(count):
		var opt: Panel = _create_dice_option(_dice_options[i], i)
		_option_container.add_child(opt)


## 创建单个骰子选项面板
func _create_dice_option(data: DiceData, index: int) -> Panel:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(160, 220)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# 骰子名称
	var name_label: Label = Label.new()
	name_label.text = data.dice_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# 分隔
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# 骰子面预览（传入骰子材质）
	if data.combat_faces.size() > 0:
		var face: FaceData = data.combat_faces[0]
		var mat: DiceMaterial = data.dice_material
		var tex: Texture2D = DiceFaceRenderer.render(mat, face)
		if tex != null:
			var tex_rect: TextureRect = TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(64, 64)
			tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			vbox.add_child(tex_rect)

	# 信息
	var info: Label = Label.new()
	info.text = "耐久:%d  CD:%.1fs\n面数:%d" % [data.durability, data.cooldown, data.combat_faces.size()]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info)

	# 点击处理
	panel.gui_input.connect(_on_panel_gui_input.bind(index))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "点击选择 " + data.dice_name

	return panel


func _on_panel_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index < _dice_options.size():
			dice_selected.emit(_dice_options[index])
			queue_free()
