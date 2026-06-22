# 🎲 骰子开发指南

> **目标读者**：AI Agent 或开发者  
> **用途**：新增骰子时的标准流程  
> **前置知识**：已阅读 `ARCHITECTURE.md` 第十一章（攻击效果系统架构）

---

## 一、快速开始：新增一个标准骰子

### 场景：创建一个"火焰骰子"（投射物攻击）

#### 步骤 1：创建 AttackEffect Resource

1. **在编辑器中创建**
   - 右键 `data/attacks/` → `New Resource`
   - 选择 `ProjectileEffect`
   - 保存为 `fireball_effect.tres`

2. **配置属性**
   ```gdscript
   # 在 Inspector 中设置
   base_damage = 15
   speed = 400.0
   penetration = 0  # 不穿透
   element = &"fire"
   ```

#### 步骤 2：创建 DiceData Resource

1. **创建 Resource**
   ```gdscript
   # 右键 data/dice/ → New Resource → DiceData
   # 保存为 fire_d6.tres
   ```

2. **配置核心属性**
   ```gdscript
   display_name = "火焰骰"
   dice_material = preload("res://data/materials/fire.tres")
   max_durability = 60
   
   # 引用步骤 1 创建的 AttackEffect
   attack_effect = preload("res://data/attacks/fireball_effect.tres")
   
   # 骰面数据（6个面）
   faces = [
       FaceData.new(1, 8, "火苗", preload("res://assets/sprites/faces/fire_1.png")),
       FaceData.new(2, 10, "小火球", preload("res://assets/sprites/faces/fire_2.png")),
       # ... 其他面
   ]
   ```

#### 步骤 3：测试

1. 在 `GameManager.gd` 中添加骰子到玩家：
   ```gdscript
   # 临时测试代码
   var fire_dice = preload("res://data/dice/fire_d6.tres")
   player.add_dice(fire_dice)
   ```

2. 运行游戏，投掷骰子，验证：
   - ✅ 火焰子弹正确发射
   - ✅ 伤害值正确
   - ✅ 元素效果生效（点燃敌人）

---

## 二、攻击类型选择指南

### 我应该用哪种 AttackEffect？

| 攻击表现 | 选择类型 | 示例 |
|---------|---------|------|
| 子弹、火球、冰锥（有飞行轨迹） | `ProjectileEffect` | 枪手骰子、火焰骰子 |
| 挥砍、戳刺（以玩家为中心） | `MeleeEffect` | 战士骰子、斧头骰子 |
| 闪电、陨石（远程无飞行） | `SpellEffect` | 法师骰子、雷电骰子 |
| 火焰路径、毒云（持续区域） | `DurationEffect` | 炼金骰子、毒气骰子 |
| 召唤宠物 | `SummonEffect` | 亡灵骰子、精灵骰子 |

### 特殊需求处理

#### 需求：子弹能穿透多个敌人
```gdscript
# 在 ProjectileEffect 中设置
penetration = 2  # 穿透 2 个额外敌人（共命中 3 个）
```

#### 需求：子弹能弹射
```gdscript
# 在 ProjectileEffect 中设置
bounce = 1  # 弹射 1 次
```

#### 需求：近战攻击是扇形范围
```gdscript
# 在 MeleeEffect 中设置
shape_type = MeleeEffect.ShapeType.FAN
angle = 120.0  # 120 度扇形
range = 80.0
```

---

## 三、自定义 VFX 开发

### 场景：火焰骰子需要专属的火球特效

#### 方案 A：修改现有 Bullet 外观（简单）

在 `ProjectileEffect` 中指定特效场景：
```gdscript
# fireball_effect.tres
projectile_scene = preload("res://scenes/effects/fireball.tscn")
```

创建 `fireball.tscn`：
1. 继承 `Bullet.gd`
2. 修改 `Sprite2D` 的纹理为火焰精灵
3. 添加 `GPUParticles2D` 作为子节点（火焰拖尾）

#### 方案 B：创建全新的投射物场景（复杂）

如果你的攻击效果完全不同于子弹（例如：雷电链、回旋镖），需要：

1. **创建新场景**
   ```
   scenes/effects/lightning_chain.tscn
   ├── Area2D (根节点)
   │   ├── CollisionShape2D
   │   ├── Line2D (雷电视觉效果)
   │   └── 自定义脚本 lightning_chain.gd
   ```

2. **脚本继承 AttackExecutor**
   ```gdscript
   # lightning_chain.gd
   class_name LightningChain
   extends Node2D
   
   ## 需要实现的接口（由 ProjectileExecutor 调用）
   func setup(direction: Vector2, damage: int, face: FaceData, 
              penetration: int, speed: float) -> void:
       # 自定义初始化逻辑
       pass
   ```

3. **在 ProjectileExecutor 中适配**
   ```gdscript
   # 在 projectile_executor.gd 的 _execute_attack() 中
   var scene = effect.projectile_scene
   if scene == null:
       scene = preload("res://scenes/effects/bullet.tscn")  # 默认子弹
   
   var instance = scene.instantiate()
   # ... 配置并添加到场景
   ```

---

## 四、遗物系统对接

### 如何让遗物修饰我的骰子？

#### 步骤 1：在 AttackEffect 中定义遗物修饰逻辑

```gdscript
# scripts/core/fireball_effect.gd (继承 ProjectileEffect)
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
    super(relics)  # 先调用父类逻辑
    
    for relic in relics:
        match relic.relic_id:
            &"fire_damage_up":  # 火焰伤害+20%
                damage_multiplier += 0.2
            &"fire_burn_duration_up":  # 燃烧持续时间+2秒
                burn_duration += 2.0
```

