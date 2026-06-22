extends Area2D
class_name Bullet

## ═══════════════════════════════════════════════════════════
## 子弹基类 - 处理碰撞检测、穿透逻辑、元素效果
## 子类可以继承此类并重写 _apply_element_effect() 来实现自定义效果
## ═══════════════════════════════════════════════════════════

const AttackEffect = preload("res://scripts/core/attack_effect.gd")

@export var speed: float = 500.0
@export var bullet_color: Color = Color.YELLOW

## 调试开关：开启后打印碰撞检测每一步
@export var debug: bool = false

var _direction: Vector2 = Vector2.RIGHT
var _damage: int = 10
var _face: FaceData
var _penetration: int = 0
var _damage_mult: float = 1.0
var _effect: ProjectileEffect = null  # 攻击效果配置
var _hit_enemies: Array[Node2D] = []

## 流星尾焰（仅 1 点子弹启用）
var _trail: Line2D = null
const _TRAIL_MAX_POINTS: int = 10

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	monitoring = true
	collision_mask = 2

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if _sprite != null and _sprite.texture == null:
		_sprite.texture = _create_texture()
		_sprite.modulate = bullet_color

	## 1点特殊效果：金色外观 + 放大 + 流星尾焰
	if _penetration == -1:
		_setup_special_effect()

	if debug:
		print("[Bullet] _ready | pos=%s | pen=%d | mult=%.1f" % [
			global_position, _penetration, _damage_mult])


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	## 流星尾焰：每帧记录位置，旧点淡出
	if _trail:
		_trail.add_point(global_position)
		if _trail.get_point_count() > _TRAIL_MAX_POINTS:
			_trail.remove_point(0)

	if _is_off_screen():
		queue_free()


func _exit_tree() -> void:
	if _trail:
		_trail.queue_free()


## body_entered 回调：敌人 CharacterBody2D 进入子弹范围
func _on_body_entered(body: Node2D) -> void:
	if debug:
		print("[Bullet] body_entered | %s" % body.name)
	_handle_hit(body)


## area_entered 回调：敌人 Hitbox (Area2D) 进入子弹范围
func _on_area_entered(area: Area2D) -> void:
	if debug:
		print("[Bullet] area_entered | %s" % area.name)
	var parent: Node2D = area.get_parent()
	if parent != null and parent != self:
		_handle_hit(parent)


## 命中处理：去重 → 组检查 → 元素效果 → 伤害 → 穿透判定
func _handle_hit(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	## 去重：防止 body_entered + area_entered 双触发同一敌人
	if body in _hit_enemies:
		return

	## 只处理 "enemies" 组
	if not body.is_in_group("enemies"):
		return

	_hit_enemies.append(body)
	var final_damage: int = _damage
	if _penetration == -1:  # 1点特殊效果
		final_damage = int(final_damage * _damage_mult)
	_apply_element_effect(body)

	if body.has_method("take_damage"):
		if debug:
			print("[Bullet] hit %s | dmg=%d | pen=%d" % [body.name, final_damage, _penetration])
		body.take_damage(final_damage, (_face.is_crit if _face else false), _face)

	## 穿透逻辑：
	## -1 = 无限穿透，继续飞行
	##  0 = 无穿透，命中即销毁
	##  1+ = 可额外穿透 N 个敌人（共命中 N+1 个）
	if _penetration == -1:
		return
	_penetration -= 1
	if _penetration < 0:
		queue_free()


## 应用元素效果（子类可重写此方法）
func _apply_element_effect(body: Node2D) -> void:
	if _effect == null or not body.has_node("StatusComponent"):
		return

	var status_comp = body.get_node("StatusComponent") as StatusComponent
	if status_comp == null:
		return

	## 根据 effect.element 应用对应效果
	match _effect.element:
		AttackEffect.ElementType.FROST:
			status_comp.apply_freeze(_effect.freeze_duration, _effect.freeze_chance)
			status_comp.apply_slow(_effect.slow_duration, _effect.slow_factor)
		AttackEffect.ElementType.FIRE:
			status_comp.apply_burn(_effect.burn_duration, _effect.burn_tick_interval, _effect.burn_damage)
		AttackEffect.ElementType.LIGHTNING:
			## TODO: 闪电效果
			pass
		AttackEffect.ElementType.POISON:
			## TODO: 毒液效果
			pass


## 配置子弹参数（实例化后、add_child 前调用）
func setup(direction: Vector2, damage: int, face: FaceData, 
			 penetration: int, damage_mult: float, 
			 effect: ProjectileEffect = null) -> void:
	_direction = direction.normalized()
	_damage = damage
	_face = face
	_penetration = penetration
	_damage_mult = damage_mult
	_effect = effect

	## 根据元素效果设置子弹颜色（_ready() 会用 bullet_color 上色）
	## 注意：必须在 _ready() 之前调用，否则颜色设置不生效
	if _effect != null:
		if _effect.element == AttackEffect.ElementType.FIRE:
			bullet_color = Color(1.0, 0.4, 0.1)  # 火焰：橙红色
		elif _effect.element == AttackEffect.ElementType.FROST:
			bullet_color = Color(0.3, 0.7, 1.0)  # 冰霜：冰蓝色
		else:
			bullet_color = Color.YELLOW  # 默认：黄色
	else:
		bullet_color = Color.YELLOW  # 无元素效果：黄色


## 1点特殊效果：金色外观 + 放大 + Line2D 流星尾焰
func _setup_special_effect() -> void:
	bullet_color = Color(1.0, 0.85, 0.2)

	if _sprite:
		_sprite.modulate = bullet_color
		_sprite.scale = Vector2(0.6, 0.6)

	## 流星尾焰：Line2D 记录最近 N 帧位置，渐变从尾(透明)到头(不透明)
	_trail = Line2D.new()
	_trail.name = "Trail"
	_trail.width = 5.0
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND

	var g: Gradient = Gradient.new()
	g.add_point(0.0, Color(bullet_color, 0.0))
	g.add_point(0.5, Color(bullet_color, 0.5))
	g.add_point(1.0, Color(bullet_color, 1.0))
	_trail.gradient = g

	## 挂到场景根节点（非子弹子节点），这样尾焰留在世界空间不会跟着子弹平移
	get_tree().current_scene.add_child(_trail)


func _is_off_screen() -> bool:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return false
	var rect: Rect2 = Rect2(
		cam.global_position - get_viewport_rect().size * 0.6,
		get_viewport_rect().size * 1.2
	)
	return not rect.has_point(global_position)


## 根据骰面点数计算穿透参数
## 返回 [penetration, damage_mult]
## penetration: -1=无限穿透, 0=不穿透, 1+=额外穿透次数
static func calc_penetration(face_value: int) -> Array:
	match face_value:
		1: return [-1, 1.5]
		2, 3: return [0, 1.0]
		4, 5, 6: return [1, 1.0]
		_: return [0, 1.0]


## 代码生成圆形纹理（无外部资源时的兜底）
static func _create_texture() -> Texture2D:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x: int in range(16):
		for y: int in range(16):
			if Vector2(x - 7.5, y - 7.5).length() <= 7.0:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)
