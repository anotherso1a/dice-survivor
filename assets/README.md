# assets/ — 美术资源目录

## 目录职责

存放所有美术资源文件，包括精灵图、音效、BGM、字体和 UI 素材。此目录下的资源**仅供引用**，不包含任何逻辑代码。

## 子目录

| 子目录 | 内容 | 格式 |
|--------|------|------|
| `sprites/` | 角色/敌人/特效精灵图 | `.png` / `.webp` |
| `audio/` | 音效和背景音乐 | `.wav`（音效）/ `.ogg`（BGM） |
| `fonts/` | 像素字体 | `.ttf` / `.otf` / `.woff2` |
| `ui/` | UI 素材（按钮/面板/图标） | `.png` / `.svg` |

## 已有资源

| 路径 | 说明 |
|------|------|
| `RPG Top Down Character Asset Pack - FREE/` | 玩家角色精灵图（Blonde Man / Blue Haired Woman） |
| `Snoblin_Pixel_RPG_Skeleton_Characters_FREE_DEMO/` | 骷髅敌人精灵图（walk/idle/death/hurt） |

## 开发方式

### 添加新资源

1. 将资源文件放入对应子目录
2. 在 Godot 编辑器中打开项目，自动生成 `.import` 文件
3. 在场景或脚本中通过 `load("res://assets/...")` 引用

### 资源规范

- 精灵图使用 `.png` 格式，像素风格素材不要压缩（导入设置关闭 Filter）
- 音效使用 `.wav`，BGM 使用 `.ogg`（流式播放，节省内存）
- 命名用 `snake_case`：`skeleton_walk.png`、`fire_hit.wav`
- 精灵图如果是 spritesheet，在 Godot 的 Import 面板中设置为 Texture2D 后用 SpriteFrames 切割

## 注意事项

- 不要在此目录放置 `.gd` 脚本或 `.tscn` 场景
- `.import` 文件由 Godot 自动生成，应加入 `.gitignore`
- 大型资源（音频/视频）考虑使用 Git LFS 管理
