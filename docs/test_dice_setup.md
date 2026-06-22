## 快速测试场景 - 验证元素效果
## 将此场景添加到 Main 场景中，用于测试冰霜和火焰骰子

[gd_scene load_steps=3 format=3]

[ext_resource path="res://scripts/entities/player.gd" type="Script" id="1"]
[ext_resource path="res://scripts/systems/game_manager.gd" type="Script" id="2"]

[sub_resource path="res://data/dice/frost_d6.tres" type="Resource" id="1_frost"]
[sub_resource path="res://data/dice/fire_d6.tres" type="Resource" id="1_fire"]

[node name="TestPlayer" type="CharacterBody2D"]
script = ExtResource("1")
## 动态添加骰子（测试用）
## 在 _ready() 中调用：
##   var frost_dice = preload("res://data/dice/frost_d6.tres")
##   add_dice(frost_dice)

[node name="TestUI" type="CanvasLayer"]
## 添加两个按钮：切换冰霜骰子 / 切换火焰骰子

[node name="FrostButton" type="Button" parent="TestUI"]
text = "切换冰霜骰子"
position = Vector2(100, 100)
pressed.connect(_on_frost_button_pressed)

[node name="FireButton" type="Button" parent="TestUI"]
text = "切换火焰骰子"
position = Vector2(100, 150)
pressed.connect(_on_fire_button_pressed)

[node name="StatusLabel" type="Label" parent="TestUI"]
text = "当前骰子：无"
position = Vector2(100, 200)
```

## 使用方法：
1. 将此场景保存为 `scenes/test/test_dice.tscn`
2. 在 `GameManager.gd` 的 `_ready()` 中添加玩家时，使用此场景
3. 运行游戏，点击 UI 按钮切换骰子类型
4. 观察敌人是否受到元素效果影响（冰冻、点燃、减速）

## 调试技巧：
- 开启 `Bullet` 的 `debug = true`
- 开启 `StatusComponent` 的 `debug = true`
- 查看 Godot 输出窗口的打印信息
