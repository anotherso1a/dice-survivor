# data/enemies/ — 敌人数据

## 目录职责

存放所有敌人类型的 `.tres` Resource 配置文件。每种敌人由数据文件定义属性，由对应的场景文件（`scenes/entities/enemies/`）定义节点树和组件组合。

## 数据结构

对应脚本类：`scripts/core/enemy_data.gd`（`EnemyData`）

### EnemyData 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `enemy_id` | StringName | 唯一标识 |
| `display_name` | String | 显示名称 |
| `enemy_type` | EnemyType | 类型：BASIC / RANGED / TANK / SUICIDE / ELITE / BOSS |
| `max_hp` | int | 最大血量 |
| `move_speed` | float | 移动速度 |
| `contact_damage` | int | 接触伤害 |
| `resist_element` | StringName | 抗性元素（`&"fire"` / `&"ice"` / `&""`） |
| `resist_percent` | float | 抗性百分比（0.0~1.0） |
| `scene` | PackedScene | 对应的 .tscn 场景引用 |
| `drop_table` | Dictionary | 掉落表 |

## 敌人类型说明

| EnemyType | 行为特征 | 组件组合 |
|-----------|---------|---------|
| BASIC | 追玩家、接触伤害 | Health + Movement + ContactDamage |
| RANGED | 保持距离、远程攻击 | Health + Movement + RangedAttack |
| TANK | 慢速、高血量 | Health + Movement + ContactDamage + Shield |
| SUICIDE | 快速冲向玩家、自爆 | Health + Movement + ExplosionOnDeath |
| ELITE | 增强版基础敌人 | Health + Movement + ContactDamage + BuffAura |
| BOSS | 大型、多阶段 | Health + Movement + BossAI + MultiPhase |

## 开发方式

### 新增敌人

1. 右键此目录 → 新建资源 → 选 `EnemyData`
2. 填写属性、设定类型和数值
3. 创建对应场景文件（见 `scenes/entities/enemies/README.md`）
4. 在 `scene` 字段中引用该 `.tscn`
5. 在波次配置（`data/waves/`）中引用

### 已有敌人（来自设计文档）

| 文件名 | 名称 | 类型 | 说明 |
|--------|------|------|------|
| `skeleton_basic.tres` | 骷髅兵 | BASIC | 基础近战敌人 |
| `skeleton_tank.tres` | 骷髅盾兵 | TANK | 高血量慢速 |
| `skeleton_ranged.tres` | 骷髅弓手 | RANGED | 远程投射攻击 |
| `boss_anti_one.tres` | 反一号 | BOSS | 第一个 BOSS |

## 注意事项

- 敌人的**行为**由组件决定，**数值**由数据文件决定——两者分离
- 掉落表格式：`{"coins": [5, 10], "exp": [10, 20], "items": [...]}`，具体由 `DropComponent` 解读
- BOSS 类型有独立的 `BossBase` 脚本和多阶段逻辑，不使用普通 `EnemyBase`
