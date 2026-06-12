# 🏗️ Dice Survivor — 项目架构规划

> 版本 v1.0 · 2026-06-12 · 基于 GAME_DESIGN.md 全量系统推导

---

## 一、设计原则

| 原则 | 说明 |
|------|------|
| **数据驱动** | 骰子/技能/遗物/敌人全部用 `.tres` Resource 定义，策划在编辑器拖拽编辑 |
| **组合优于继承** | 行为用 Component 节点组合，不用深层继承树 |
| **信号解耦** | 跨场景通信走 EventBus，场景内通信走节点信号，绝不跨层直接引用 |
| **场景自治** | 每个场景可 F6 独立运行，不依赖父节点上下文 |
| **静态类型** | GDScript 2.0 全量类型标注，零 untyped var |

---

## 二、目录结构

```
res://
├── assets/                          # 美术资源（不改动）
│   ├── sprites/                     # 精灵图
│   ├── audio/                       # 音效 / BGM
│   ├── fonts/                       # 像素字体
│   └── ui/                          # UI 素材
│
├── data/                            # .tres Resource 数据文件
│   ├── dice/                         #   骰子数据
│   │   ├── standard_d6.tres
│   │   ├── leaded_d6.tres
│   │   ├── glass_d6.tres
│   │   ├── fire_d6.tres
│   │   └── ...
│   ├── skills/                      #   技能数据
│   │   ├── one_lock.tres
│   │   ├── one_enhance.tres
│   │   └── ...
│   ├── relics/                      #   遗物数据
│   │   ├── lucky_coin.tres
│   │   ├── dual_face.tres
│   │   └── ...
│   ├── enemies/                     #   敌人数据
│   │   ├── skeleton_basic.tres
│   │   ├── skeleton_tank.tres
│   │   └── ...
│   ├── waves/                       #   波次配置
│   │   ├── wave_01.tres
│   │   └── ...
│   └── recipes/                     #   合成配方
│       ├── fire_thunder_fusion.tres
│       └── ...
│
├── scripts/                         # 所有 GDScript
│   ├── core/                        #   核心数据类（纯 Resource/RefCounted）
│   │   ├── dice_data.gd             #     DiceData (Resource)
│   │   ├── face_data.gd             #     FaceData (Resource) — 单个骰面
│   │   ├── skill_data.gd            #     SkillData (Resource)
│   │   ├── relic_data.gd            #     RelicData (Resource)
│   │   ├── enemy_data.gd            #     EnemyData (Resource)
│   │   ├── wave_data.gd             #     WaveData (Resource)
│   │   └── recipe_data.gd           #     RecipeData (Resource)
│   │
│   ├── systems/                     #   Autoload 系统单例
│   │   ├── event_bus.gd             #     全局信号总线
│   │   ├── game_manager.gd          #     游戏流程状态机（战斗→休息→BOSS）
│   │   ├── dice_manager.gd          #     骰子池管理、骰面修改、合成
│   │   ├── save_manager.gd          #     存档 / 读档
│   │   └── run_state.gd             #     当局运行时状态（金币/HP/骰子背包/遗物列表）
│   │
│   ├── components/                  #   可复用组件（组合挂载用）
│   │   ├── health_component.gd      #     HP / 受伤 / 死亡信号
│   │   ├── movement_component.gd    #   移动（追玩家 / 巡逻 / 远程走位）
│   │   ├── contact_damage.gd        #   接触伤害
│   │   ├── burn_component.gd        #   燃烧 DOT
│   │   ├── freeze_component.gd      #   冻结
│   │   ├── poison_component.gd      #   中毒
│   │   ├── shock_component.gd       #   雷击弹射
│   │   ├── drop_component.gd        #   掉落物（金币 / 经验 / 道具）
│   │   └── spawner_component.gd     #   刷怪逻辑
│   │
│   ├── entities/                    #   游戏实体脚本
│   │   ├── player.gd                #     Player (CharacterBody2D)
│   │   ├── enemy_base.gd            #     EnemyBase (CharacterBody2D) — 所有敌人基类
│   │   ├── boss_base.gd             #     BossBase extends EnemyBase — BOSS 专用
│   │   ├── projectile.gd            #     Projectile (Area2D) — 远程投射物
│   │   ├── pickup.gd                #     Pickup (Area2D) — 可拾取物
│   │   └── dice_entity.gd           #     DiceEntity (Node2D) — 场景中的骰子
│   │
│   ├── minigames/                   #   休息站小游戏（独立场景 + 脚本）
│   │   ├── minigame_base.gd         #     基类：统一的 start()/end()/get_result() 接口
│   │   ├── baccarat.gd              #     比大小（百家乐简化）
│   │   ├── liars_dice.gd            #     吹牛
│   │   ├── gold_flower.gd           #     炸金花
│   │   └── blackjack.gd            #     21点
│   │
│   ├── effects/                     #   视觉特效
│   │   ├── damage_number.gd         #     飘字
│   │   ├── spawn_warning.gd         #     出生警告
│   │   └── element_vfx.gd           #     元素特效（火焰/冰霜/雷电）
│   │
│   ├── ui/                          #   UI 脚本
│   │   ├── hud.gd                   #     战斗 HUD
│   │   ├── level_up_ui.gd           #     三选一升级界面
│   │   ├── rest_station_ui.gd        #     休息站主界面
│   │   ├── dice_inventory_ui.gd     #     骰子背包
│   │   ├── crafting_ui.gd           #     合成台
│   │   └── game_over_ui.gd          #     结算 / 死亡
│   │
│   └── utils/                       #   工具类
│       ├── constants.gd             #     全局常量
│       ├── math_utils.gd            #     数学工具
│       └── json_loader.gd           #     JSON 导入导出（Mod 支持）
│
├── scenes/                          # 所有 .tscn 场景文件
│   ├── main.tscn                    #   游戏主场景（仅挂 GameManager）
│   ├── arena.tscn                   #   战斗场景
│   ├── rest_station.tscn            #   休息站场景
│   ├── entities/                    #   实体场景
│   │   ├── player.tscn
│   │   ├── enemies/
│   │   │   ├── skeleton_basic.tscn
│   │   │   ├── skeleton_tank.tscn
│   │   │   ├── skeleton_ranged.tscn
│   │   │   ├── boss_anti_one.tscn
│   │   │   └── ...
│   │   ├── dice.tscn
│   │   ├── projectile.tscn
│   │   └── pickup.tscn
│   ├── minigames/                   #   小游戏场景
│   │   ├── baccarat.tscn
│   │   ├── liars_dice.tscn
│   │   ├── gold_flower.tscn
│   │   └── blackjack.tscn
│   ├── ui/                          #   UI 场景
│   │   ├── hud.tscn
│   │   ├── level_up_ui.tscn
│   │   ├── rest_station_ui.tscn
│   │   ├── dice_inventory_ui.tscn
│   │   ├── crafting_ui.tscn
│   │   └── game_over_ui.tscn
│   └── effects/                     #   特效场景
│       ├── damage_number.tscn
│       └── spawn_warning.tscn
│
└── project.godot
```

