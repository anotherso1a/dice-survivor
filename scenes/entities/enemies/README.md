# scenes/entities/enemies/ — 敌人场景

## 目录职责

存放各种敌人类型的 `.tscn` 场景文件。每种敌人是一个独立的场景，通过不同的组件组合和参数配置实现行为差异。

## 敌人场景文件

| 文件 | 名称 | 类型 | 核心组件组合 |
|------|------|------|-------------|
| `skeleton_basic.tscn` | 骷髅兵 | BASIC | Health + Movement + ContactDamage |
| `skeleton_tank.tres` | 骷髅盾兵 | TANK | Health + Movement + ContactDamage（高HP低速） |
| `skeleton_ranged.tscn` | 骷髅弓手 | RANGED | Health + Movement + RangedAttack |
| `boss_anti_one.tscn` | 反一号 | BOSS | Health + Movement + BossAI + MultiPhase |

## 开发方式

### 新增敌人

1. 确定敌人类型和需要的组件
2. 在此目录创建 `.tscn`，根节点 CharacterBody2D + `enemy_base.gd`
3. 挂载组件节点（参照上方组件组合）
4. 在 Inspector 中配置组件参数（HP/速度/伤害等）
5. 添加精灵图（`AnimatedSprite2D`）和碰撞体
6. 创建对应数据文件（`data/enemies/xxx.tres`），在 `scene` 字段引用本场景
7. 在波次配置（`data/waves/`）中引用

### 敌人数据 vs 敌人场景

```
data/enemies/skeleton_basic.tres  ← 数值配置（HP=6, 速度=80, 伤害=3）
scenes/entities/enemies/skeleton_basic.tscn ← 节点树 + 组件 + 精灵
```

- 数据文件定义**数值**
- 场景文件定义**行为和外观**
- 两者通过 `EnemyData.scene` 字段关联

## 注意事项

- 同种敌人的不同变体（如精英版）可以通过同一场景 + 不同 EnemyData 实现
- BOSS 场景使用 `boss_base.gd`，支持多阶段逻辑
- 敌人的出生警告由 `SpawnerComponent` 或 `GameManager` 管理，不在敌人场景内
