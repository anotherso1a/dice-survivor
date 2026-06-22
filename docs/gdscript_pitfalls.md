# Godot 4 GDScript 防坑指南

> **用途**：每次修改 `.gd` 脚本后运行前快速自查，避免重复踩坑。

---

## 坑 1：未声明变量直接使用

### 错误示例
```gdscript
# ❌ 直接使用未声明的变量
func _ready() -> void:
    if debug:  # `debug` 未声明！
        print("debug mode")
```

### 正确写法
```gdscript
# ✅ 先声明（@export 可在 Inspector 中切换）
@export var debug: bool = false

func _ready() -> void:
    if debug:
        print("debug mode")
```

### 自查清单
- [ ] 所有在 `if` / `for` / `match` 中使用的变量都已声明
- [ ] 局部变量使用 `var` 或 `var x := ...` 声明
- [ ] `@export` 变量放在文件顶部（Inspector 可配置）

---

## 坑 2：方法重写（override）签名不匹配父类

### 错误示例
```gdscript
# ❌ 父类签名：_find_nearest_enemy(source: Node2D, max_range: float = -1)
# 子类签名少了默认参数，Godot 解析失败
func _find_nearest_enemy(source: Node2D) -> Node2D:
    # ...
```

### 正确写法
```gdscript
# ✅ 子类签名必须与父类完全一致（含默认参数）
func _find_nearest_enemy(source: Node2D, max_range: float = -1) -> Node2D:
    # ...
```

### 自查清单
- [ ] 重写父类方法时，复制父类的方法签名（包括所有默认参数）
- [ ] 返回类型必须一致
- [ ] Godot 4.3+ 可使用 `@override` 注解让编辑器帮忙检查

---

## 坑 3：混淆「属性」和「方法」

### 错误示例
```gdscript
# ❌ RunState 中 `relics` 是属性，不是方法
var relics: Array[RelicData] = []

# 错误调用：
var r = RunState.get_relics()  # Method does not exist!
```

### 正确写法
```gdscript
# ✅ 直接访问属性（Autoload 单例通过类名访问）
var relics: Array[RelicData] = RunState.relics
```

### 判断规则

| 代码中定义 | 访问方式 |
|---|---|
| `var x: Type = value` | `Obj.x`（直接访问） |
| `func get_x() -> Type:` | `Obj.get_x()`（方法调用） |

### 自查清单
- [ ] 访问前先检查代码：`var` 声明的是属性，用 `.` 访问
- [ ] `func` 声明的是方法，用 `()` 调用
- [ ] Autoload 单例直接通过名称访问（如 `RunState.xxx`）

---

## 坑 4：调用方法时参数数量/类型不匹配

### 错误示例
```gdscript
# ❌ HealthComponent.take_damage() 只接受 2 个参数
# 却传了 3 个
_health.take_damage(damage, false, null)  # Too many arguments!
```

### 正确写法
```gdscript
# ✅ 查看方法定义后传正确数量的参数
# HealthComponent.gd:
# func take_damage(dmg: int, is_crit: bool) -> void

_health.take_damage(damage, false)  # ✅ 2 个参数
```

### 自查清单
- [ ] 调用方法前，先 `右键 → Go to Definition` 查看方法签名
- [ ] 不要传多余的 `null` 占位参数
- [ ] 可选参数有默认值，调用时可省略

---

## 坑 5：Godot 编辑器缓存导致「类名未解析」

### 现象
```
Error: Identifier "MeleeExecutor" not declared in the current scope.
```
但 `melee_executor.gd` 明明存在且 `class_name MeleeExecutor` 已声明。

### 原因
Godot 编辑器没有重新解析修改后的脚本，`class_name` 未注册到全局。

### 解决方案（三选一）
1. **重新打开脚本文件**（双击在脚本编辑器打开）
2. **运行场景**（`F6` 单独运行当前场景）
3. **重启 Godot 编辑器**（最彻底）

### 预防
- 新增 `class_name` 后，立即保存并重新打开该脚本
- 使用动态加载（`load("res://...")`）代替 `class_name` 引用，避免解析顺序问题

---

## 坑 6：`@onready` 变量在 `_ready()` 外使用

### 错误示例
```gdscript
@onready var _hp_bar: ProgressBar = $HpBar

func _init() -> void:
    _hp_bar.value = 100  # ❌ _ready() 前 @onready 变量还是 null！
```

### 正确写法
```gdscript
func _ready() -> void:
    _hp_bar.value = 100  # ✅ _ready() 后 @onready 才可用
```

---

## 快速排错流程图

```
脚本保存后报错
    ↓
① 看错误信息：哪一行？什么错？
    ↓
② 未声明变量？→ 坑 1
   签名不匹配？→ 坑 2
   方法不存在？→ 坑 3 或 坑 4
   类名未解析？→ 坑 5
    ↓
③ 修复后保存 → 重新打开脚本 → 运行测试
```

---

## 防御性编程模板

```gdscript
## 每个脚本开头声明调试开关
@export var debug: bool = false

## 调用可能存在的方法前用 has_method() 检查
if target.has_method("take_damage"):
    target.take_damage(dmg, false)

## 访问节点前用 is_instance_valid() 检查
if is_instance_valid(enemy):
    enemy.take_damage(dmg, false)

## 数组访问前检查 size()
if _hit_enemies.size() > 0:
    var first = _hit_enemies[0]

## 类型转换用 as + 判空
var enemy := node as EnemyBase
if enemy != null:
    enemy.take_damage(dmg, false)
```
