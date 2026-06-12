# scripts/systems/ — Autoload 全局系统单例

## 目录职责

存放所有 Autoload 全局单例脚本。这些脚本在游戏启动时自动加载，生命周期贯穿整个进程或当局游戏。负责跨场景的全局状态管理和协调。

> **核心原则**：Autoload 是服务定位器，不是逻辑垃圾桶。只放**真正的全局状态**和**跨场景协调**逻辑。

## 包含文件

| 文件 | 类名 | Autoload 名 | 生命周期 | 职责 |
|------|------|-------------|---------|------|
| `event_bus.gd` | EventBus | EventBus | 进程级 | 全局信号总线，跨场景解耦通信 |
| `game_manager.gd` | GameManager | GameManager | 进程级 | 游戏流程状态机（菜单→战斗→休息→BOSS→结算） |
| `run_state.gd` | RunState | RunState | 当局级 | 当局运行时状态（金币/HP/骰子背包/遗物列表） |
| `dice_manager.gd` | DiceManager | DiceManager | 当局级 | 骰子池 CRUD、骰面修改、合成、技能应用 |
| `save_manager.gd` | SaveManager | SaveManager | 进程级 | 存档/读档/设置持久化 |

## 生命周期说明

| 级别 | 含义 | 重开游戏时 |
|------|------|-----------|
| 进程级 | 从游戏启动到关闭一直存在 | 保留，重置内部状态 |
| 当局级 | 从开始游戏到返回主菜单 | 销毁重建或调用 `reset()` |

## 开发方式

### 引用 Autoload

```gdscript
# 全局信号
EventBus.enemy_died.emit(global_position, enemy_data)

# 游戏流程
GameManager.transition_to(GameManager.Phase.REST_STATION)

# 当局状态
var coins: int = RunState.coins
RunState.coins += 10

# 骰子管理
var dice: DiceData = DiceManager.get_dice(&"standard_d6")
```

### 新增 Autoload 的判断标准

**应该新增**：
- 需要在多个场景间共享的状态
- 需要在场景切换时保留的数据
- 需要被不相关的系统同时访问的服务

**不应该新增**：
- 只在单个场景内使用的逻辑 → 写在场景脚本里
- 可以通过组件组合实现的行为 → 写在 components/ 里
- UI 展示逻辑 → 写在 ui/ 里

### 注册新 Autoload

1. 创建脚本文件
2. 打开 `项目 → 项目设置 → Autoload`
3. 添加脚本路径，设定名称
4. 确保 `project.godot` 中已自动注册

## 依赖规则

```
systems 可以引用：core、utils
systems 不可引用：components、entities、effects、ui、minigames
```

- systems 之间可以互相引用，但要避免循环依赖
- systems 与场景实体的通信通过 EventBus 信号，不直接 `get_node()`
- systems 不持有场景节点的引用，只持有数据（core 层的 Resource）

## EventBus 使用规范

### 信号命名

```gdscript
# snake_case，参数必须带类型
signal enemy_died(pos: Vector2, enemy_data: EnemyData)
signal coins_changed(new_amount: int)
```

### 发射信号

```gdscript
# 在任何脚本中都可以发射
EventBus.enemy_died.emit(global_position, enemy_data)
```

### 监听信号

```gdscript
# 在 _ready() 中连接
func _ready() -> void:
    EventBus.enemy_died.connect(_on_enemy_died)

# 在 _exit_tree() 中断开（如果节点可能被回收）
func _exit_tree() -> void:
    EventBus.enemy_died.disconnect(_on_enemy_died)

func _on_enemy_died(pos: Vector2, data: EnemyData) -> void:
    # 处理逻辑
    pass
```

### 信号归属判断

| 通信范围 | 使用方式 |
|---------|---------|
| 同一场景内 | 节点信号（`health.died.connect(...)`） |
| 跨场景/跨系统 | EventBus（`EventBus.enemy_died.emit(...)`） |
