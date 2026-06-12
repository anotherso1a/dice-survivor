# Dice Survivor — 项目记忆

## 项目概况
- 类型：骰子幸存者（土豆兄弟 + Balatro + 杀戮尖塔融合）
- 引擎：Godot 4.6+ / GDScript 2.0
- 平台：Steam（PC/Mac/Linux）
- 美术：像素风 32×32，PICO-8 风格 32 色板
- 视口：1280×720

## 架构决策
- 数据驱动：`.tres` Resource 为主，JSON 导出用于 Mod 支持
- 组合优于继承：组件节点（HealthComponent / MovementComponent 等）
- 信号解耦：EventBus 跨场景，节点信号场景内
- 小游戏：MinigameBase 基类，独立场景
- 详见 `ARCHITECTURE.md`

## 当前 MVP 进度
- M1 已完成：基本战斗循环、骰子切换、精灵装配、受伤/死亡动画、随机出生
- M2~M9 待做：第二骰子、三选一升级、百家乐、卖血、BOSS、美术、音效、平衡

## 碰撞层约定
- Layer 1: Player body
- Layer 2: Enemy body
- Layer 3+: 预留给环境/墙壁
- 敌人碰撞层=2, 碰撞掩码=0（穿过玩家，不物理碰撞）
- 玩家碰撞层=1, 碰撞掩码=0（不被敌人推动）
- 敌人 Hitbox Area2D 碰撞掩码=1（检测 layer 1 的玩家做接触伤害）
- 接触伤害有冷却（默认 0.5s），避免每帧扣血

## 关键文件
- `GAME_DESIGN.md` — 完整游戏设计文档
- `ARCHITECTURE.md` — 项目架构规划文档

## 用户背景
- 前端工程师，Godot 新手
- 需要解释 shader/着色器等图形术语
