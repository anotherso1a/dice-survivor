## 骰子投射物视觉特效 + 命中结算
##
## 业界标准攻击时序：
##   骰子投出 → 投射物飞行(0.3s) → 命中瞬间(on_hit回调) →
##     ├── 结算伤害 (enemy.take_damage)
##     ├── 伤害数字弹出
##     ├── hitstop 停帧
##     └── 屏幕微震
##   → 命中闪光放大 → 淡出消失
##
## 用法：
##   在 Main.tscn 中挂载此节点，然后调用：
##   $DiceProjectileFX.play(from, to, face, material, func():
##       enemy.take_damage(...)
##       ...
##   )
##
class_name DiceProjectileFX
extends Node2D


## ─── 空回调（默认值，防止没传 on_hit 时报错）────────────────
func _noop() -> void:
	pass


## 播放一次骰子投射物动画 + 命中结算
## from_pos: 起始位置（玩家坐标）
## to_pos:   终点位置（敌人坐标）
## face:     掷出的骰面数据
## material: 骰子材质（决定外观）
## on_hit:   命中瞬间回调 — 在这里结算伤害、弹出伤害数字、hitstop等
func play(from_pos: Vector2, to_pos: Vector2, face: FaceData, material: DiceMaterial, on_hit: Callable = _noop) -> void:
	# 1. 渲染骰面纹理
	var tex: Texture2D = DiceFaceRenderer.render(material, face)

	# 2. 创建精灵
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.global_position = from_pos + Vector2(randf_range(-10, 10), randf_range(-15, -5))
	sprite.scale = Vector2(0.45, 0.45)
	sprite.z_index = 100
	get_tree().current_scene.add_child(sprite)

	# 3. 动画：飞行 + 旋转 + 渐缩
	var tw := create_tween()
	tw.set_parallel(true)

	# 飞行路径：带微小弧度（用两个 tween 制造抛物线感）
	var mid := (from_pos + to_pos) * 0.5 + Vector2(0, -40)
	tw.tween_property(sprite, "global_position", mid, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "global_position", to_pos, 0.18).set_ease(Tween.EASE_IN).set_delay(0.12)

	# 旋转（2 圈）+ 缩放缩小
	tw.tween_property(sprite, "rotation", TAU * 2, 0.3)
	tw.tween_property(sprite, "scale", Vector2(0.25, 0.25), 0.3)
	tw.set_parallel(false)

	# 4. 🔥 命中瞬间：先结算伤害/反馈，再放闪光
	tw.tween_callback(on_hit)

	# 5. 命中闪光：放大 + 高亮
	tw.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.06)
	tw.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.06)

	# 6. 淡出消失
	tw.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tw.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.15)

	# 7. 清理
	tw.tween_callback(sprite.queue_free)


## 快速版本：使用预生成的骰面纹理（无需重新渲染）
## 用于从 DiceEntity 已有的 _face_textures 直接复用
func play_with_texture(from_pos: Vector2, to_pos: Vector2, face_texture: Texture2D) -> void:
	if face_texture == null:
		return

	var sprite := Sprite2D.new()
	sprite.texture = face_texture
	sprite.global_position = from_pos + Vector2(randf_range(-10, 10), randf_range(-15, -5))
	sprite.scale = Vector2(0.45, 0.45)
	sprite.z_index = 100
	get_tree().current_scene.add_child(sprite)

	var tw := create_tween()
	tw.set_parallel(true)

	var mid := (from_pos + to_pos) * 0.5 + Vector2(0, -40)
	tw.tween_property(sprite, "global_position", mid, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "global_position", to_pos, 0.18).set_ease(Tween.EASE_IN).set_delay(0.12)
	tw.tween_property(sprite, "rotation", TAU * 2, 0.3)
	tw.tween_property(sprite, "scale", Vector2(0.25, 0.25), 0.3)
	tw.set_parallel(false)

	tw.tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.06)
	tw.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.06)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tw.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.15)
	tw.tween_callback(sprite.queue_free)


## 显示范围攻击的冲击波圆环（AOE 骰子命中点）
## pos: 冲击中心位置
## radius: 冲击半径（像素）
static func show_impact_ring(pos: Vector2, radius: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var scene_root: Node = tree.current_scene
	if scene_root == null:
		return

	# 生成冲击波圆环纹理（环状，外亮内透）
	var ring_size: int = 64
	var img := Image.create(ring_size, ring_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(ring_size * 0.5, ring_size * 0.5)
	for y in range(ring_size):
		for x in range(ring_size):
			var dist := Vector2(x, y).distance_to(center)
			var r_norm: float = dist / (ring_size * 0.5)
			if r_norm > 0.65 and r_norm < 0.95:
				var t: float = 1.0 - abs(r_norm - 0.8) / 0.15
				img.set_pixel(x, y, Color(1.0, 0.7, 0.25, t * 0.8))

	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.global_position = pos
	sprite.z_index = 99
	sprite.scale = Vector2(radius / 32.0, radius / 32.0)
	scene_root.add_child(sprite)

	var tw := scene_root.create_tween()
	tw.tween_property(sprite, "scale", sprite.scale * 1.8, 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	tw.tween_callback(sprite.queue_free)
