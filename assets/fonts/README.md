# assets/fonts/ — 字体资源

## 目录职责

存放游戏中使用的字体文件，主要是像素风格字体。

## 格式支持

| 格式 | 说明 |
|------|------|
| `.ttf` | TrueType 字体 |
| `.otf` | OpenType 字体 |
| `.woff2` | Web 字体格式 |
| `.fnt` + `.png` | Bitmap Font（位图字体） |

## 开发规范

- 像素风格游戏推荐使用 Bitmap Font 或等宽像素字体
- 在 Godot 中使用 `DynamicFont` 或 `BitmapFont` 节点加载
- 字体大小应与精灵图风格匹配（通常 8px / 16px 像素字体）

## 当前状态

暂无字体资源，后续添加。
