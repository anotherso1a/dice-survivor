## 骰子面代码渲染器
##
## 根据 DiceMaterial（骰体材质）+ FaceData（骰点数据）动态生成骰面纹理。
## 每个骰面生成一次 ImageTexture，按 (material, face_data) 联合缓存。
##
## 点数图案按 DiceMaterial.pip_style 分支绘制：
##   CLASSIC → 经典圆点
##   FROST  → 雪花（6瓣像素风）
##   FLAME  → 火苗（三角+波浪像素风）
##   GLASS  → 菱形水晶
##   LEAD   → 实心圆点（沉重感）
##   CURSED → 骷髅/十字
##
## 用法：
##   var tex: Texture2D = DiceFaceRenderer.render(material, face_data)
##
class_name DiceFaceRenderer
extends RefCounted


# ========== 常量 ==========
const FACE_SIZE: int = 64
const HALF: int = FACE_SIZE / 2  # 32

# 纹理缓存：key = material.get_instance_id() xor face_cache_key，value = ImageTexture
static var _cache: Dictionary = {}


# ========== 公开接口 ==========

## 根据骰体材质 + 骰点数据生成（或取缓存）骰面纹理
static func render(material: DiceMaterial, face_data: FaceData) -> Texture2D:
	if material == null or face_data == null:
		return _make_fallback_texture()

	var cache_key: int = _calc_cache_key(material, face_data)
	if _cache.has(cache_key):
		return _cache[cache_key]

	var img := _draw_face(material, face_data)
	var tex := ImageTexture.create_from_image(img)
	_cache[cache_key] = tex
	return tex


## 清除缓存（切换遗物/合成骰子后调用）
static func clear_cache() -> void:
	_cache.clear()


# ========== 缓存 key ==========

static func _calc_cache_key(material: DiceMaterial, face_data: FaceData) -> int:
	# material 的 pip_style 是影响外观的关键
	var h: int = int(material.pip_style) * 9973
	h = h * 31 + hash(face_data.face_type)
	h = h * 31 + hash(face_data.value)
	h = h * 31 + hash(face_data.damage)
	h = h * 31 + hash(face_data.is_crit)
	h = h * 31 + hash(face_data.element)
	h = h * 31 + hash(face_data.element_power)
	h = h * 31 + hash(face_data.self_damage)
	return h


# ========== 主绘制流程 ==========

static func _draw_face(material: DiceMaterial, face_data: FaceData) -> Image:
	var img := Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)

	# 1. 底色 + 圆角
	_fill_background(img, material, face_data)

	# 2. 光影效果
	_draw_lighting(img, material)

	# 3. 边框
	_draw_border(img, material)

	# 4. 点数（按 pip_style 分支）
	_draw_pips(img, material, face_data)

	# 5. 伤害数值
	if face_data.damage > 0:
		_draw_damage_number(img, face_data, material)

	# 6. 元素角标
	if not face_data.element.is_empty():
		_draw_element_badge(img, face_data)

	# 7. 暴击闪光
	if face_data.is_crit:
		_draw_crit_effect(img, material)

	# 8. 诅咒暗角
	if face_data.face_type == FaceData.FaceType.CURSED:
		_draw_curse_vignette(img)

	return img


# ========== 底层绘制 ==========

## 底色填充（带圆角）
static func _fill_background(img: Image, mat: DiceMaterial, _face_data: FaceData) -> void:
	var bg: Color = mat.base_color
	for y in range(FACE_SIZE):
		for x in range(FACE_SIZE):
			if _is_outside_rounded_corner(x, y):
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				img.set_pixel(x, y, bg)


## 光影：左上角高光，右下角阴影
static func _draw_lighting(img: Image, mat: DiceMaterial) -> void:
	var hi := mat.highlight_color
	var sh := mat.shadow_color
	for y in range(FACE_SIZE):
		for x in range(FACE_SIZE):
			if _is_outside_rounded_corner(x, y):
				continue
			var px := Vector2(x, y)
			var center := Vector2(HALF, HALF)
			var dist: float = px.distance_to(center)
			var max_dist: float = HALF * 0.9
			if dist > max_dist:
				continue

			var t: float = dist / max_dist
			var light_dir := Vector2(-1, -1).normalized()
			var pixel_dir := (px - center).normalized()
			var dot: float = light_dir.dot(pixel_dir)

			var highlight: float = clamp(dot * 0.15 + 0.05, 0.0, 0.2)
			var shadow: float = clamp(-dot * 0.12, 0.0, 0.15)

			var c: Color = img.get_pixel(x, y)
			c.r = clampf(c.r + highlight - shadow, 0.0, 1.0)
			c.g = clampf(c.g + highlight - shadow, 0.0, 1.0)
			c.b = clampf(c.b + highlight - shadow, 0.0, 1.0)
			img.set_pixel(x, y, c)