---

## 三、Autoload 规划

| Autoload | 脚本路径 | 职责 | 生命周期 |
|----------|---------|------|---------|
| **EventBus** | `scripts/systems/event_bus.gd` | 全局信号总线，跨场景解耦通信 | 进程级 |
| **GameManager** | `scripts/systems/game_manager.gd` | 游戏流程状态机：菜单→战斗→休息→BOSS→结算 | 进程级 |
| **RunState** | `scripts/systems/run_state.gd` | 当局运行时状态：金币、HP、骰子背包、遗物列表、当前关卡 | 当局级（重开清零） |
| **DiceManager** | `scripts/systems/dice_manager.gd` | 骰子池 CRUD、骰面修改、合成配方、骰子实例化 | 当局级 |
| **SaveManager** | `scripts/systems/save_manager.gd` | 存档 / 读档 / 设置持久化 | 进程级 |

### EventBus 信号清单（随开发逐步扩充）

```gdscript
# scripts/systems/event_bus.gd
extends Node

# 战斗
signal enemy_died(pos: Vector2, enemy_data: EnemyData)
signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)

# 骰子
signal dice_rolled(dice_entity: Node2D, face: FaceData, is_crit: bool)
signal dice_broken(dice_data: DiceData)
signal dice_added(dice_data: DiceData)
signal dice_removed(dice_data: DiceData)

# 玩家
signal player_hp_changed(new_hp: int, max_hp: int)
signal player_died
signal player_take_damage(dmg: int)

# 游戏流程
signal game_phase_changed(old_phase: StringName, new_phase: StringName)
signal level_up_requested(choices: Array[SkillData])
signal rest_station_entered
signal boss_spawned(boss_data: EnemyData)

# 经济
signal coins_changed(new_amount: int)

# 遗物
signal relic_added(relic_data: RelicData)
signal relic_removed(relic_data: RelicData)

# 效果
signal element_triggered(element: StringName, target: Node2D, source: Node2D)
signal crit_triggered(target: Node2D, damage: int)
```

