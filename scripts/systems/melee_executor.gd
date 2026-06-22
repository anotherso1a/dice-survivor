# 近战攻击执行器 - 挥砍/戳刺/旋转（待实现）
class_name MeleeExecutor
extends AttackExecutor

func _execute_attack(face: FaceData, source: Node2D, effect: AttackEffect, damage: int, relics: Array[RelicData]) -> void:
	push_warning("MeleeExecutor: 近战攻击尚未实现，face=%d, damage=%d" % [face.value, damage])
	# TODO: 实现近战攻击逻辑
	# 1. 根据 MeleeEffect 的形状（扇形/圆形/直线）检测敌人
	# 2. 应用伤害 + 元素效果
	# 3. 播放射击 VFX
