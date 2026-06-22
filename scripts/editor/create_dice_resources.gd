## 编辑器工具 - 创建冰霜和火焰骰子资源
## 在 Godot 编辑器中：选中此脚本 → 顶部菜单"文件" → "运行脚本"
@tool
extends EditorScript

func _run() -> void:
    print("🎲 开始创建冰霜和火焰骰子资源...")
    
    ## 1. 创建冰霜投射物效果
    var frost_effect = ProjectileEffect.new()
    frost_effect.effect_name = "冰霜投射物"
    frost_effect.element = AttackEffect.ElementType.FROST
    frost_effect.base_damage = 8  # 冰霜骰子基础伤害
    frost_effect.freeze_chance = 0.02  # 2% 冰冻概率
    frost_effect.freeze_duration = 2.0
    frost_effect.slow_duration = 2.0
    frost_effect.slow_factor = 0.5
    frost_effect.speed = 450.0  # 冰锥速度
    
    var error = ResourceSaver.save(frost_effect, "res://data/attacks/frost_projectile.tres")
    if error == OK:
        print("✅ 冰霜效果已保存: data/attacks/frost_projectile.tres")
    else:
        push_error("❌ 保存冰霜效果失败: " + error_string(error))
    
    ## 2. 创建火焰投射物效果
    var fire_effect = ProjectileEffect.new()
    fire_effect.effect_name = "火焰投射物"
    fire_effect.element = AttackEffect.ElementType.FIRE
    fire_effect.base_damage = 9  # 火焰骰子基础伤害（比正常少1）
    fire_effect.burn_duration = 2.0
    fire_effect.burn_tick_interval = 0.5
    fire_effect.burn_damage = 1
    fire_effect.speed = 400.0  # 火球速度
    
    error = ResourceSaver.save(fire_effect, "res://data/attacks/fire_projectile.tres")
    if error == OK:
        print("✅ 火焰效果已保存: data/attacks/fire_projectile.tres")
    else:
        push_error("❌ 保存火焰效果失败: " + error_string(error))
    
    ## 3. 创建冰霜骰子数据（简化版 - 后续需要配置骰面）
    var frost_dice = DiceData.new()
    frost_dice.dice_id = &"d6_frost"
    frost_dice.dice_name = "冰霜骰子"
    frost_dice.sides = 6
    frost_dice.cooldown = 1.0
    frost_dice.durability = 60
    frost_dice.attack_effect = frost_effect
    
    ## TODO: 需要创建 FaceData 资源并赋值给 combat_faces
    ## 临时：创建一个简单的骰面配置
    for i in range(6):
        var face = FaceData.new()
        face.value = i + 1
        face.damage = 8 + (i + 1)  # 点数越高伤害越高
        face.face_name = "冰霜 %d" % [i + 1]
        frost_dice.combat_faces.append(face)
    
    error = ResourceSaver.save(frost_dice, "res://data/dice/frost_d6.tres")
    if error == OK:
        print("✅ 冰霜骰子已保存: data/dice/frost_d6.tres")
    else:
        push_error("❌ 保存冰霜骰子失败: " + error_string(error))
    
    ## 4. 创建火焰骰子数据（简化版）
    var fire_dice = DiceData.new()
    fire_dice.dice_id = &"d6_fire"
    fire_dice.dice_name = "火焰骰子"
    fire_dice.sides = 6
    fire_dice.cooldown = 1.0
    fire_dice.durability = 60
    fire_dice.attack_effect = fire_effect
    
    ## TODO: 需要创建 FaceData 资源并赋值给 combat_faces
    for i in range(6):
        var face = FaceData.new()
        face.value = i + 1
        face.damage = 9 + (i + 1)  # 火焰伤害略高
        face.face_name = "火焰 %d" % [i + 1]
        fire_dice.combat_faces.append(face)
    
    error = ResourceSaver.save(fire_dice, "res://data/dice/fire_d6.tres")
    if error == OK:
        print("✅ 火焰骰子已保存: data/dice/fire_d6.tres")
    else:
        push_error("❌ 保存火焰骰子失败: " + error_string(error))
    
    print("🎉 资源创建完成！请检查 data/ 目录")
    print("⚠️ 注意：骰面数据（FaceData）是临时创建的，建议后续在编辑器中优化")
