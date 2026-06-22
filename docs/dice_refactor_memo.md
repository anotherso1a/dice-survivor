# 🎲 冰霜与火焰骰子重构 - 工作备忘录

> **日期**：2026-06-23  
> **状态**：第一阶段（基础元素效果）代码完成，待测试  
> **下一步**：测试基础效果 vs 实现特殊点数效果

---

## ✅ 已完成的工作

### 1. 修改核心脚本

| 文件 | 修改内容 |
|------|---------|
| `scripts/effects/bullet.gd` | 添加 `_effect` 变量、修改 `setup()` 方法、添加 `_apply_element_effect()` |
| `scripts/systems/projectile_executor.gd` | 完善 `_create_projectile()`、正确对接 `Bullet.setup()` |
| `scripts/entities/enemy_base.gd` | 动态添加 `StatusComponent`、处理冰冻/点燃效果 |
| `scripts/components/status_component.gd` | 创建状态组件（管理冰冻/点燃/减速） |
| `scripts/core/projectile_effect.gd` | 添加元素效果属性（冰冻概率、点燃持续时间等） |

### 2. 创建工具脚本

| 文件 | 用途 |
|------|------|
| `scripts/editor/create_dice_resources.gd` | 在 Godot 编辑器中运行，自动创建骰子资源文件 |
| `docs/test_dice_setup.md` | 测试指南（如何验证元素效果） |

---

## 📋 还需要做的工作

### 第一阶段：让基础元素效果工作 🔜

- [x] 修改脚本
- [ ] **创建资源文件**（`.tres`）
  - 需要用户在 Godot 编辑器中运行 `create_dice_resources.gd`
  - 或者手动创建 `data/attacks/frost_projectile.tres` 和 `fire_projectile.tres`
- [ ] **测试**
  - 验证冰霜骰子的冰冻、减速效果是否生效
  - 验证火焰骰子的点燃效果是否生效

### 第二阶段：实现特殊点数效果 🚀（后续优化）

根据用户的详细描述：

#### 冰霜骰子特殊效果
- **2、3 点**：命中后散出小范围寒气（AOE 减速）
- **1 点**：冰霜射线（从角色发出，对射线上所有敌人造成大量伤害并减速，50% 概率冰冻）

**需要做的**：
1. 创建 `FrostProjectile.gd`（继承 `Bullet`）
2. 重写 `_apply_element_effect()` 方法，根据 `face.value` 分发逻辑
3. 创建冰霜射线场景 `scenes/effects/frost_ray.tscn` + `frost_ray.gd`
4. 创建寒气 AOE 场景 `scenes/effects/frost_aoe.tscn` + `frost_aoe.gd`

#### 火焰骰子特殊效果
- **2、3 点**：命中敌人后在小范围产生火场（AOE 点燃）
- **1 点**：大号火球，命中后留下更大范围的火场

**需要做的**：
1. 创建 `FireProjectile.gd`（继承 `Bullet`）
2. 重写 `_apply_element_effect()` 方法，根据 `face.value` 分发逻辑
3. 创建火场区域场景 `scenes/effects/fire_field.tscn` + `fire_field.gd`
4. 修改 `ProjectileEffect`，添加 `projectile_scene` 属性（指定使用哪个场景）

---

## 🧪 如何测试基础元素效果

### 步骤 1：创建资源文件

**方案 A：在 Godot 编辑器中运行脚本**
1. 打开 Godot 编辑器
2. 选中 `scripts/editor/create_dice_resources.gd`
3. 点击顶部菜单的 "文件" → "运行脚本"
4. 检查输出面板，确认资源文件已创建

**方案 B：手动创建资源文件**
1. 在编辑器中右键 `data/attacks/` → "新建资源"
2. 选择 `ProjectileEffect`
3. 配置属性（参考 `docs/dice_development_guide.md`）
4. 保存为 `frost_projectile.tres` 和 `fire_projectile.tres`

### 步骤 2：添加骰子到玩家

在 `GameManager.gd` 的 `_ready()` 中临时添加：
```gdscript
func _ready() -> void:
    # ... 现有代码 ...
    
    # 测试：添加冰霜骰子
    var frost_dice = preload("res://data/dice/frost_d6.tres")
    player.add_dice(frost_dice)
    
    # 测试：添加火焰骰子
    var fire_dice = preload("res://data/dice/fire_d6.tres")
    player.add_dice(fire_dice)
```

### 步骤 3：运行游戏并观察

1. 运行游戏
2. 投掷冰霜骰子，观察：
   - ✅ 冰锥是否向敌人发射？
   - ✅ 命中后敌人是否减速（移动变慢）？
   - ✅ 是否有 2% 概率冰冻敌人（暂停移动）？
3. 投掷火焰骰子，观察：
   - ✅ 火球是否向敌人发射？
   - ✅ 命中后敌人是否点燃（持续受到伤害）？

### 步骤 4：查看调试输出

开启调试开关：
- `Bullet.debug = true`（在编辑器中选中子弹场景）
- `StatusComponent.debug = true`（在代码中临时设置）

查看 Godot 输出面板，确认：
- `[Bullet] hit %s | dmg=%d` - 命中敌人
- `[Status] 应用冰冻/点燃/减速` - 元素效果已应用
- `[Enemy] 点燃伤害: %d` - 持续伤害生效

---

## 🤔 下一步应该选择什么？

### 选项 A：先测试基础效果（推荐 ⭐）

**理由**：
1. 确保基础架构正确
2. 及早发现 bug（如果有）
3. 减少对后续特殊效果实现的影响

**需要做的**：
1. 创建资源文件（运行编辑器脚本或手动创建）
2. 添加骰子到玩家
3. 运行游戏并观察
4. 如果发现问题，修复 bug

### 选项 B：直接继续实现特殊点数效果

**理由**：
1. 更接近用户的完整需求
2. 减少后续的返工（如果基础架构正确）

**需要做的**：
1. 创建自定义投射物脚本（`FrostProjectile.gd`, `FireProjectile.gd`）
2. 创建特殊效果场景（冰霜射线、火场区域、寒气 AOE）
3. 修改 `ProjectileEffect`，添加 `projectile_scene` 属性
4. 修改 `ProjectileExecutor`，根据 `effect.projectile_scene` 加载场景

**风险**：
- 如果基础架构有 bug，特殊效果也会跟着错
- 任务量较大，可能需要较长时间

---

## 📊 当前已知问题

1. **`StatusComponent` 的动态添加**
   - 我在 `EnemyBase._ready()` 中动态添加 `StatusComponent`
   - 但是，如果敌人场景**已经在编辑器中挂载了** `StatusComponent`，会重复创建节点
   - **修复方案**：在添加前检查 `has_node("StatusComponent")`

2. **点燃伤害的逻辑位置**
   - 当前 `StatusComponent.burn_tick` 信号是在 `StatusComponent` 内部触发的
   - 但是，实际的伤害逻辑应该由 `BurnComponent` 处理，还是 `StatusComponent` 处理？
   - **当前方案**：在 `EnemyBase._on_burn_tick()` 中直接调用 `_health.take_damage()`（简化版）
   - **未来优化**：让 `BurnComponent` 统一处理点燃伤害

3. **冰冻状态的视觉效果**
   - 当前只暂停敌人的移动（`_physics_process()` 中的检查）
   - 但是，**没有视觉效果**（例如：敌人变蓝、显示冰冻图标等）
   - **未来优化**：在 `_on_status_changed()` 中添加 VFX

---

## 📝 备忘录更新记录

- 2026-06-23 02:30 - 创建备忘录，记录第一阶段完成状态
