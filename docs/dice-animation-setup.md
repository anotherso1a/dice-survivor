# 骰子动画配置指南

## 当前状态

`Dice.tscn` 场景已添加 `AnimatedSprite2D` 节点，脚本已搭好动画状态机。

你需要做的就是在 Godot 编辑器里把动画资源配上。

---

## 步骤 1：为 AnimatedSprite2D 创建 SpriteFrames 资源

1. 在 Godot 里打开 `scenes/entities/Dice.tscn`
2. 选中 `Dice / Visual / AnimatedSprite2D` 节点
3. 在检查器（Inspector）里，找到 `Frames` 属性（显示 `[empty]`）
4. 点击 `[empty]` → `新建 SpriteFrames`
5. 此时 `Frames` 会变成 `[SpriteFrames]`（点击可打开底部编辑面板）

---

## 步骤 2：配置动画

SpriteFrames 面板在底部（和动画编辑器类似），你需要创建以下动画：

### 动画 1：`spin`（旋转动画，CD 中播放）

两种做法：

**做法 A — 用代码驱动旋转（推荐，已内置）**
- 不需要在 SpriteFrames 里创建 `spin` 动画
- 脚本会在 `_process_spinning()` 里直接改 `_visual.rotation_degrees`
- 你只需要确保 SpriteFrames 里有任意动画能让精灵显示出来

**做法 B — 用帧动画做旋转**
- 在 SpriteFrames 面板，点击 `添加动画`，命名为 `spin`
- 把你的骰子旋转 sprite sheet 切好帧，全选拖进 `spin` 动画
- 勾选 `循环`（Loop）
- 脚本会自动调用 `_sprite.play("spin")`

---

### 动画 2：`idle`（默认待机，可选）

- 在 SpriteFrames 面板，点击 `添加动画`，命名为 `idle`
- 放一帧骰子默认画面即可
- CD 为 0（无冷却的骰子）会播放这个动画

---

### 动画 3~8：`face_0` ~ `face_5`（展示掷出的面，0.2s）

两种做法：

**做法 A — 用独立动画（推荐，灵活）**

在 SpriteFrames 面板：
1. 点击 `添加动画`，命名为 `face_0`（对应第 1 面）
2. 添加对应面的帧（可以只有 1 帧，停留 0.2s）
3. 重复创建 `face_1` ~ `face_5`
4. 在 `dice_entity.gd` 的 `_enter_showing_face()` 里取消注释这段：

```gdscript
var anim_name := "face_%d" % _pending_face.face_index
if _sprite.sprite_frames.has_animation(anim_name):
    _sprite.play(anim_name)
```

⚠️ 需要 `FaceData` 里有 `face_index: int` 字段（0~5）

---

**做法 B — 用 frame 直接切换（简单，不需要多个动画）**

1. 在 SpriteFrames 面板，创建一个动画叫 `faces`
2. 把 6 个面的帧按顺序放进去（第 0 帧 = 面1，第 1 帧 = 面2…）
3. 在 `dice_entity.gd` 的 `_enter_showing_face()` 里改成：

```gdscript
_sprite.play("faces")
_sprite.frame = _pending_face.face_index  # 直接跳到对应帧
```

---

## 步骤 3：FaceData 需要添加 face_index 字段

打开 `scripts/core/face_data.gd`，添加：

```gdscript
## 面的索引（0~5），对应骰子 6 个面
## 用于动画切换：_sprite.frame = face_index 或播放 "face_x" 动画
@export var face_index: int = 0
```

---

## 步骤 4：DiceData 里配置 cooldown

打开 `scripts/core/dice_data.gd`，确保有：

```gdscript
## 骰子冷却时间（秒），CD 期间播放旋转动画
@export var cooldown: float = 1.0
```

---

## 动画状态机流程图

```
[初始]
  │
  ├─ dice_data.cooldown > 0 → SPINNING（旋转动画）
  │                            │
  │                            └─ roll() 被调用 → SHOWING_FACE（展示面 0.2s）
  │                                                            │
  │                                                            └─ 0.2s 后 → 发出 rolled 信号 → 回到 SPINNING
  │
  └─ dice_data.cooldown == 0 → IDLE（待机动画，不自动触发 roll）
```

---

## 调试技巧

在 `dice_entity.gd` 里已经有 `print("[Dice] 掷出：...")` 的调试输出。

运行游戏后，打开 Godot 输出窗口，应该能看到掷骰结果。

如果动画没播放：
1. 检查 `AnimatedSprite2D` 的 `Frames` 是否绑定了 SpriteFrames 资源
2. 检查动画名称是否和脚本里的完全一致（`spin` / `idle` / `face_0` 等）
3. 在 `_process()` 里加 `print(_anim_state)` 看状态是否正确切换
