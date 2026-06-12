# data/waves/ — 波次配置

## 目录职责

存放每波敌人生成配置的 `.tres` Resource 文件。每个波次定义了敌人组成、生成间隔、难度参数等。

## 数据结构

对应脚本类：`scripts/core/wave_data.gd`（`WaveData`）

### WaveData 核心字段（预期）

| 字段 | 类型 | 说明 |
|------|------|------|
| `wave_index` | int | 波次序号 |
| `enemy_groups` | Array[Dictionary] | 敌人组（每组含 enemy_id + 数量 + 生成间隔） |
| `spawn_interval` | float | 单个敌人生成间隔（秒） |
| `is_boss_wave` | bool | 是否 BOSS 波（每 5 波） |
| `boss_data` | EnemyData | BOSS 数据引用 |

### enemy_groups 格式

```gdscript
# 每个组定义一种敌人的生成规则
{
    "enemy_id": &"skeleton_basic",  # 指向 data/enemies/ 中的资源
    "count": 5,                      # 本波生成数量
    "delay": 0.5,                    # 每个之间的间隔（秒）
    "start_after": 0.0,              # 波次开始后多久开始生成此组
}
```

## 开发方式

### 新增波次

1. 右键此目录 → 新建资源 → 选 `WaveData`
2. 设定 `wave_index`
3. 添加 `enemy_groups` 数组元素
4. 如是 BOSS 波，设定 `is_boss_wave = true` 并引用 BOSS 数据
5. 保存为 `wave_XX.tres`

### 波次设计规则（来自设计文档）

- 每 5 波出现 BOSS
- 波次间难度递增：敌人数量 ↑、速度 ↑、新增精英怪
- BOSS 波之间有休息站（小游戏中转）
- 波次配置在 `GameManager` 中按 `current_wave` 索引加载

## 注意事项

- 波次配置是**静态数据**，运行时的生成逻辑由 `SpawnerComponent` 负责
- 波次之间可以共享 `enemy_groups` 模板（如 wave_02 和 wave_03 的基础敌人相同，只有数量差异）
- 后续支持无尽模式时，可由代码在已有波次基础上自动缩放生成
