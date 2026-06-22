# 村庄系统 + 骰盅赌斗 — 交付总结

## 本次实现内容

### 新增脚本（6 个）
- `scripts/minigames/minigame_base.gd` — 小游戏基类，统一 start/force_end/_end_minigame 接口
- `scripts/minigames/dice_cup_duel.gd` — 骰盅赌斗核心：5 状态机、长按/松手/揭牌输入、动画时序串联、骰子结算
- `scripts/ui/dice_cup_ui.gd` — UI 控制层：监听逻辑信号 → 驱动 AnimationPlayer → 结果弹窗
- `scripts/world/village_player.gd` — 村庄专用玩家：左右移动、NPC 靠近检测、交互键
- `scripts/world/village_npc.gd` — NPC 基类：交互区域、5 种 NPC 类型枚举
- `scripts/world/village_scene.gd` — 村庄总控：小游戏调度、奖励应用、离开触发

### 新增场景（2 个骨架）
- `scenes/world/village.tscn` — 村庄骨架
- `scenes/minigames/dice_cup_duel.tscn` — 骰盅小游戏骨架（含结果弹窗布局）

### 修改文件（2 个）
- `scripts/systems/event_bus.gd` — 新增 village_entered/exited、dice_cup_started/finished、npc_interaction_triggered
- `scripts/systems/game_manager.gd` — Phase 枚举加 VILLAGE、新增 _enter_village() + set_village_scene()

### 文档
- `docs/village_and_dice_cup_integration.md` — 完整集成指南、InputMap 配置、动画清单

## 下一步（编辑器操作）
1. 注册 InputMap 动作：`interact`、`dice_cup_reveal`
2. 制作骰盅动画（AnimationPlayer）：cup_shake、cup_settle、player_cup_open、npc_cup_open、popup_in/out
3. 给 NPC 和玩家添加碰撞形状
4. 补充像素精灵帧动画