---

## 四、核心数据类设计

### 4.1 FaceData（骰面 — 最小数据单元）

```gdscript
# scripts/core/face_data.gd
class_name FaceData
extends Resource

enum FaceType { NORMAL, ENHANCED, ELEMENTAL, CURSED }

@export var face_type: FaceType = FaceType.NORMAL
@export var value: int = 1
@export var damage: int = 1
@export var multiplier: float = 1.0
@export var is_crit: bool = false
@export var element: StringName = &""
@export var element_power: int = 0          # 元素效果强度（燃烧层数/冻结秒数/弹射目标数）
@export var self_damage: int = 0            # 诅咒面自伤
@export var gamble_value: int = 0           # 赌博模式点数
@export var description: String = ""

## 运行时计算最终伤害（含暴击 + 遗物加成）
func get_final_damage(multiplier_bonus: float = 0.0) -> int:
    var final_mult: float = multiplier + multiplier_bonus
    return int(damage * final_mult)
```

### 4.2 DiceData（骰子）

```gdscript
# scripts/core/dice_data.gd
class_name DiceData
extends Resource

enum DiceMode { COMBAT, GAMBLE }

@export var dice_id: StringName = &""
@export var dice_name: String = ""
@export var sides: int = 6
@export var cooldown: float = 1.0
@export var element: StringName = &""
@export var durability: int = -1             # -1 = 无限
@export var max_durability: int = -1
@export var combat_faces: Array[FaceData] = []
@export var gamble_faces: Array[FaceData] = []
@export var icon: Texture2D

var current_durability: int = -1
var current_mode: DiceMode = DiceMode.COMBAT

func _init() -> void:
    current_durability = durability

func roll_combat() -> FaceData:
    if combat_faces.is_empty():
        return null
    var face: FaceData = combat_faces.pick_random()
    _consume_durability()
    return face

func roll_gamble() -> FaceData:
    if gamble_faces.is_empty():
        return null
    _consume_durability()
    return gamble_faces.pick_random()

func set_mode(mode: DiceMode) -> void:
    current_mode = mode

func is_broken() -> bool:
    return durability > 0 and current_durability <= 0

func _consume_durability() -> void:
    if durability > 0:
        current_durability -= 1
```

### 4.3 SkillData（技能）

```gdscript
# scripts/core/skill_data.gd
class_name SkillData
extends Resource

enum SkillTarget { DICE_FACE, DICE_WHOLE, PLAYER, ALL_DICE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var skill_id: StringName = &""
@export var skill_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var target: SkillTarget = SkillTarget.DICE_FACE
@export var icon: Texture2D

# 效果参数（每个技能按需解读）
@export var params: Dictionary = {}
```

### 4.4 RelicData（遗物）

```gdscript
# scripts/core/relic_data.gd
class_name RelicData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var relic_id: StringName = &""
@export var relic_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export var applies_to: StringName = &""       # "combat" / "gamble" / "both"
@export var effect_script: GDScript             # 遗物效果逻辑脚本
@export var params: Dictionary = {}
```

### 4.5 EnemyData（敌人配置）

