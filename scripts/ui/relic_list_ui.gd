## 遗物列表面板脚本
##
## 挂载节点：scenes/ui/relic_list_ui.tscn
## 职责：展示玩家当前持有的所有遗物，包含图标、名称、稀有度颜色和效果描述。
##       按 R 键（或点击 HUD 遗物徽章）打开/关闭。
##
## 数据来源：RunState.relics（Array[RelicData]）
## 刷新机制：订阅 EventBus.relic_added / relic_removed 信号自动更新列表
##
## UI 设计：暗色面板 + 可滚动网格，稀有度决定边框/文字颜色
##   - COMMON (白)   → 灰色文字
##   - UNCOMMON (蓝) → 蓝色文字
##   - RARE (紫)     → 紫色文字
##   - EPIC (金)     → 金色文字
##   - LEGENDARY (红)→ 红色/橙色文字
##
extends CanvasLayer


# ========== 节点引用 ==========
@onready var _panel: ColorRect = %Panel
@onready var _relic_grid: VBoxContainer = %RelicGrid
@onready var _close_button: Button = %CloseButton
@onready var _title_label: Label = %CountLabel
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_close_button.pressed.connect(_on_close_pressed)

	# 订阅遗物变化信号，自动刷新列表
	EventBus.relic_added.connect(_on_relics_changed)
	EventBus.relic_removed.connect(_on_relics_changed)

	print("✅ RelicList ready")


## 切换显示/隐藏
func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_list()
		_close_button.grab_focus()


func _on_close_pressed() -> void:
	visible = false


## 遗物添加/移除时刷新
func _on_relics_changed(_relic: RelicData) -> void:
	if visible:
		_refresh_list()


## 完全重建遗物列表
func _refresh_list() -> void:
	# 清除旧条目
	for child in _relic_grid.get_children():
		child.queue_free()

	var relics: Array[RelicData] = RunState.relics

	if relics.is_empty():
		_empty_label.visible = true
		_title_label.text = "遗物 (0)"
		return

	_empty_label.visible = false
	_title_label.text = "遗物 (%d)" % relics.size()

	for relic in relics:
		var entry := _create_relic_entry(relic)
		_relic_grid.add_child(entry)


## 创建单个遗物条目
func _create_relic_entry(relic: RelicData) -> Control:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	# 稀有度颜色条
	var rarity_bar := ColorRect.new()
	rarity_bar.custom_minimum_size = Vector2(5, 40)
	rarity_bar.color = _get_rarity_color(relic.rarity)
	container.add_child(rarity_bar)

	# 信息区
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = _get_rarity_symbol(relic.rarity) + " " + relic.relic_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _get_rarity_color(relic.rarity))
	info_box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = relic.description
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(desc_label)

	# 类型标签
	var tag_label := Label.new()
	tag_label.text = _get_tag_text(relic.applies_to)
	tag_label.add_theme_font_size_override("font_size", 11)
	tag_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5, 1))
	info_box.add_child(tag_label)

	container.add_child(info_box)
	return container


## 稀有度 → 颜色映射
func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		RelicData.Rarity.UNCOMMON:
			return Color(0.3, 0.5, 0.9, 1)   # 蓝
		RelicData.Rarity.RARE:
			return Color(0.6, 0.3, 0.9, 1)   # 紫
		RelicData.Rarity.EPIC:
			return Color(0.95, 0.75, 0.15, 1) # 金
		RelicData.Rarity.LEGENDARY:
			return Color(0.95, 0.35, 0.2, 1)  # 橙红
		_:
			return Color(0.6, 0.6, 0.6, 1)   # 白/灰


## 稀有度 → 符号
func _get_rarity_symbol(rarity: int) -> String:
	match rarity:
		RelicData.Rarity.UNCOMMON:  return "●"
		RelicData.Rarity.RARE:      return "◆"
		RelicData.Rarity.EPIC:      return "★"
		RelicData.Rarity.LEGENDARY: return "👑"
		_:                          return "○"


## 适用场景标签
func _get_tag_text(applies_to: StringName) -> String:
	match applies_to:
		&"combat": return "[战斗]"
		&"gamble": return "[赌局]"
		&"both":   return "[双面]"
		_:         return ""
