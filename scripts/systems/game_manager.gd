## 游戏流程状态机（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 GameManager.xxx 直接访问。
##
## 管理游戏阶段切换：菜单 → 战斗 → 波次清空 → 升级 → 休息站 → BOSS → 结算
## 当前 MVP 阶段：MENU 和 BATTLE 阶段完整可用，其余留骨架。
##
extends Node


enum Phase {
	MENU,           ## 主菜单
	BATTLE,         ## 战斗中
	WAVE_CLEAR,     ## 波次清空 → 弹三选一
	LEVEL_UP,       ## 三选一升级中
	REST_STATION,   ## 休息站
	BOSS,           ## BOSS 战
	GAME_OVER,      ## 死亡 / 通关
}


@export_group("Debug")
## 当前阶段（只读查看）
@export var current_phase: Phase = Phase.MENU


func _ready() -> void:
	# 游戏从主菜单启动，不自动进入战斗
	# 当玩家点击"开始游戏"后，Main 场景加载，GameManager 由 Main 场景驱动
	print("🎮 GameManager 就绪，等待开始游戏")


## 阶段切换（统一入口）
func transition_to(new_phase: Phase) -> void:
	var old: Phase = current_phase
	current_phase = new_phase
	EventBus.game_phase_changed.emit(
		Phase.keys()[old] as StringName,
		Phase.keys()[new_phase] as StringName,
	)
	match new_phase:
		Phase.MENU:
			pass  # 菜单场景自己管理
		Phase.BATTLE:
			_start_battle()
		Phase.WAVE_CLEAR:
			_on_wave_clear()
		Phase.LEVEL_UP:
			_show_level_up()
		Phase.REST_STATION:
			_enter_rest_station()
		Phase.BOSS:
			_spawn_boss()
		Phase.GAME_OVER:
			_game_over()


## 战斗开始
func _start_battle() -> void:
	print("▶ 战斗开始")


## 波次清空
func _on_wave_clear() -> void:
	print("✅ 波次清空，升级选择...")
	## TODO M2：弹出三选一技能界面


## 显示升级界面
func _show_level_up() -> void:
	## TODO M2：加载 SkillData 三选一
	pass


## 进入休息站
func _enter_rest_station() -> void:
	## TODO M4：加载休息站场景
	pass


## 生成 BOSS
func _spawn_boss() -> void:
	## TODO M3：生成 BOSS 敌人
	pass


## 游戏结束
func _game_over() -> void:
	print("💀 游戏结束")
	## TODO：显示结算界面，可选重新开始
	var err := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if err != OK:
		get_tree().reload_current_scene()
