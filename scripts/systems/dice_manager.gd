## 骰子池管理（Autoload / Singleton）
##
## ============================================================
##  架构说明（重要！）
## ============================================================
##  整套骰子系统分三层：
##
##  [DiceMaterial]  ← 骰体材质（决定外观风格）
##      定义：pip_style（点数图案类型）、base_color、border_color、rarity
##      文件：scripts/core/dice_material.gd
##      内置材质：在 _init() 中初始化，可通过 DiceManager.get_material("flame") 获取
##
##  [DiceData]  ← 骰子实体数据（决定游戏数值）
##      引用：dice_material: DiceMaterial（指向材质）
##      包含：combat_faces: Array[FaceData]（6个战斗面）、cooldown、durability 等
##      文件：scripts/core/dice_data.gd
##
##  [DiceFaceRenderer]  ← 骰面纹理生成器（把数据和材质画成图片）
##      输入：DiceMaterial + FaceData
##      输出：Texture2D（64×64 像素风骰面纹理）
##      文件：scripts/tools/dice_face_renderer.gd
##
##  数据流：
##    DiceManager.create_dice(config)
##      → 创建 DiceData，绑定 DiceMaterial
##      → DiceEntity.setup(data)
##        → DiceFaceRenderer.render(material, face) 预生成所有面纹理
##        → 骰子在头顶 rolling 时切换纹理
##
## ============================================================
##  快速创建新骰子（工厂方法）
## ============================================================
##  只需提供一个 Dictionary 配置，立即得到 DiceData：
##
##  var d := DiceManager.create_dice({
##    "id": &"d6_holy",                          # 唯一ID（StringName）
##    "name": "圣光骰子 d6",                      # 显示名称
##    "material": DiceManager.get_material("glass"), # 骰体材质（决定外观）
##    "cooldown": 1.0,                           # 冷却时间（秒）
##    "durability": -1,                          # 耐久度（-1=无限）
##    "element": &"holy",                        # 元素类型（可选）
##    "faces": [                                 # 6个战斗面
##      {"value": 1, "damage": 10, "is_crit": true, "element": &"holy", "element_power": 2},
##      {"value": 2, "damage": 3},
##      {"value": 3, "damage": 3},
##      {"value": 4, "damage": 4},
##      {"value": 5, "damage": 4},
##      {"value": 6, "damage": 5},
##    ],
##  })
##
##  预设骰子（快捷方式，内部也调用同样的创建逻辑）：
##    get_standard_d6() / get_leaded_d6() / get_fire_d6() / get_frost_d6() 等
## ============================================================
extends Node


# ========== 内置材质引用（单例访问）=========
# 在 _init 中初始化
static var _mat_standard: DiceMaterial
static var _mat_frost: DiceMaterial
static var _mat_flame: DiceMaterial
static var _mat_glass: DiceMaterial
static var _mat_lead: DiceMaterial
static var _mat_cursed: DiceMaterial
static var _mat_mountain: DiceMaterial


## 获取内置材质（快捷方式）
static func get_material(key: String) -> DiceMaterial:
	match key:
		"standard", "normal": return _mat_standard
		"frost", "ice": return _mat_frost
		"flame", "fire": return _mat_flame
		"glass": return _mat_glass
		"lead": return _mat_lead
		"cursed", "curse": return _mat_cursed
		"mountain", "rock": return _mat_mountain
		_: return _mat_standard


func _init() -> void:
	_mat_standard = _make_material("标准", DiceMaterial.PipStyle.CLASSIC, Color(0.20, 0.20, 0.25), "common")
	_mat_lead  = _make_material("灌铅", DiceMaterial.PipStyle.LEAD, Color(0.18, 0.18, 0.22), "common")
	_mat_glass  = _make_material("玻璃", DiceMaterial.PipStyle.GLASS, Color(0.15, 0.22, 0.35), "rare")
	_mat_flame  = _make_material("火焰", DiceMaterial.PipStyle.FLAME, Color(0.30, 0.10, 0.05), "rare")
	_mat_frost  = _make_material("冰霜", DiceMaterial.PipStyle.FROST, Color(0.10, 0.18, 0.30), "rare")
	_mat_cursed = _make_material("诅咒", DiceMaterial.PipStyle.CURSED, Color(0.25, 0.12, 0.12), "epic")
	_mat_mountain = _make_material("山岳", DiceMaterial.PipStyle.MOUNTAIN, Color(0.15, 0.12, 0.08), "rare")