## 边框
static func _draw_border(img: Image, mat: DiceMaterial) -> void:
	var border: Color = mat.border_color
	var thickness: int = 2
	for y in range(FACE_SIZE):
		for x in range(FACE_SIZE):
			if _is_outside_rounded_corner(x, y):
				continue
			var d_edge: int = min(x, min(FACE_SIZE - 1 - x, min(y, FACE_SIZE - 1 - y)))
			if d_edge < thickness:
				img.set_pixel(x, y, border)


# ========== 点数绘制（按 pip_style 分派）==========

static func _draw_pips(img: Image, mat: DiceMaterial, face_data: FaceData) -> void:
	var value: int = clampi(face_data.value, 1, 6)
	var pip_color: Color = mat.pip_color
	if face_data.is_crit:
		pip_color = mat.crit_pip_color

	match mat.pip_style:
		DiceMaterial.PipStyle.FROST:
			_draw_snowflake_pips(img, value, pip_color)
		DiceMaterial.PipStyle.FLAME:
			_draw_flame_pips(img, value, pip_color)
		DiceMaterial.PipStyle.GLASS:
			_draw_diamond_pips(img, value, pip_color)
		DiceMaterial.PipStyle.LEAD:
			_draw_filled_pips(img, value, pip_color)
		DiceMaterial.PipStyle.CURSED:
			_draw_cross_pips(img, value, pip_color)
		_:
			_draw_classic_pips(img, value, pip_color)


## 经典圆点
static func _draw_classic_pips(img: Image, value: int, pip_color: Color) -> void:
	var r: int = 5
	match value:
		1: _draw_pip(img, Vector2(HALF, HALF), r, pip_color)
		2:
			_draw_pip(img, Vector2(HALF, 14), r, pip_color)
			_draw_pip(img, Vector2(HALF, FACE_SIZE - 14), r, pip_color)
		3:
			_draw_pip(img, Vector2(HALF, 14), r, pip_color)
			_draw_pip(img, Vector2(HALF, HALF), r, pip_color)
			_draw_pip(img, Vector2(HALF, FACE_SIZE - 14), r, pip_color)
		4:
			_draw_pip(img, Vector2(14, 14), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, 14), r, pip_color)
			_draw_pip(img, Vector2(14, FACE_SIZE - 14), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, FACE_SIZE - 14), r, pip_color)
		5:
			_draw_pip(img, Vector2(14, 14), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, 14), r, pip_color)
			_draw_pip(img, Vector2(HALF, HALF), r, pip_color)
			_draw_pip(img, Vector2(14, FACE_SIZE - 14), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, FACE_SIZE - 14), r, pip_color)
		6:
			_draw_pip(img, Vector2(14, 14), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, 14), r, pip_color)
			_draw_pip(img, Vector2(14, HALF), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, HALF), r, pip_color)
			_draw_pip(img, Vector2(14, FACE_SIZE - 14), r, pip_color)
			_draw_pip(img, Vector2(FACE_SIZE - 14, FACE_SIZE - 14), r, pip_color)


## 雪花点数（6瓣像素风）
static func _draw_snowflake_pips(img: Image, value: int, pip_color: Color) -> void:
	var positions := _get_pip_positions(value)
	for pos in positions:
		_draw_snowflake(img, pos, 6, pip_color)


## 火苗点数（三角+波浪像素风）
static func _draw_flame_pips(img: Image, value: int, pip_color: Color) -> void:
	var positions := _get_pip_positions(value)
	for pos in positions:
		_draw_flame(img, pos, 8, pip_color)


## 菱形水晶点数
static func _draw_diamond_pips(img: Image, value: int, pip_color: Color) -> void:
	var positions := _get_pip_positions(value)
	for pos in positions:
		_draw_diamond(img, pos, 7, pip_color)


