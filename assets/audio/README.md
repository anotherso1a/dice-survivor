# assets/audio/ — 音效与音乐

## 目录职责

存放所有游戏音效和背景音乐。

## 资源分类

| 子类 | 格式 | 说明 |
|------|------|------|
| sfx/ | `.wav` | 短音效（攻击/受伤/拾取/UI 点击） |
| bgm/ | `.ogg` | 背景音乐（战斗/休息站/BOSS/菜单） |

## 开发规范

- **音效**使用 `.wav` 格式（无压缩，延迟低，适合短音效）
- **BGM** 使用 `.ogg` 格式（流式播放，内存占用低）
- 命名：`{category}_{action}.wav`，如 `sfx_hit.wav`、`bgm_battle.ogg`
- 在 Godot 的 Import 设置中，BGM 设置为 Stream（流式），音效设置为 Sample

## 当前状态

暂无音效资源，后续添加。