# ========== 获取预设骰子（保持原有 API 兼容）=========

## 标准 d6
func get_standard_d6() -> DiceData:
	var d := _new_dice(&"d6_standard", "标准骰子 d6", 1.0, -1, _mat_standard)
	d.combat_faces = [
		_make_face(1, 10, true),
		_make_face(2, 2, false),
		_make_face(3, 2, false),
		_make_face(4, 2, false),
		_make_face(5, 2, false),
		_make_face(6, 3, false),
	]
	_set_face_indices(d)
	## 枪手角色：穿透子弹攻击
	d.attack_type = DiceData.AttackType.PENETRATING_BULLET
	## 新系统：配置投射物效果
	d.attack_effect = _make_standard_bullet_effect()
	d.gamble_faces = [
		_make_gamble_face(1, 1, "烂"),
		_make_gamble_face(2, 2, "烂"),
		_make_gamble_face(3, 3, "中"),
		_make_gamble_face(4, 4, "中"),
		_make_gamble_face(5, 5, "好"),
		_make_gamble_face(6, 6, "顶"),
	]
	return d


## 灌铅 d6
func get_leaded_d6() -> DiceData:
	var d := _new_dice(&"d6_leaded", "灌铅骰子 d6", 2.0, -1, _mat_lead)
	d.combat_faces = [
		_make_face(1, 15, true),
		_make_face(2, 3, false),
		_make_face(3, 3, false),
		_make_face(4, 3, false),
		_make_face(5, 3, false),
		_make_face(6, 4, false),
	]
	_set_face_indices(d)
	return d


## 玻璃 d6
func get_glass_d6() -> DiceData:
	var d := _new_dice(&"d6_glass", "玻璃骰子 d6", 0.8, 10, _mat_glass)
	d.combat_faces = [
		_make_face(1, 20, true),
		_make_face(2, 5, false),
		_make_face(3, 5, false),
		_make_face(4, 5, false),
		_make_face(5, 5, false),
		_make_face(6, 6, false),
	]
	_set_face_indices(d)
	return d


## 火焰 d6
func get_fire_d6() -> DiceData:
	var d := _new_dice(&"d6_fire", "火焰骰子 d6", 1.0, -1, _mat_flame)
	d.element = &"fire"
	d.combat_faces = [
		_make_face(1, 8, true, &"fire", 3),
		_make_face(2, 2, false),
		_make_face(3, 2, false),
		_make_face(4, 2, false),
		_make_face(5, 2, false),
		_make_face(6, 2, false),
	]
	_set_face_indices(d)
	## 新系统：火焰投射物（点燃敌人）
	d.attack_effect = _make_fire_projectile_effect()
	return d


## 冰霜 d6（新增！）
func get_frost_d6() -> DiceData:
	var d := _new_dice(&"d6_frost", "冰霜骰子 d6", 1.2, -1, _mat_frost)
	d.element = &"ice"
	d.combat_faces = [
		_make_face(1, 6, true, &"ice", 2),
		_make_face(2, 2, false),
		_make_face(3, 3, false),
		_make_face(4, 2, false),
		_make_face(5, 3, false),
		_make_face(6, 4, false),
	]
	_set_face_indices(d)
	## 新系统：冰霜投射物（减速/冰冻）
	d.attack_effect = _make_frost_projectile_effect()
	return d


## 山岳 d6（范围攻击）
func get_mountain_d6() -> DiceData:
	var d := _new_dice(&"d6_mountain", "山岳骰子 d6", 3.0, -1, _mat_mountain)
	d.attack_type = DiceData.AttackType.AOE_IMPACT
	d.aoe_radius = 130.0
	d.combat_faces = [
		_make_face(1, 12, false),
		_make_face(2, 14, false),
		_make_face(3, 16, false),
		_make_face(4, 18, false),
		_make_face(5, 22, false),
		_make_face(6, 28, true),
	]
	_set_face_indices(d)
	## 新系统：AOE 冲击效果
	d.attack_effect = _make_aoe_effect(d.aoe_radius)
	d.gamble_faces = [
		_make_gamble_face(1, 1, "崩"),
		_make_gamble_face(2, 2, "裂"),
		_make_gamble_face(3, 3, "震"),
		_make_gamble_face(4, 4, "毁"),
		_make_gamble_face(5, 5, "灭"),
		_make_gamble_face(6, 6, "天崩"),
	]
	return d


