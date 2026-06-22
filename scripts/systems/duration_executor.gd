# 持续效果执行器 - 火焰路径/毒云/治疗光环（待实现）
class_name DurationExecutor
extends AttackExecutor

func _execute_attack(face: FaceData, source: Node2D, effect: AttackEffect, damage: int, relics: Array[RelicData]) -> void:
	push_warning("DurationExecutor: 持续效果尚未实现，face=%d, damage=%d" % [face.value, damage])
	# TODO: 实现持续效果逻辑
	# 1. 在场景中放置持续效果区域（Area2D）
	# 2. 设置持续时间、tick 频率、范围
	# 3. 周期性对范围内敌人造成伤害/效果
