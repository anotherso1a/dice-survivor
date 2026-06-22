# 召唤执行器 - 骷髅/精灵/炮台（待实现）
class_name SummonExecutor
extends AttackExecutor

func _execute_attack(face: FaceData, source: Node2D, effect: AttackEffect, damage: int, relics: Array[RelicData]) -> void:
	push_warning("SummonExecutor: 召唤尚未实现，face=%d, damage=%d" % [face.value, damage])
	# TODO: 实现召唤逻辑
	# 1. 根据 SummonEffect 的属性创建召唤物节点
	# 2. 设置召唤物位置（围绕玩家）
	# 3. 设置召唤物持续时间、伤害等
	# 4. 召唤物自动攻击敌人（倒计时结束后消失）