## 实心圆点（沉重感）
static func _draw_filled_pips(img: Image, value: int, pip_color: Color) -> void:
	var positions := _get_pip_positions(value)
	for pos in positions:
		_draw_filled_pip(img, pos, 6, pip_color)


## 十字/骷髅点数（诅咒骰子）
static func _draw_cross_pips(img: Image, value: int, pip_color: Color) -> void:
	var positions := _get_pip_positions(value)
	for pos in positions:
		_draw_cross(img, pos, 7, pip_color)


# ========== 图案绘制函数 ==========

## 绘制单个雪花（6瓣，像素风）
static func _draw_snowflake(img: Image, center: Vector2, size: int, color: Color) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	# 中心圆
	for y in range(cy - 2, cy + 3):
		for x in range(cx - 2, cx + 3):
			if _in_bounds(x, y) and Vector2(x, y).distance_to(center) <= 2.0:
				img.set_pixel(x, y, color)
	# 6个方向的分支
	var dirs := [Vector2(0, -1), Vector2(0.87, 0.5), Vector2(-0.87, 0.5),
				 Vector2(0, 1), Vector2(-0.87, -0.5), Vector2(0.87, -0.5)]
	for dir in dirs:
		for i in range(1, size):
			var px: int = cx + int(dir.x * i)
			var py: int = cy + int(dir.y * i)
			if _in_bounds(px, py):
				img.set_pixel(px, py, color)
			# 分支小叉
			if i == 2 or i == 3:
				var perp := Vector2(-dir.y, dir.x)
				var bx: int = px + int(perp.x)
				var by: int = py + int(perp.y)
				if _in_bounds(bx, by):
					img.set_pixel(bx, by, color)


## 绘制单个火苗（像素风：底部宽三角 + 顶部尖，带波浪边缘）
static func _draw_flame(img: Image, center: Vector2, size: int, color: Color) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	for y in range(cy - size, cy + size + 1):
		for x in range(cx - size, cx + size + 1):
			if not _in_bounds(x, y):
				continue
			var dx: float = abs(x - cx) / float(size)
			var dy: float = (y - cy) / float(size)  # -1（上）~ +1（下）
			# 火焰形状：下半（dy>0）宽，上半（dy<0）窄
			var threshold: float = 0.0
			if dy >= 0.0:
				# 下半部：宽三角
				threshold = 0.9 - dy * 0.7
			else:
				# 上半部：窄尖顶 + 正弦波浪边缘
				var wave: float = sin(x * 0.8 + y * 0.5) * 0.15
				threshold = 0.35 + wave + dy * 0.2
			if dx <= threshold:
				var c := color
				# 上半部半透明
				if dy < -0.3:
					c.a = 0.6
				img.set_pixel(x, y, c)
	# 高光（中心偏上，亮黄色）
	var hi_cx: int = cx
	var hi_cy: int = cy - 2
	if _in_bounds(hi_cx, hi_cy):
		var hi_color := Color(1.0, 1.0, 0.7, 1.0)
		for d in range(-1, 2):
			var px: int = hi_cx + d
			var py: int = hi_cy + d
			if _in_bounds(px, py):
				img.set_pixel(px, py, hi_color)


## 绘制单个菱形
static func _draw_diamond(img: Image, center: Vector2, size: int, color: Color) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	for y in range(cy - size, cy + size + 1):
		for x in range(cx - size, cx + size + 1):
			if not _in_bounds(x, y):
				continue
			var dx: int = abs(x - cx)
			var dy: int = abs(y - cy)
			if dx + dy <= size:
				img.set_pixel(x, y, color)
	# 内部高光（X 形）
	for i in range(-size, size + 1):
		var px1: int = cx + i
		var py1: int = cy + i
		var px2: int = cx + i
		var py2: int = cy - i
		if _in_bounds(px1, py1):
			var c := img.get_pixel(px1, py1)
			c = c.lerp(Color(1.0, 1.0, 1.0, 0.5), 0.3)
			img.set_pixel(px1, py1, c)
		if _in_bounds(px2, py2):
			var c := img.get_pixel(px2, py2)
			c = c.lerp(Color(1.0, 1.0, 1.0, 0.5), 0.3)
			img.set_pixel(px2, py2, c)


## 绘制单个实心圆点
static func _draw_filled_pip(img: Image, center: Vector2, radius: int, color: Color) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	for y in range(cy - radius - 2, cy + radius + 3):
		for x in range(cx - radius - 2, cx + radius + 3):
			if not _in_bounds(x, y):
				continue
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= radius + 1:
				var c := color
				if dist > radius - 1:
					c.a = 1.0 - (dist - radius + 1.0)  # 抗锯齿
				img.set_pixel(x, y, c)


