## 村庄 NPC 基类（VillageNPC）
##
## 村庄里所有可交互 NPC 的基类。
## 子类可覆写 _on_interact() 实现具体互动内容（商人、铁匠、赌徒 NPC 等）。
##
class_name VillageNPC
extends Node2D

## 互动请求信号（供村庄场景监听，决定启动哪个小游戏/UI）
signal interaction_triggered(npc: VillageNPC)

## NPC 类型枚举
enum NPCType {
	GAMBLER,     ## 赌徒（骰盅赌斗）
	MERCHANT,    ## 商人（购买骰子/遗物）
	BLACKSMITH,  ## 铁匠（合成/强化）
	HEALER,      ## 医师（回血/卖血）
	MARKET,      ## 市场（骰子背包管理）
}

@export var npc_type: NPCType = NPCType.GAMBLER
@export var npc_display_name: String = "神秘人"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var name_label: Label = $NameLabel
@onready var interact_hint: Label = $InteractHint

var _idle_timer: float = 0.0
var _origin_y: float = 0.0


func _ready() -> void:
	name_label.text = npc_display_name
	_origin_y = sprite.position.y
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	if interact_hint:
		interact_hint.hide()


func _process(delta: float) -> void:
	## NPC 空闲呼吸动画
	_idle_timer += delta
	sprite.position.y = _origin_y + sin(_idle_timer * 2.5) * 1.5
	name_label.position.y = -60 + sin(_idle_timer * 2.5) * 1.0


func _on_body_entered(body: Node2D) -> void:
	print("[NPC:%s] body_entered: %s" % [npc_display_name, body.name])
	if body is VillagePlayer:
		(body as VillagePlayer).set_nearby_npc(self)
		if interact_hint:
			interact_hint.text = "[F]"
			interact_hint.show()


func _on_body_exited(body: Node2D) -> void:
	if body is VillagePlayer:
		(body as VillagePlayer).set_nearby_npc(null)
	if interact_hint:
		interact_hint.hide()


## 玩家按下交互键时，由 VillagePlayer 调用
func interact() -> void:
	## 交互反馈弹跳
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.08)
		tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.12)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	interaction_triggered.emit(self)
	_on_interact()


## 子类覆写：具体互动逻辑
func _on_interact() -> void:
	pass
