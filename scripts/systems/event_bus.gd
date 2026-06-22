## 全局信号总线（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 EventBus.xxx 直接访问，无需获取节点引用。
##
## 【信号总线模式（Signal Bus）】
## EventBus 是所有场景都能访问的全局信号中心。
## 发送方只需 EventBus.xxx.emit(...)，接收方只需 EventBus.xxx.connect(callback)，
## 双方完全解耦——发送方不知道谁在监听，接收方也不知道谁在发送。
## 这比直接调用方法或 get_parent() 更松耦合，特别适合跨场景通信。
##
## 使用规则：
##   - 跨场景通信 → 用 EventBus 信号
##   - 场景内通信 → 用节点直接信号连接
##   - 禁止子节点 get_parent() 调用父方法
##   - 禁止 UI 直接引用游戏实体节点
##
## 注意：所有信号参数必须类型标注，零 untyped 信号。
##
extends Node  # 继承 Node 基类；作为 Autoload 挂载到场景树根节点下


## ========== 战斗 ==========
## 敌人死亡：发出位置 + 敌人数据
signal enemy_died(pos: Vector2, enemy_data: EnemyData)  # 信号声明：敌人死亡时触发，携带死亡位置和敌人数据，供掉落/特效等系统订阅
## 波次开始
signal wave_started(wave_index: int)  # 信号声明：新一波敌人开始时触发，携带波次序号
## 波次清空
signal wave_cleared(wave_index: int)  # 信号声明：当前波次所有敌人被消灭时触发，携带波次序号


## ========== 骰子 ==========
## 骰子投掷完成：投掷者（骰子实体）+ 骰面数据 + 是否暴击
signal dice_rolled(dice_entity: Node2D, face: FaceData, is_crit: bool)  # 信号声明：骰子落地后触发，携带骰子节点、落地面数据、是否暴击
## 骰子损坏（耐久耗尽）
signal dice_broken(dice_data: DiceData)  # 信号声明：骰子耐久度归零时触发，携带损坏骰子的数据
## 骰子新增到背包
signal dice_added(dice_data: DiceData)  # 信号声明：新骰子加入玩家背包时触发，供 UI 刷新背包列表
## 骰子从背包移除
signal dice_removed(dice_data: DiceData)  # 信号声明：骰子从玩家背包移除时触发，供 UI 刷新背包列表


## ========== 玩家 ==========
## 玩家 HP 变化
signal player_hp_changed(new_hp: int, max_hp: int)  # 信号声明：玩家当前血量变化时触发，携带新血量和最大血量，供血条 UI 订阅
## 玩家死亡
signal player_died  # 信号声明：玩家血量归零时触发，无参数，供结算/重启逻辑订阅
## 玩家受到伤害（用于触发受击特效等）
signal player_take_damage(dmg: int)  # 信号声明：玩家受伤时触发，携带伤害值，供受击特效/屏幕震动等订阅


## ========== 游戏流程 ==========
## 游戏阶段切换
signal game_phase_changed(old_phase: StringName, new_phase: StringName)  # 信号声明：游戏阶段切换时触发，携带旧阶段和新阶段名称，供 UI/音效等响应
## 升级请求（三选一界面）
signal level_up_requested(choices: Array[SkillData])  # 信号声明：请求显示升级选择界面时触发，携带候选技能数组
## 进入休息站
signal rest_station_entered  # 信号声明：进入休息站时触发，供休息站 UI 订阅
## BOSS 生成
signal boss_spawned(boss_data: EnemyData)  # 信号声明：BOSS 敌人生成时触发，携带 BOSS 数据


## ========== 经济 ==========
## 金币变化
signal coins_changed(new_amount: int)  # 信号声明：玩家金币数量变化时触发，携带新金币数，供金币 UI 订阅


## ========== 遗物 ==========
## 遗物获得
signal relic_added(relic_data: RelicData)  # 信号声明：获得新遗物时触发，供遗物栏 UI 订阅
## 遗物移除
signal relic_removed(relic_data: RelicData)  # 信号声明：遗物被移除时触发，供遗物栏 UI 订阅


## ========== 效果 ==========
## 元素效果触发
signal element_triggered(element: StringName, target: Node2D, source: Node2D)  # 信号声明：元素效果触发时发射，携带元素类型、目标节点、来源节点
## 暴击触发（用于全局暴击特效）
signal crit_triggered(target: Node2D, damage: int)  # 信号声明：暴击触发时发射，携带目标节点和伤害值，供全局暴击特效系统订阅


## ========== 击杀计数（HUD 订阅）==========
signal kill_count_changed(new_count: int)  # 信号声明：击杀数变化时触发，携带新击杀数，供 HUD 击杀计数显示订阅


## ========== 村庄 / 城镇 ==========
## 进入村庄：携带村庄场景名（如 &"village_1", &"town_2", &"castle_3"）
signal village_entered(village_id: StringName)
## 离开村庄（向右走到头）
signal village_exited


## ========== 骰盅赌斗 ==========
## 骰盅赌斗开始：携带本局赌注
signal dice_cup_started(bet: int)
## 骰盅赌斗结束：携带结果字典 {"won": bool, "reward": Dictionary}
signal dice_cup_finished(result: Dictionary)


## ========== NPC 互动 ==========
## 任意 NPC 触发互动：携带 NPC 节点引用
signal npc_interaction_triggered(npc: Node)
