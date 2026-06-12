# data/relics/ — 遗物数据

## 目录职责

存放所有遗物的 `.tres` Resource 配置文件。遗物是被动型持续效果，在整局游戏中生效，影响战斗或赌博的结算规则。

## 数据结构

对应脚本类：`scripts/core/relic_data.gd`（`RelicData`）

### RelicData 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `relic_id` | StringName | 唯一标识 |
| `relic_name` | String | 显示名称 |
| `description` | String | 遗物描述文本 |
| `rarity` | Rarity | 稀有度：COMMON / UNCOMMON / RARE / EPIC / LEGENDARY |
| `icon` | Texture2D | 遗物图标 |
| `applies_to` | StringName | 生效场景：`&"combat"` / `&"gamble"` / `&"both"` |
| `effect_script` | GDScript | 效果逻辑脚本引用 |
| `params` | Dictionary | 效果参数 |

## 开发方式

### 新增遗物

1. 右键此目录 → 新建资源 → 选 `RelicData`
2. 填写基础属性（名称、描述、稀有度、图标）
3. 设定 `applies_to` 指定生效场景
4. 编写效果逻辑脚本（`scripts/relics/xxx_effect.gd`），在 `effect_script` 中引用
5. 在 `params` 中定义效果参数
6. 保存为 `xxx.tres`

### 已有遗物（来自设计文档）

| 文件名 | 名称 | 稀有度 | 说明 |
|--------|------|--------|------|
| `lucky_coin.tres` | 幸运硬币 | COMMON | 赌博模式 +10% 赢率 |
| `dual_face.tres` | 双面骰 | UNCOMMON | 暴击时触发两次效果 |
| `phoenix_feather.tres` | 凤凰羽毛 | RARE | 死亡时复活一次，HP 恢复 50% |
| `frozen_hourglass.tres` | 冰冻沙漏 | EPIC | 所有敌人减速 20% |
| `gamblers_soul.tres` | 赌徒之魂 | LEGENDARY | 赌博赢了伤害翻倍，输了伤害也翻倍 |

## 注意事项

- 遗物效果是**被动持续**的，与技能的**主动一次性**不同
- 效果逻辑由 `effect_script` 指向的 `.gd` 文件实现，遗物数据本身只存配置
- 遗物列表存储在 `RunState.relics` 中，当局有效（重开清零）
- 遗物的触发时机：通过 `EventBus` 订阅对应信号（如 `dice_rolled`、`enemy_died`）
