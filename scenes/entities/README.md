# scenes/entities/ — 游戏实体场景

## 目录职责

存放所有游戏实体的 `.tscn` 场景文件。每个实体场景定义了该实体的节点树结构：挂载了哪些组件、碰撞体、精灵、动画等。

## 子目录

| 子目录 | 内容 |
|--------|------|
| `enemies/` | 各种敌人场景（骷髅兵/盾兵/弓手/BOSS 等） |

## 根目录文件

| 文件 | 根节点类型 | 说明 |
|------|-----------|------|
| `player.tscn` | CharacterBody2D | 玩家角色场景 |
| `dice.tscn` | Node2D | 场景中的骰子 |
| `projectile.tscn` | Area2D | 远程投射物 |
| `pickup.tscn` | Area2D | 可拾取物 |

## 典型实体场景节点树

### Player

```
Player (CharacterBody2D) ← player.gd
├── HealthComponent (Node) ← health_component.gd
├── MovementComponent (Node) ← movement_component.gd
├── ContactDamage (Node) ← contact_damage.gd
├── AnimatedSprite2D
├── CollisionShape2D
├── DiceSlot (Node2D)
├── Label
└── HpLabel
```

### Enemy (skeleton_basic)

```
EnemyBase (CharacterBody2D) ← enemy_base.gd
├── HealthComponent (Node) ← health_component.gd
├── MovementComponent (Node) ← movement_component.gd
├── ContactDamage (Node) ← contact_damage.gd
├── BurnComponent (Node) ← burn_component.gd
├── AnimatedSprite2D
├── CollisionShape2D
├── Hitbox (Area2D)
├── HpBar (ProgressBar)
└── CollisionShape2D (Hitbox)
```

## 开发方式

### 新增敌人场景

1. 在 `enemies/` 下新建场景
2. 根节点设为 `CharacterBody2D`，挂载 `enemy_base.gd`
3. 添加所需的组件节点（Health / Movement / ContactDamage 等）
4. 配置 `@export` 参数（HP/速度/伤害等在 Inspector 中调整）
5. 添加精灵和碰撞体
6. F6 测试

### 组件挂载步骤

1. 在场景中添加子节点 → 选择 Node
2. 在 Inspector 中 Attach Script → 选择对应组件脚本
3. 或直接从文件系统拖拽组件 `.gd` 文件到场景节点上
4. 在 Inspector 中调整组件参数

## 注意事项

- 同类敌人（如所有骷髅变体）共享 `EnemyBase` 脚本，差异通过组件参数和 EnemyData 配置实现
- BOSS 场景挂载 `boss_base.gd`，不在 `enemies/` 中单独说明
- 实体场景不应直接引用其他实体场景（实例化由 SpawnerComponent 或 GameManager 负责）
