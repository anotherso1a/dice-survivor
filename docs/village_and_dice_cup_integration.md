# 村庄系统 + 骰盅赌斗 — 集成指南

> 本文档说明如何将村庄场景与骰盅赌斗小游戏集成到现有幸存者游戏中。

---

## 一、新增文件一览

| 文件 | 说明 |
|------|------|
| `scripts/minigames/minigame_base.gd` | 小游戏基类（之前 ARCHITECTURE.md 中规划的） |
| `scripts/minigames/dice_cup_duel.gd` | 骰盅赌斗核心逻辑：状态机 + 骰子结算 |
| `scripts/ui/dice_cup_ui.gd` | 骰盅 UI 控制器：动画驱动 + 结果弹窗 |
| `scripts/world/village_player.gd` | 村庄专用玩家：左右移动 + NPC 交互 |
| `scripts/world/village_npc.gd` | 村庄 NPC 基类：交互范围检测 + 信号 |
| `scripts/world/village_scene.gd` | 村庄场景控制器：小游戏调度 + 关卡切换 |
| `scenes/world/village.tscn` | 村庄场景骨架（需在编辑器中完善美术/碰撞） |
| `scenes/minigames/dice_cup_duel.tscn` | 骰盅小游戏场景骨架 |

### 修改的文件

| 文件 | 修改内容 |
|------|---------|
| `scripts/systems/event_bus.gd` | 新增 `village_entered / village_exited / dice_cup_started / dice_cup_finished / npc_interaction_triggered` |
| `scripts/systems/game_manager.gd` | Phase 枚举新增 `VILLAGE`；新增 `_enter_village()` + `set_village_scene()` |

---

## 二、InputMap 必须注册的动作

在 **Godot 编辑器 → Project → Project Settings → Input Map** 中注册：

| 动作名 | 说明 | 推荐按键 |
|--------|------|---------|
| `move_left` | 村庄左移 | A / Left Arrow / 手柄左摇杆 |
| `move_right` | 村庄右移 | D / Right Arrow / 手柄左摇杆 |
| `interact` | NPC 互动 | F / Y 键（手柄北键） |
| `ui_accept` | 骰盅摇晃（长按） | Space / A 键（手柄南键） |
| `dice_cup_reveal` | 骰盅揭牌 | X / X 键（手柄西键） |
| `ui_cancel` | 退出小游戏 | ESC / B 键（手柄东键） |

> `ui_accept` 和 `ui_cancel` 是 Godot 内置动作，通常已存在，确认映射正确即可。

---

## 三、流程触发方式

### 幸存者战斗结束后进入村庄

```gdscript
## 在 Main.gd 或 GameManager 的波次清算逻辑中：
GameManager.set_village_scene("res://scenes/world/village.tscn")
GameManager.transition_to(GameManager.Phase.VILLAGE)
```

不同大关卡可以切换不同村庄场景（村庄→城镇→城市→城堡）：
```gdscript
## 关卡 1 后：村庄
GameManager.set_village_scene("res://scenes/world/village.tscn")
## 关卡 2 后：城镇
GameManager.set_village_scene("res://scenes/world/town.tscn")
```

### 村庄内骰盅赌斗

玩家走近"赌徒 NPC"→ 按 F → 自动启动骰盅赌斗小游戏，无需手动调用。

---

## 四、骰盅赌斗状态机

```
IDLE
  ↓ 长按 A / 左键（≥ 0.5s）
SHAKING（摇晃动画循环）
  ↓ 松开
SETTLING（落地动画，0.4s）
  ↓ 落地完成
WAIT_REVEAL（显示"按 X 揭牌"提示）
  ↓ 可以重新长按再摇（回到 SHAKING）
  ↓ 按 X / 右键
REVEALING（演绎动画，禁止输入）
  T=0.8s → 发 player_cup_revealed(value)
  T=1.6s → 发 npc_cup_revealed(value)
  T=2.4s → 发 duel_result_ready → 弹出结果弹窗
DONE
  → 发 minigame_finished({won, reward})
```

---

## 五、骰子点数结算规则

- 玩家骰子：遍历 `RunState.dice_pool`，每颗骰子调用 `roll_gamble()`，取 `face.gamble_value` 的最大值
- NPC：`randi_range(1, 6)` 随机
- 比较：玩家点数 > NPC 点数 → 玩家胜
- 奖励：胜 → `+bet + 30` 金币；败 → `-bet` 金币 + `-5` HP

> ⚠️ 确保骰子的 `gamble_faces` 数组不为空，且每个 `FaceData.gamble_value` 已正确填写。

---

## 六、待完成（编辑器内操作）

1. **村庄美术**
   - 完善 `village.tscn` 的 TileMapLayer 背景（木板地板、建筑外墙、路灯）
   - 为 `GamblerNPC` 添加像素精灵帧动画（`idle`、`talk`）
   - 为 `VillagePlayer` 添加像素精灵帧动画（`idle`、`walk`）

2. **骰盅动画**
   - 在 `dice_cup_duel.tscn` 的 `AnimationPlayer` 中制作：
     - `cup_shake`：骰盅左右摇晃（循环）
     - `cup_settle`：落地"啪"动画（一次性）
     - `reveal_intro`：相机拉近 + 桌面聚焦
     - `player_cup_open`：玩家骰盅掀盖动画
     - `npc_cup_open`：NPC 骰盅掀盖动画
     - `popup_in` / `popup_out`：结果弹窗出入场

3. **音效**
   - 骰盅摇晃音（沙沙声）
   - 骰盅落地音（啪声）
   - 掀盖音
   - 胜利/失败音效

4. **碰撞形状**
   - VillagePlayer 的 `CollisionShape2D`：约 16×32 像素胶囊
   - GamblerNPC 的 `InteractArea/CollisionShape2D`：约 80×80 像素方形感应区

5. **更多 NPC**
   - 复制 `GamblerNPC` 节点，修改 `npc_type` 为 `MERCHANT / BLACKSMITH / HEALER`
   - 在 `village_scene.gd` 的 `_open_merchant_ui` 等预留函数中实现对应 UI

---

## 七、Village 关卡体系（建议）

| 关卡段 | 村庄类型 | 场景文件 | 特色 NPC |
|--------|---------|---------|---------|
| 第 1 大关后 | 破旧村庄 | `village.tscn` | 赌徒、药草商、铁匠学徒 |
| 第 2 大关后 | 城镇 | `town.tscn` | 高级赌场、武器商、炼金师 |
| 第 3 大关后 | 城市 | `city.tscn` | 豪赌房、遗物拍卖、骰子工匠 |
| 第 4 大关后 | 城堡 | `castle.tscn` | 国王赌局、秘密锻造炉、传说遗物商 |
