# Dice Survivor — 项目记忆

## 项目概况
- 类型：骰子幸存者（土豆兄弟 + Balatro + 杀戮尖塔融合）
- 引擎：Godot 4.6+ / GDScript 2.0
- 平台：Steam（PC/Mac/Linux）
- 美术：像素风 32×32，PICO-8 风格 32 色板
- 视口：1280×720

## 架构决策
- 数据驱动：`.tres` Resource 为主，JSON 导出用于 Mod 支持
- 组合优于继承：组件节点（HealthComponent / MovementComponent 等）
- 信号解耦：EventBus 跨场景，节点信号场景内
- 小游戏：MinigameBase 基类，独立场景
- 详见 `ARCHITECTURE.md`

## 当前 MVP 进度
- M1 已完成：基本战斗循环、骰子切换、精灵装配、受伤/死亡动画、随机出生
- M2~M9 待做：第二骰子、三选一升级、百家乐、卖血、BOSS、美术、音效、平衡
- 村庄系统脚本骨架已完成（2026-06-22）：VillagePlayer/NPC/Scene + 骰盅赌斗 DiceCupDuel 脚本
  - GameManager.Phase 新增 VILLAGE；EventBus 新增 village/dice_cup 系列信号
  - 编辑器待做：InputMap 注册、AnimationPlayer 骰盅动画制作、碰撞形状、精灵动画

## 碰撞层约定
- Layer 1: Player body
- Layer 2: Enemy body
- Layer 3+: 预留给环境/墙壁
- 敌人碰撞层=2, 碰撞掩码=0（穿过玩家，不物理碰撞）
- 玩家碰撞层=1, 碰撞掩码=0（不被敌人推动）
- 敌人 Hitbox Area2D 碰撞掩码=1（检测 layer 1 的玩家做接触伤害）
- 接触伤害有冷却（默认 0.5s），避免每帧扣血

## 关键文件
- `GAME_DESIGN.md` — 完整游戏设计文档
- `ARCHITECTURE.md` — 项目架构规划文档
- `docs/dice_development_guide.md` — **骰子开发指南（新增骰子时必须阅读）**

## ⚠️ Agent 开发规则
- **新增骰子时**：必须先读取 `docs/dice_development_guide.md`，按照指南中的流程创建 AttackEffect 和 DiceData
- **修改攻击系统时**：必须先读取 `ARCHITECTURE.md` 第十一章（攻击效果系统架构）

## 用户背景
- 前端工程师，Godot 新手
- 需要解释 shader/着色器等图形术语

## ⚠️ GDScript 防坑规范（每次开发前必读）
> 详见 `docs/gdscript_pitfalls.md`，以下是高频错误速查：

### 规则 1：变量必须先声明后使用
```gdscript
# ❌ 错误
if debug: print("test")  # `debug` 未声明

# ✅ 正确
@export var debug: bool = false
if debug: print("test")
```

### 规则 2：重写父类方法，签名必须完全一致
```gdscript
# 父类：_find_nearest_enemy(source: Node2D, max_range: float = -1)
# ❌ 错误（少了默认参数）
func _find_nearest_enemy(source: Node2D) -> Node2D:

# ✅ 正确（完全复制父类签名）
func _find_nearest_enemy(source: Node2D, max_range: float = -1) -> Node2D:
```

### 规则 3：`var` 声明的是属性，`func` 声明的是方法
```gdscript
# RunState.relics 是属性（var relics: Array[RelicData] = []）
var r = RunState.relics  # ✅ 直接访问

# 如果是 func get_relics() -> Array[RelicData]: 才是方法
var r = RunState.get_relics()  # 仅当定义了此方法时才可用
```

### 规则 4：调用方法前先检查签名，不要传多余参数
```gdscript
# HealthComponent.take_damage(dmg: int, is_crit: bool) 只有 2 个参数
# ❌ 错误
_health.take_damage(dmg, false, null)  # 传了 3 个

# ✅ 正确
_health.take_damage(dmg, false)
```

### 规则 5：新增 `class_name` 后必须重新打开脚本让 Godot 解析
- 报错 `Identifier "Xxx" not declared` 时，双击打开 `xxx.gd` 让编辑器重新解析
- 或用动态加载 `load("res://...")` 代替 `class_name` 引用

### 规则 6：`@onready` 变量只能在 `_ready()` 之后使用
```gdscript
@onready var _hp_bar: ProgressBar = $HpBar
func _init() -> void:
    _hp_bar.value = 100  # ❌ _hp_bar 还是 null
func _ready() -> void:
    _hp_bar.value = 100  # ✅ 正确
```