# ========== 快速创建新骰子（工厂方法）==========
##
## 一行配置出一种新骰子，无需手动 new DiceData + 设置每个字段。
##
## 参数 config 支持的键（均有默认值，可选）：
##   "id": StringName       — 唯一标识符，用于存档/合成系统（默认 &"d6_custom"）
##   "name": String         — 显示名称（默认 "自定义骰子"）
##   "material": DiceMaterial — 骰体材质，决定点数图案和颜色（默认 _mat_standard）
##   "cooldown": float      — 投掷冷却时间，秒（默认 1.0）
##   "durability": int      — 耐久度，-1=无限耐久（默认 -1）
##   "element": StringName  — 元素类型，如 &"fire" / &"ice"（默认 &"" 无元素）
##   "faces": Array[Dict]   — 战斗面配置，6个元素，每个是 Dict：
##       {"value": int, "damage": int, "is_crit": bool, "element": StringName, "element_power": int}
##   "gamble_faces": Array[Dict] — 赌博面配置（可选），每个是 Dict：
##       {"value": int, "gamble_value": int, "label": String}
##
## 返回值：配置好的 DiceData 实例，可直接传给 player.add_dice(data)
##
## 示例：
##   var d := DiceManager.create_dice({
##     "name": "剧毒骰子",
##     "material": DiceManager.get_material("cursed"),
##     "cooldown": 1.5,
##     "faces": [
##       {"value": 1, "damage": 5, "is_crit": false, "element": &"poison", "element_power": 3},
##       {"value": 2, "damage": 2},
##       {"value": 3, "damage": 3},
##       {"value": 4, "damage": 3},
##       {"value": 5, "damage": 4},
##       {"value": 6, "damage": 5},
##     ],
##   })
##
static func create_dice(config: Dictionary) -> DiceData:
	var material: DiceMaterial = config.get("material", _mat_standard)
	var d := _new_dice(
		config.get("id", &"d6_custom"),
		config.get("name", "自定义骰子"),
		config.get("cooldown", 1.0),
		config.get("durability", -1),
		material,
	)
	d.element = config.get("element", &"")

	# 从 config["faces"] 构建 combat_faces
	var face_cfgs: Array = config.get("faces", [])
	var faces: Array[FaceData] = []
	for cfg in face_cfgs:
		var f: FaceData = _make_face(
			cfg.get("value", 1),
			cfg.get("damage", 0),
			cfg.get("is_crit", false),
			cfg.get("element", &""),
			cfg.get("element_power", 0),
		)
		faces.append(f)
	d.combat_faces = faces
	_set_face_indices(d)

	# 赌博面（可选）
	var gamble_cfgs: Array = config.get("gamble_faces", [])
	if not gamble_cfgs.is_empty():
		var gfaces: Array[FaceData] = []
		for cfg in gamble_cfgs:
			gfaces.append(_make_gamble_face(
				cfg.get("value", 1),
				cfg.get("gamble_value", 1),
				cfg.get("label", ""),
			))
		d.gamble_faces = gfaces

	return d


# ========== 内部辅助（仅供本文件内使用）==========


## 创建一个"空壳" DiceData，只填基本属性，不填骰面
##
## 这是最底层的构建函数，所有预设骰子（get_xxx_d6）和工厂方法（create_dice）
## 都会先调用它拿到一个基础 DiceData，然后再往里填 combat_faces。
##
## 参数说明：
##   id:       唯一标识符，如 &"d6_standard"，用于合成/存档系统区分不同骰子
##   name:     显示名称，如 "标准骰子 d6"，显示在 UI 和升级面板上
##   cooldown: 投掷冷却时间（秒），1.0 = 每秒投一次，2.0 = 每两秒投一次
##   durability: 耐久度，>0 表示可用多少次，-1 表示无限耐久
##   material: 骰体材质（DiceMaterial 实例），决定骰面的绘制风格和点数图案
##
## 注意：返回的 DiceData.combat_faces 是空数组，需要在外面手动填充
static func _new_dice(id: StringName, name: String, cooldown: float, durability: int, material: DiceMaterial) -> DiceData:
	var d := DiceData.new()
	d.dice_id = id
	d.dice_name = name
	d.cooldown = cooldown
	d.durability = durability
	d.dice_material = material
	return d