```gdscript
# scripts/core/enemy_data.gd
class_name EnemyData
extends Resource

enum EnemyType { BASIC, RANGED, TANK, SUICIDE, ELITE, BOSS }

@export var enemy_id: StringName = &""
@export var display_name: String = ""
@export var enemy_type: EnemyType = EnemyType.BASIC
@export var max_hp: int = 6
@export var move_speed: float = 80.0
@export var contact_damage: int = 3
@export var resist_element: StringName = &""   # 抗性元素
@export var resist_percent: float = 0.0        # 抗性百分比
@export var scene: PackedScene                  # 对应的 .tscn
@export var drop_table: Dictionary = {}        # 掉落表
```

---

## 五、组件系统设计

### 5.1 HealthComponent（可复用血量组件）

```gdscript
# scripts/components/health_component.gd
class_name HealthComponent
extends Node

signal hp_changed(new_hp: int, max_hp: int)
signal died
signal damaged(dmg: int, is_crit: bool)

@export var max_hp: int = 10

var current_hp: int = 0

func _ready() -> void:
    current_hp = max_hp

func take_damage(dmg: int, is_crit: bool = false) -> void:
    current_hp = max(0, current_hp - dmg)
    hp_changed.emit(current_hp, max_hp)
    damaged.emit(dmg, is_crit)
    if current_hp <= 0:
        died.emit()

func heal(amount: int) -> void:
    current_hp = min(max_hp, current_hp + amount)
    hp_changed.emit(current_hp, max_hp)
```

**使用方式**：在 Player.tscn / Enemy.tscn 中作为子节点挂载，通过信号连接通知宿主。

### 5.2 组件挂载模式

```
Player.tscn
├── HealthComponent      → hp_changed / died
├── MovementComponent    → 处理 WASD 输入
├── ContactDamage        → 碰到敌人受伤
├── AnimatedSprite2D
├── CollisionShape2D
└── DiceSlot             → 骰子挂载点

Enemy.tscn (skeleton_basic)
├── HealthComponent      → hp_changed / died
├── MovementComponent    → 追玩家
├── ContactDamage        → 碰到玩家受伤
├── BurnComponent        → 燃烧 DOT
├── AnimatedSprite2D
├── CollisionShape2D
└── Hitbox (Area2D)
```

---

## 六、小游戏架构

### 6.1 基类接口

```gdscript
# scripts/minigames/minigame_base.gd
class_name MinigameBase
extends Control

signal minigame_finished(result: Dictionary)

@export var minigame_name: String = ""
@export var difficulty: int = 0           # 0=简单 1=普通 2=地狱

var _is_running: bool = false

func start(player_dice: Array[DiceData], bet: int) -> void:
    _is_running = true
    # 子类实现具体开始逻辑

func force_end() -> void:
    _is_running = false
    minigame_finished.emit({"won": false, "reward": {}})

## 子类在游戏结束时必须调用
func _end_minigame(won: bool, reward: Dictionary) -> void:
    _is_running = false
    minigame_finished.emit({"won": won, "reward": reward})
```

### 6.2 休息站如何加载小游戏

```gdscript
# 休息站场景动态加载
func _start_minigame(scene_path: String) -> void:
    var minigame_scene: PackedScene = load(scene_path)
    var minigame: MinigameBase = minigame_scene.instantiate()
    add_child(minigame)
    minigame.minigame_finished.connect(_on_minigame_finished)
    minigame.start(RunState.dice_pool, RunState.coins)

func _on_minigame_finished(result: Dictionary) -> void:
    if result.won:
        # 发放奖励
        pass
    else:
        # 扣血 / 扣钱
        pass
```

---

## 七、游戏流程状态机

```gdscript
# scripts/systems/game_manager.gd
class_name GameManager
extends Node

enum Phase {
    MENU,           # 主菜单
    BATTLE,         # 战斗中
    WAVE_CLEAR,     # 波次清空 → 弹三选一
    LEVEL_UP,       # 三选一升级中
    REST_STATION,   # 休息站
    BOSS,           # BOSS 战
    GAME_OVER,      # 死亡 / 通关
}

var current_phase: Phase = Phase.MENU
var current_wave: int = 0
var max_waves: int = 30

func transition_to(new_phase: Phase) -> void:
    var old: Phase = current_phase
    current_phase = new_phase
    EventBus.game_phase_changed.emit(
        Phase.keys()[old] as StringName,
        Phase.keys()[new_phase] as StringName
    )
    match new_phase:
        Phase.BATTLE:
            _start_wave()
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
```

