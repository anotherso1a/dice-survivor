# scripts/entities/ — 游戏实体脚本

## 目录职责

存放游戏中所有可交互实体的主控制脚本。每个实体脚本是该实体的"大脑"，负责协调组件、响应输入、管理状态机。实体脚本**不做具体计算**，而是委托给组件。

> **核心原则**：实体脚本是协调者，不是执行者。具体行为交给组件，跨实体通信交给 EventBus。

## 包含文件

| 文件 | 类名 | extends | 说明 |
|------|------|---------|------|
| `player.gd` | Player | CharacterBody2D | 玩家角色，处理输入和骰子投掷 |
| `enemy_base.gd` | EnemyBase | CharacterBody2D | 所有普通敌人基类，组件组合 |
| `boss_base.gd` | BossBase | EnemyBase | BOSS 专用，多阶段逻辑 |
| `projectile.gd` | Projectile | Area2D | 远程投射物（箭矢/火球等） |
| `pickup.gd` | Pickup | Area2D | 可拾取物（金币/经验/道具） |
| `dice_entity.gd` | DiceEntity | Node2D | 场景中的骰子（动画/投掷/面展示） |

## 实体与组件的关系

```
实体脚本 = 协调者
  ├── @onready 引用各组件
  ├── 连接组件信号到实体方法
  ├── 在 _physics_process 中调用组件 API
  └── 管理实体级状态机（idle/walk/hurt/dead）

组件 = 执行者
  ├── 封装单一行为的完整逻辑
  ├── 通过信号向上通知
  └── 不知道宿主是谁（通用）
```

## 示例：Player 实体脚本

```gdscript
class_name Player
extends CharacterBody2D

@onready var health: HealthComponent = $HealthComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    health.died.connect(_on_died)
    health.hp_changed.connect(_on_hp_changed)

func _physics_process(delta: float) -> void:
    movement.process_movement(delta)
    move_and_slide()
    _update_animation()

func _on_died() -> void:
    set_physics_process(false)
    sprite.play("death")
    EventBus.player_died.emit()

func _on_hp_changed(new_hp: int, max_hp: int) -> void:
    EventBus.player_hp_changed.emit(new_hp, max_hp)
```

## 依赖规则

```
entities 可以引用：core、components、utils
entities 不可直接引用：systems（通过 EventBus 通信）
entities 之间：不可互相引用（通过 EventBus 或信号通信）
```

## EnemyBase vs BossBase

| 特性 | EnemyBase | BossBase |
|------|-----------|----------|
| 基类 | CharacterBody2D | EnemyBase |
| 组件 | Health + Movement + ContactDamage + 状态组件 | 继承 EnemyBase 组件 + BossAI |
| 状态机 | idle → walk → hurt → death | idle → walk → attack → phase2 → death |
| 阶段 | 单阶段 | 多阶段（HP 阈值触发） |
| 死亡 | queue_free() | 特殊死亡演出 → 掉落奖励 |

## 新增实体流程

1. 确定实体类型（CharacterBody2D / Area2D / Node2D）
2. 创建 `.gd` 文件和对应 `.tscn` 场景
3. 在场景中挂载需要的组件节点
4. 在实体脚本中 `@onready` 引用组件并连接信号
5. 实现实体特有的状态机和输入处理
6. 通过 EventBus 与其他实体通信
