# assets/sprites/ — 精灵图资源

## 目录职责

存放所有角色、敌人、特效、道具的精灵图资源。每个精灵图是一个独立的 `.png` 文件或 spritesheet。

## 资源分类

| 子类 | 示例 | 说明 |
|------|------|------|
| 角色 | `player/`, `npc/` | 玩家和 NPC 精灵图 |
| 敌人 | `enemies/` | 各类敌人精灵图 |
| 骰子 | `dice/` | 骰子本体和面的精灵图 |
| 特效 | `vfx/` | 爆炸/火焰/冰霜等帧动画 |
| 道具 | `items/` | 金币/经验/遗物图标 |
| 环境 | `environment/` | 地面/墙壁/装饰 |

## 开发规范

- 像素风格精灵图在 Godot Import 中**关闭 Filter**（避免模糊）
- Spritesheet 切割在 `AnimatedSprite2D` 的 `SpriteFrames` 中完成，不需要预先切割图片
- 尺寸建议：角色 32×32 或 48×48，特效 64×64 或 128×128
- 命名格式：`{entity}_{action}.png`，如 `skeleton_walk.png`、`player_idle.png`

## 当前已有资源

现有角色精灵图在 assets 根目录的资源包中：
- `RPG Top Down Character Asset Pack - FREE/` → 玩家角色
- `Snoblin_Pixel_RPG_Skeleton_Characters_FREE_DEMO/` → 骷髅敌人

后续新增精灵图建议按分类放入此目录的子文件夹中。