---

## 八、现有代码迁移映射

| 当前文件 | 迁移目标 | 说明 |
|---------|---------|------|
| `scripts/Data/DiceData.gd` | `scripts/core/dice_data.gd` | 拆出 FaceData，改 combat_faces 为 `Array[FaceData]` |
| `scripts/Data/DiceDatabase.gd` | `data/dice/*.tres` | 从代码构造 → .tres Resource 文件，编辑器直接编辑 |
| `scripts/Dice.gd` | `scripts/entities/dice_entity.gd` | 场景节点逻辑，数据职责还给 DiceData |
| `scripts/Player.gd` | `scripts/entities/player.gd` + `scripts/components/*.gd` | 拆出 HealthComponent、MovementComponent |
| `scripts/Enemy.gd` | `scripts/entities/enemy_base.gd` + `scripts/components/*.gd` | 拆出 HealthComponent、BurnComponent |
| `scripts/Main.gd` | `scripts/systems/game_manager.gd` + `scripts/systems/run_state.gd` | 刷怪/流程→GameManager，金币/背包→RunState |
| `scripts/HUD.gd` | `scripts/ui/hud.gd` | 订阅 EventBus 更新 UI |

---

## 九、开发规范

### 9.1 命名规范

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件名 | snake_case | `dice_data.gd`, `enemy_base.gd` |
| class_name | PascalCase | `DiceData`, `EnemyBase` |
| 变量 | snake_case | `current_hp`, `move_speed` |
| 常量 | SCREAMING_SNAKE | `MAX_DICE_SLOTS`, `SPAWN_MARGIN` |
| 信号 | snake_case | `hp_changed`, `enemy_died` |
| 枚举 | PascalCase 枚举名 + SCREAMING 成员 | `Phase.MENU`, `Rarity.RARE` |
| .tres 文件 | 与 dice_id 对应 | `standard_d6.tres` |
| 场景文件 | snake_case | `skeleton_basic.tscn` |

### 9.2 信号使用规则

- **场景内通信**：用节点信号（`health.died.connect(...)`）
- **跨场景通信**：用 EventBus（`EventBus.enemy_died.emit(...)`）
- **绝不允许**：子节点 `get_parent()` 调用父方法
- **绝不允许**：UI 直接引用游戏实体节点

### 9.3 新增内容流程

```
新增一种骰子:
  1. 创建 data/dice/xxx_d6.tres（编辑器填数据）
  2. 在 DiceManager 或 JSON 配置中注册
  3. 完成，无需改代码

新增一种敌人:
  1. 创建 data/enemies/xxx.tres
  2. 创建 scenes/entities/enemies/xxx.tscn（挂载组件）
  3. 在 wave 配置中引用

新增一种小游戏:
  1. 创建 scripts/minigames/xxx.gd（extends MinigameBase）
  2. 创建 scenes/minigames/xxx.tscn
  3. 在休息站注册

新增一种遗物:
  1. 创建 data/relics/xxx.tres
  2. 创建 scripts/relics/xxx_effect.gd（效果逻辑）
  3. 在 relic_data.effect_script 中引用
```

---

## 十、MVP 迁移优先级

### Phase 1：骨架搭建（当前 → M2 之前）

1. 创建新目录结构
2. 迁移 DiceData → 拆出 FaceData
3. 创建 EventBus / RunState / GameManager 骨架
4. 创建 HealthComponent、MovementComponent
5. 重构 Player.gd / Enemy.gd 使用组件
6. 重构 Main.gd → 刷怪逻辑移入 GameManager

### Phase 2：数据驱动化（M2 同步）

1. DiceDatabase 代码构造 → .tres 文件
2. EnemyData .tres + EnemyBase 基类
3. WaveData .tres 波次配置

### Phase 3：小游戏框架（M4 同步）

1. MinigameBase 基类
2. RestStation 场景
3. 第一个小游戏：百家乐