## 创建一个战斗骰面（FaceData）
##
## 战斗骰面是骰子掷出后用来计算伤害的面，每个 DiceData.combat_faces 数组里
## 有 6 个 FaceData（对应骰子的 6 个面）。
##
## 参数说明：
##   value:       骰面点数（1~6），目前主要用于显示，后续可用于"大小赌"
##   damage:     基础伤害值，敌人会受到这么多伤害（受 is_crit 影响会翻倍）
##   is_crit:    是否暴击，true = 伤害翻倍，且骰面纹理会有金色闪光特效
##   element:    元素类型（可选），如 &"fire" 火焰 / &"ice" 冰霜，空 = 无元素
##   element_power: 元素强度（可选），元素伤害的额外参数，如燃烧层数、减速百分比等
##
## 示例：
##   _make_face(1, 10, true, &"fire", 3)
##   → 面1，伤害10，暴击（伤害变20），火焰元素，元素强度3
##
## 注意：这个函数只创建 FaceData，不把它加到任何 DiceData 里，
## 需要外面手动 append 到 DiceData.combat_faces 数组
static func _make_face(value: int, damage: int, is_crit: bool, element: StringName = &"", element_power: int = 0) -> FaceData:
	var f := FaceData.new()
	f.value = value
	f.damage = damage
	f.is_crit = is_crit
	f.element = element
	f.element_power = element_power
	return f


## 创建一个赌博骰面（FaceData）
##
## 赌博骰面用于"百家乐"小游戏（M5），和战斗骰面分开存储。
## 在赌博场景中，骰子掷出后显示 gamble_label（如"烂""中""好""顶"），
## 并根据 gamble_value 决定输赢。
##
## 参数说明：
##   value:        骰面点数（1~6），对应骰子的物理面
##   gamble_value: 赌博数值，用于和庄家比较大小
##   label:        显示标签，如 "烂"（输）、"中"（平）、"好"（赢）、"顶"（大赢）
##
## 注意：赌博面存储在 DiceData.gamble_faces 里，和 combat_faces 是独立的两套数据
##       目前游戏里还没有实现百家乐小游戏，这个是为未来预留的
static func _make_gamble_face(value: int, gamble_value: int, label: String) -> FaceData:
	var f := FaceData.new()
	f.value = value
	f.gamble_value = gamble_value
	f.gamble_label = label
	return f


## 给 combat_faces 数组里的每个 FaceData 设置 face_index
##
## face_index 表示这个面是骰子的第几面（0~5），有两个作用：
##   1. DiceFaceRenderer 用它来决定绘制哪个面的点数布局（1点/2点/.../6点）
##   2. 骰子 rolling 动画结束时，根据掷出的 value 找到对应的 FaceData
##
## 必须在填充完 combat_faces 之后调用，否则 face_index 会是默认的 0
## （这就是为什么所有 get_xxx_d6() 和 create_dice() 最后都要调用它）
static func _set_face_indices(d: DiceData) -> void:
	for i in range(d.combat_faces.size()):
		d.combat_faces[i].face_index = i


# ========== AttackEffect 工厂方法（新系统）==========

## 创建标准子弹效果（枪手角色）
static func _make_standard_bullet_effect() -> ProjectileEffect:
	var e := ProjectileEffect.new()
	e.effect_name = "穿透子弹"
	e.base_damage = 0
	e.projectile_count = 1
	e.penetration = 1
	e.speed = 500.0
	return e


## 创建火焰骰子投射物效果（点燃敌人）
static func _make_fire_projectile_effect() -> ProjectileEffect:
	var e := ProjectileEffect.new()
	e.effect_name = "火焰投射物"
	e.base_damage = 0
	e.projectile_count = 1
	e.penetration = 0
	e.speed = 500.0
	e.burn_duration = 2.0
	e.burn_tick_interval = 0.5
	e.burn_damage = 1
	return e


