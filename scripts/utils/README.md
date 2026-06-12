# scripts/utils/ — 工具类

## 目录职责

存放无状态的纯工具函数和全局常量定义。这些工具不持有任何状态，只提供可复用的计算和转换方法。通常是静态方法或常量集合。

> **核心原则**：utils 是最底层的依赖，不引用项目中的任何其他脚本目录。

## 包含文件

| 文件 | 类名 | 说明 |
|------|------|------|
| `constants.gd` | Constants | 全局常量（视口尺寸/生成参数/游戏数值上限等） |
| `math_utils.gd` | MathUtils | 数学工具（随机/插值/向量计算等） |
| `json_loader.gd` | JsonLoader | JSON 导入导出（Mod 支持/.tres↔JSON 转换） |

## 使用方式

### 常量引用

```gdscript
# constants.gd
class_name Constants
extends RefCounted

const VIEWPORT_W: float = 1280.0
const VIEWPORT_H: float = 720.0
const SPAWN_MARGIN: float = 60.0
const MIN_PLAYER_DIST: float = 150.0
const MAX_DICE_SLOTS: int = 6
```

```gdscript
# 在其他脚本中使用
var pos: Vector2 = Vector2(Constants.VIEWPORT_W / 2, Constants.VIEWPORT_H / 2)
```

### 工具方法

```gdscript
# math_utils.gd
class_name MathUtils
extends RefCounted

static func random_in_rect(margin: float, w: float, h: float) -> Vector2:
    return Vector2(
        randf_range(margin, w - margin),
        randf_range(margin, h - margin)
    )

static func random_direction() -> Vector2:
    var angle: float = randf() * TAU
    return Vector2(cos(angle), sin(angle))
```

```gdscript
# 调用
var pos: Vector2 = MathUtils.random_in_rect(60.0, 1280.0, 720.0)
```

## 依赖规则

```
utils 可以引用：无（Godot 内置 API 除外）
utils 不可引用：core、systems、components、entities、effects、ui、minigames
```

## 新增工具类判断标准

**应该放入 utils**：
- 纯计算函数（输入→输出，无副作用）
- 多个脚本都需要复用的常量
- 与项目无关的通用工具（如 JSON 解析、向量运算）

**不应该放入 utils**：
- 涉及游戏逻辑的计算 → 放在 core 或对应系统里
- 需要访问场景树的操作 → 不属于工具类
- 只在一个地方使用的局部函数 → 就地定义