## 绘制单个十字
static func _draw_cross(img: Image, center: Vector2, size: int, color: Color) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	# 竖线
	for y in range(cy - size, cy + size + 1):
		if _in_bounds(cx, y):
			img.set_pixel(cx, y, color)
	# 横线
	for x in range(cx - size, cx + size + 1):
		if _in_bounds(x, cy):
			img.set_pixel(x, cy, color)
	# 四角小点（装饰）
	for corner in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		var px: int = cx + int(corner.x)
		var py: int = cy + int(corner.y)
		if _in_bounds(px, py):
			img.set_pixel(px, py, color)


# ========== 辅助：获取骰点位置 ==========

static func _get_pip_positions(value: int) -> Array[Vector2]:
	match value:
		1: return [Vector2(HALF, HALF)]
		2: return [Vector2(HALF, 14), Vector2(HALF, FACE_SIZE - 14)]
		3: return [Vector2(HALF, 14), Vector2(HALF, HALF), Vector2(HALF, FACE_SIZE - 14)]
		4: return [Vector2(14, 14), Vector2(FACE_SIZE - 14, 14),
				Vector2(14, FACE_SIZE - 14), Vector2(FACE_SIZE - 14, FACE_SIZE - 14)]
		5: return [Vector2(14, 14), Vector2(FACE_SIZE - 14, 14), Vector2(HALF, HALF),
				Vector2(14, FACE_SIZE - 14), Vector2(FACE_SIZE - 14, FACE_SIZE - 14)]
		6: return [Vector2(14, 14), Vector2(FACE_SIZE - 14, 14),
				Vector2(14, HALF), Vector2(FACE_SIZE - 14, HALF),
				Vector2(14, FACE_SIZE - 14), Vector2(FACE_SIZE - 14, FACE_SIZE - 14)]
		_: return [Vector2(HALF, HALF)]


static func _draw_pip(img: Image, center: Vector2, radius: int, color: Color) -> void:
	_draw_filled_pip(img, center, radius, color)


# ========== 其他绘制（伤害数字、元素角标、暴击、诅咒）==========

static func _draw_damage_number(img: Image, face_data: FaceData, _mat: DiceMaterial) -> void:
	var dmg: int = face_data.damage
	var color: Color = Color(0.75, 0.75, 0.80)
	if dmg >= 15:
		color = Color(1.0, 0.25, 0.25)
	elif dmg >= 8:
		color = Color(0.95, 0.65, 0.20)
	var text: String = str(dmg)
	_draw_small_text(img, text, Vector2(40, 44), color)


static func _draw_element_badge(img: Image, face_data: FaceData) -> void:
	var elem: StringName = face_data.element
	var color: Color = Color(1, 1, 1, 1)
	match elem:
		&"fire": color = Color(1.0, 0.35, 0.10)
		&"ice": color = Color(0.20, 0.65, 1.0)
		&"thunder": color = Color(1.0, 0.90, 0.20)

	var center := Vector2(FACE_SIZE - 12, 12)
	var r: int = 8
	for y in range(FACE_SIZE):
		for x in range(FACE_SIZE):
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= r:
				var c := color
				c.a = 0.9
				img.set_pixel(x, y, c)
			elif dist <= r + 1.5:
				var c := color
				c.a = 0.4
				img.set_pixel(x, y, c)
	# 白色边框
	for angle in range(0, 360, 5):
		var rad := deg_to_rad(angle)
		var px: int = int(center.x + r * cos(rad))
		var py: int = int(center.y + r * sin(rad))
		if _in_bounds(px, py):
			var c: Color = img.get_pixel(px, py)
			c = c.lerp(Color.WHITE, 0.5)
			img.set_pixel(px, py, c)


