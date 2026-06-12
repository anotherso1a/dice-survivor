## 游戏流程状态机（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 GameManager.xxx 直接访问。
##
## 管理游戏阶段切换：菜单 → 战斗 → 波次清空 → 升级 → 休息站 → BOSS → 结算
## 当前 MVP 阶段：只实现 BATTLE 和 GAME_OVER 阶段，其余留骨架。
##
## 对应旧文件：scripts/Main.gd 中的流程逻辑（部分）
## 迁移要点：
##   - 刷怪逻辑暂时保留在 arena 场景中（GameManager 只负责阶段切换）
##   - 后续 M2-M5 逐步将刷怪、波次管理移入此处
##
extends Node  # 继承 Node 基类；作为 Autoload 挂载到场景树根节点下


enum Phase {  # 枚举类型：定义游戏所有可能的阶段
	MENU,           ## 主菜单
	BATTLE,         ## 战斗中
	WAVE_CLEAR,     ## 波次清空 → 弹三选一
	LEVEL_UP,       ## 三选一升级中
	REST_STATION,   ## 休息站
	BOSS,           ## BOSS 战
	GAME_OVER,      ## 死亡 / 通关
}


@export_group("Debug")  # 在 Inspector 面板中创建 "Debug" 分组，方便调试时查看
## 当前阶段（只读查看）
@export var current_phase: Phase = Phase.BATTLE  # 导出变量：当前游戏阶段，初始为 BATTLE，可在 Inspector 中查看


## 【_ready() 生命周期】
## 节点进入场景树后自动调用，此时节点已在树中，可安全访问兄弟/父节点。
## 与 _init() 的区别：_init() 是构造器（节点还没进场景树），_ready() 是节点就绪后调用。
func _ready() -> void:
	## MVP：直接进入战斗
	transition_to(Phase.BATTLE)  # 游戏启动后立即切换到战斗阶段


## 阶段切换（统一入口）
func transition_to(new_phase: Phase) -> void:
	var old: Phase = current_phase  # 保存旧阶段，用于发射信号时告知监听方
	current_phase = new_phase  # 更新当前阶段为新阶段
	EventBus.game_phase_changed.emit(  # 通过 EventBus 信号总线发射阶段切换信号，所有订阅方都会收到通知
		Phase.keys()[old] as StringName,  # 将旧阶段枚举值转为字符串名（如 "BATTLE"），供 UI 显示
		Phase.keys()[new_phase] as StringName,  # 将新阶段枚举值转为字符串名
	)
	match new_phase:  # 模式匹配：根据新阶段执行对应的逻辑分支
		Phase.BATTLE:  # 新阶段为战斗
			_start_battle()  # 调用战斗开始方法
		Phase.WAVE_CLEAR:  # 新阶段为波次清空
			_on_wave_clear()  # 调用波次清空处理方法
		Phase.LEVEL_UP:  # 新阶段为升级选择
			_show_level_up()  # 调用升级界面显示方法
		Phase.REST_STATION:  # 新阶段为休息站
			_enter_rest_station()  # 调用休息站进入方法
		Phase.BOSS:  # 新阶段为 BOSS 战
			_spawn_boss()  # 调用 BOSS 生成方法
		Phase.GAME_OVER:  # 新阶段为游戏结束
			_game_over()  # 调用游戏结束方法


## 战斗开始
func _start_battle() -> void:
	print("▶ 战斗开始")  # 控制台输出日志，便于调试
	## 刷怪由 arena 场景控制，此处只负责阶段逻辑


## 波次清空
func _on_wave_clear() -> void:
	print("✅ 波次清空，升级选择...")  # 控制台输出日志
	## TODO M2：弹出三选一技能界面


## 显示升级界面
func _show_level_up() -> void:
	## TODO M2：加载 SkillData 三选一
	pass  # 占位：暂时不实现，pass 保证函数体不为空


## 进入休息站
func _enter_rest_station() -> void:
	## TODO M4：加载休息站场景
	pass  # 占位：暂时不实现


## 生成 BOSS
func _spawn_boss() -> void:
	## TODO M3：生成 BOSS 敌人
	pass  # 占位：暂时不实现


## 游戏结束
func _game_over() -> void:
	print("💀 游戏结束")  # 控制台输出日志
	## TODO：显示结算界面，可选重新开始
	get_tree().reload_current_scene()  # 获取场景树并重新加载当前场景，实现重启游戏