## 创建冰霜骰子投射物效果（减速/冰冻）
static func _make_frost_projectile_effect() -> ProjectileEffect:
	var e := ProjectileEffect.new()
	e.effect_name = "冰霜投射物"
	e.base_damage = 0
	e.projectile_count = 1
	e.penetration = 0
	e.speed = 550.0
	e.freeze_chance = 0.02  # 2% 基础冰冻概率
	e.freeze_duration = 2.0
	e.slow_duration = 2.0
	e.slow_factor = 0.5
	return e


## 创建山岳骰子 AOE 冲击效果
static func _make_aoe_effect(radius: float) -> SpellEffect:
	var e := SpellEffect.new()
	e.effect_name = "山岳冲击"
	e.base_damage = 0
	e.aoe_radius = radius
	e.delay = 0.2
	return e


## 快速创建一个 DiceMaterial 材质资源
##
## 这是材质创建的底层函数，在 _init() 里被调用 6 次，创建 6 种内置材质。
## 外部一般不直接调用，而是通过 DiceManager.get_material("flame") 获取已有材质。
##
## 参数说明：
##   name:       材质名称，如 "火焰"（显示在 Inspector 里）
##   pip_style:  点数图案类型（DiceMaterial.PipStyle 枚举），
##              决定骰面上的"点"长什么样：
##                CLASSIC → 经典圆点（标准/灌铅骰子）
##                FROST   → 雪花图案（冰霜骰子）
##                FLAME   → 火苗图案（火焰骰子）
##                GLASS   → 钻石图案（玻璃骰子）
##                LEAD    → 菱形图案（灌铅骰子）
##                CURSED  → 骷髅图案（诅咒骰子）
##   base_color: 骰面底色（Color），如火焰=暗红色、冰霜=暗蓝色
##   rarity:     稀有度，"common" / "rare" / "epic"，影响未来合成/商店的显示
##
## 根据 pip_style 自动设置对应的颜色：
##   - pip_color:       普通状态时点数的颜色
##   - crit_pip_color:  暴击状态时点数的颜色（更亮/更金）
##   - border_color:    骰面边缘的颜色
##
## 返回：配置好的 DiceMaterial 实例（不保存为 .tres 文件，运行时创建）
##       如果后续想在编辑器里微调颜色，可以创建 .tres 文件覆盖这些默认值
static func _make_material(name: String, pip_style: DiceMaterial.PipStyle, base_color: Color, rarity: String) -> DiceMaterial:
	var m := DiceMaterial.new()
	m.material_name = name
	m.pip_style = pip_style
	m.base_color = base_color
	m.rarity = rarity
	match pip_style:
		DiceMaterial.PipStyle.FROST:
			m.pip_color = Color(0.60, 0.90, 1.0)
			m.crit_pip_color = Color(0.90, 0.98, 1.0)
			m.border_color = Color(0.40, 0.70, 1.0)
		DiceMaterial.PipStyle.FLAME:
			m.pip_color = Color(1.0, 0.60, 0.15)
			m.crit_pip_color = Color(1.0, 0.95, 0.30)
			m.border_color = Color(1.0, 0.40, 0.10)
		DiceMaterial.PipStyle.GLASS:
			m.pip_color = Color(0.70, 0.85, 1.0)
			m.crit_pip_color = Color(1.0, 1.0, 1.0)
			m.border_color = Color(0.50, 0.70, 0.90)
		DiceMaterial.PipStyle.LEAD:
			m.pip_color = Color(0.55, 0.55, 0.60)
			m.crit_pip_color = Color(0.90, 0.85, 0.10)
		DiceMaterial.PipStyle.CURSED:
			m.pip_color = Color(0.70, 0.25, 0.25)
			m.crit_pip_color = Color(1.0, 0.30, 0.30)
		DiceMaterial.PipStyle.MOUNTAIN:
			m.pip_color = Color(0.55, 0.45, 0.30)
			m.crit_pip_color = Color(1.0, 0.70, 0.15)
			m.border_color = Color(0.35, 0.25, 0.15)
	return m