static func _draw_crit_effect(img: Image, mat: DiceMaterial) -> void:
	# 四角星
	var star_positions := [Vector2(6, 6), Vector2(FACE_SIZE - 6, 6),
						 Vector2(6, FACE_SIZE - 6), Vector2(FACE_SIZE - 6, FACE_SIZE - 6)]
	for sp in star_positions:
		_draw_small_pixel_star(img, sp, 2, Color(1.0, 0.9, 0.2, 1.0))
	# 外发光
	for y in range(FACE_SIZE):
		for x in range(FACE_SIZE):
			var d_edge: int = min(x, min(FACE_SIZE - 1 - x, min(y, FACE_SIZE - 1 - y)))
			if d_edge == 2:
				var c: Color = img.get_pixel(x, y)
				c = c.lerp(Color(1.0, 0.85, 0.1, 1.0), 0.5)
				img.set_pixel(x, y, c)


static func _draw_curse_vignette(img: Image) -> void:
	var center := Vector2(HALF, HALF)
	for y in range(FACE_SIZE):
		for x in range(FACE_SIZE):
			var dist: float = Vector2(x, y).distance_to(center)
			var t: float = clamp(dist / HALF, 0.0, 1.0)
			if t > 0.5:
				var c: Color = img.get_pixel(x, y)
				c = c.lerp(Color(0.15, 0.05, 0.05), (t - 0.5) * 1.5)
				img.set_pixel(x, y, c)


# ========== 辅助工具函数 ==========

static func _is_outside_rounded_corner(x: int, y: int) -> bool:
	var corner_r: int = 8
	if x < corner_r and y < corner_r:
		return Vector2(x, y).distance_to(Vector2(corner_r, corner_r)) > corner_r
	if x >= FACE_SIZE - corner_r and y < corner_r:
		return Vector2(x, y).distance_to(Vector2(FACE_SIZE - corner_r - 1, corner_r)) > corner_r
	if x < corner_r and y >= FACE_SIZE - corner_r:
		return Vector2(x, y).distance_to(Vector2(corner_r, FACE_SIZE - corner_r - 1)) > corner_r
	if x >= FACE_SIZE - corner_r and y >= FACE_SIZE - corner_r:
		return Vector2(x, y).distance_to(Vector2(FACE_SIZE - corner_r - 1, FACE_SIZE - corner_r - 1)) > corner_r
	return false


static func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < FACE_SIZE and y >= 0 and y < FACE_SIZE


static func _draw_small_text(img: Image, text: String, pos: Vector2, color: Color) -> void:
	var font := {
		'0': [0b010, 0b101, 0b101, 0b101, 0b010],
		'1': [0b001, 0b011, 0b001, 0b001, 0b011],
		'2': [0b010, 0b101, 0b010, 0b010, 0b101],
		'3': [0b010, 0b101, 0b010, 0b101, 0b010],
		'4': [0b101, 0b101, 0b111, 0b001, 0b001],
		'5': [0b101, 0b010, 0b010, 0b101, 0b010],
		'6': [0b010, 0b101, 0b110, 0b101, 0b010],
		'7': [0b101, 0b001, 0b010, 0b010, 0b010],
		'8': [0b010, 0b101, 0b010, 0b101, 0b010],
		'9': [0b010, 0b101, 0b011, 0b101, 0b010],
		'+': [0b000, 0b010, 0b111, 0b010, 0b000],
	}
	var px_scale: int = 2
	var offset_x: int = 0
	for ch in text:
		var bitmap: Array = font.get(str(ch), [])
		if bitmap.is_empty():
			offset_x += 4 * px_scale
			continue
		for row in range(bitmap.size()):
			var bits: int = bitmap[row]
			for col in range(3):
				if (bits >> (2 - col)) & 1:
					for dy in range(px_scale):
						for dx in range(px_scale):
							var px: int = int(pos.x) + offset_x + col * px_scale + dx
							var py: int = int(pos.y) + row * px_scale + dy
							if _in_bounds(px, py):
								img.set_pixel(px, py, color)
		offset_x += 4 * px_scale


static func _draw_small_pixel_star(img: Image, center: Vector2, size: int, color: Color) -> void:
	var cx: int = int(center.x)
	var cy: int = int(center.y)
	for i in range(-size, size + 1):
		if _in_bounds(cx + i, cy):
			img.set_pixel(cx + i, cy, color)
		if _in_bounds(cx, cy + i):
			img.set_pixel(cx, cy + i, color)


static func _make_fallback_texture() -> Texture2D:
	var img := Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.3, 1.0))
	for i in range(FACE_SIZE):
		img.set_pixel(i, i, Color.RED)
		img.set_pixel(FACE_SIZE - 1 - i, i, Color.RED)
	var tex := ImageTexture.create_from_image(img)
	return tex