#### 步骤 2：创建遗物数据

```gdscript
# data/relics/fire_damage_up.tres
extends RelicData

relic_id = &"fire_damage_up"
display_name = "烈焰之心"
description = "火焰伤害+20%"

# 仅影响火元素攻击
affected_elements = [&"fire"]
```

---

## 五、元素反应系统（待实现）

### 当前状态

⚠️ **元素反应系统尚未实现**（Phase 2）

当前版本元素类型（`fire`/`frost`/`lightning` 等）仅作为标签存储在 `AttackEffect.element` 中，不会触发正向反应。

### 未来实现后的效果

当元素反应系统完成后，以下组合会自动触发：

| 元素组合 | 反应效果 |
|---------|---------|
| 冰冻敌人 + 火焰攻击 | 冰冻破裂（爆炸伤害） |
| 感电敌人 + 冰/毒攻击 | 电弧扩散（链式伤害） |
| 燃烧敌人 + 闪电攻击 | 闪电链传导 |

### 开发建议

如果你需要实现元素反应：

1. 创建 `StatusComponent.gd`（挂载到敌人）
2. 创建 `ReactionTable.gd`（数据驱动的反应配置）
3. 在 `enemy_base.gd` 的 `take_damage()` 中接入元素逻辑

---

## 六、测试检查清单

新增骰子后，运行以下检查：

### 基础功能
- [ ] 骰子在编辑器中的数据配置正确（骰面伤害/纹理）
- [ ] 骰子能正确添加到玩家（在 `GameManager` 或测试中）
- [ ] 投掷骰子后，`rolled` 信号正确触发
- [ ] 攻击效果正确执行（子弹发射/近战范围检测等）

### 攻击效果
- [ ] 伤害值正确（`face.damage` × `AttackEffect.damage_multiplier`）
- [ ] 暴击正确计算（如果 `is_crit == true`）
- [ ] 穿透/弹射逻辑正确（如果配置了）
- [ ] 元素标签正确传递（如果配置了）

### VFX 表现
- [ ] 攻击特效正确显示（子弹轨迹/近战范围指示等）
- [ ] 命中特效正确播放（敌人受击动画/粒子效果等）
- [ ] 特效在子弹销毁后正确清理（无内存泄漏）

### 遗物对接
- [ ] 相关遗物正确修饰攻击属性
- [ ] 遗物效果在 UI 中正确显示（如果有）

---

## 七、常见问题 (FAQ)

### Q1: 我的骰子总是发射子弹，但我想要近战攻击

**原因**：`DiceData.attack_effect` 引用了 `ProjectileEffect`，而不是 `MeleeEffect`。

**解决**：
1. 创建 `MeleeEffect` Resource
2. 在 `DiceData` 中将 `attack_effect` 指向它
3. 实现 `MeleeExecutor.gd`（当前是空壳，需要实现）

### Q2: 我想让子弹有特殊的飞行轨迹（例如：螺旋、追踪）

**原因**：当前 `Bullet.gd` 只支持直线飞行。

**解决**：
1. 创建新的投射物场景（继承 `Bullet.gd` 或重写 `_physics_process`）
2. 在 `ProjectileEffect.projectile_scene` 中引用新场景
3. 在自定义脚本中实现追踪逻辑：
   ```gdscript
   func _physics_process(delta: float) -> void:
       # 简单追踪逻辑
       var nearest_enemy = _find_nearest_enemy()
       if nearest_enemy:
           direction = direction.slerp(
               (nearest_enemy.global_position - global_position).normalized(), 
               0.1  # 追踪速度
           )
       global_position += direction * speed * delta
   ```

### Q3: 我想添加全新的攻击类型（例如：时间停止）

**原因**：当前只有 5 种攻击类型，可能不够用。

**解决**：
1. 在 `AttackEffect.gd` 中添加新类型：
   ```gdscript
   enum EffectType { PROJECTILE, MELEE, SPELL, DURATION, SUMMON, TIME_STOP }
   ```
2. 创建对应的 Effect 类（`time_stop_effect.gd`）
3. 创建对应的 Executor 类（`time_stop_executor.gd`）
4. 在 `AttackExecutor.create_executor()` 中添加分支

---

## 八、代码参考

### 完整示例：火焰骰子配置

```gdscript
# ========== data/attacks/fireball_effect.tres ==========
extends ProjectileEffect

base_damage = 15
speed = 400.0
penetration = 0
element = &"fire"
projectile_scene = preload("res://scenes/effects/fireball.tscn")

# 遗物修饰
func _apply_type_specific_relics(relics: Array[RelicData]) -> void:
    super(relics)
    for relic in relics:
        if relic.relic_id == &"fire_penetration_up":
            penetration += 1


# ========== data/dice/fire_d6.tres ==========
display_name = "火焰骰"
dice_material = preload("res://data/materials/fire.tres")
max_durability = 60
attack_effect = preload("res://data/attacks/fireball_effect.tres")

# 骰面（6个面）
faces = [
    FaceData.new(1, 8, "火苗", load("res://assets/faces/fire_1.png")),
    FaceData.new(2, 10, "小火球", load("res://assets/faces/fire_2.png")),
    FaceData.new(3, 12, "火球", load("res://assets/faces/fire_3.png")),
    FaceData.new(4, 15, "大火球", load("res://assets/faces/fire_4.png")),
    FaceData.new(5, 18, "火焰风暴", load("res://assets/faces/fire_5.png")),
    FaceData.new(6, 25, "地狱火", load("res://assets/faces/fire_6.png"))
]
```


---

**文档版本**: v1.0  
**最后更新**: 2026-06-23  
**维护者**: AI Agent / 开发者
