# scripts/components/ — 可复用行为组件

## 目录职责

存放所有可复用的行为组件脚本。每个组件是一个独立的 Node，负责**单一职责**的行为，通过组合方式挂载到实体场景上。组件之间通过信号通信，不互相引用。

> **核心原则**：组合优于继承。不要写 `CharacterWithHealth`，写 `HealthComponent` 然后挂上去。

## 包含文件

| 文件 | 类名 | 职责 | 信号 |
|------|------|------|------|
| `health_component.gd` | HealthComponent | HP/受伤/死亡/治疗 | `hp_changed`, `died`, `damaged` |
| `movement_component.gd` | MovementComponent | 移动（追玩家/巡逻/远程走位） | `direction_changed` |
| `contact_damage.gd` | ContactDamage | 接触伤害（碰到目标造成伤害） | `hit_target` |
| `burn_component.gd` | BurnComponent | 燃烧 DOT（持续伤害 + 视觉提示） | `burn_tick`, `burn_expired` |
| `freeze_component.gd` | FreezeComponent | 冻结（减速/定身 + 视觉提示） | `frozen`, `unfrozen` |
| `poison_component.gd` | PoisonComponent | 中毒（递减 DOT） | `poison_tick`, `poison_expired` |
| `shock_component.gd` | ShockComponent | 雷击弹射（伤害在敌人间跳转） | `shock_bounced` |
| `drop_component.gd` | DropComponent | 掉落物生成（金币/经验/道具） | `item_dropped` |
| `spawner_component.gd` | SpawnerComponent | 刷怪逻辑（定时/按波次） | `enemy_spawned` |

## 设计规则

### 组件特征

1. **extends Node**（不是 CharacterBody2D 或 Area2D）
2. 通过 `@export` 暴露配置参数
3. 通过**信号**向上通知宿主，绝不调用 `get_parent()` 的方法
4. 不持有其他组件的引用（组件间通过宿主脚本协调）
5. 可以在编辑器中独立配置，不需要写代码就能调整参数

### 组件模板

```gdscript
class_name HealthComponent
extends Node

## 信号：通知宿主和外部系统
signal hp_changed(new_hp: int, max_hp: int)
signal died
signal damaged(dmg: int, is_crit: bool)

## 配置：在 Inspector 中可编辑
@export var max_hp: int = 10

## 运行时状态
var current_hp: int = 0

func _ready() -> void:
    current_hp = max_hp

## 公共 API：供宿主和外部调用
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

## 挂载方式

### 在场景中添加组件

```
Player.tscn
├── HealthComponent      ← 挂载组件
├── MovementComponent    ← 挂载组件
├── ContactDamage        ← 挂载组件
├── AnimatedSprite2D
├── CollisionShape2D
└── DiceSlot
```

### 在宿主脚本中引用组件

```gdscript
# entities/player.gd
class_name Player
extends CharacterBody2D

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent

func _ready() -> void:
    health.died.connect(_on_died)
    health.hp_changed.connect(_on_hp_changed)

func _on_died() -> void:
    set_physics_process(false)
    EventBus.player_died.emit()
```

## 依赖规则

```
components 可以引用：core、utils
components 不可引用：systems、entities、effects、ui、minigames
components 之间：不可互相引用（通过宿主脚本或 EventBus 协调）
```

## 新增组件流程

1. 确定职责是**单一**的（一个组件只管一件事）
2. 创建 `.gd` 文件，`extends Node`
3. 定义 `@export` 配置参数
4. 定义信号（向上通知机制）
5. 实现公共 API 方法
6. 在目标场景中添加为子节点
7. 在宿主脚本中通过 `@onready` 引用并连接信号
