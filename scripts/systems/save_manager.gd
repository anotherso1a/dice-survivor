## 存档管理器（Autoload / Singleton）
##
## 本脚本在 project.godot 中注册为 Autoload，整个游戏生命周期只存在一个实例，
## 任何地方都能通过 SaveManager.xxx 直接访问。
##
## 负责：
##   1. 持久化存档（user:// 路径下的 save.json）
##   2. 设置持久化
##   3. 解锁内容记录（骰子图鉴、遗物图鉴等）
##
## MVP 阶段为骨架，后续 M5 实现。
##
extends Node  # 继承 Node 基类；作为 Autoload 挂载到场景树根节点下


const SAVE_PATH: String = "user://save.json"  # 常量：存档文件路径。
# user:// 是 Godot 特殊路径，指向操作系统用户数据目录（如 ~/.local/share/godot/appname/ 或 AppData/），
# 区别于 res://（只读的游戏资源目录）。存档文件必须放在 user:// 下才能写入。


## 保存游戏（当前仅保存设置和解锁记录）
func save() -> void:
	## TODO M5
	pass  # 占位：MVP 阶段暂不实现存档保存逻辑，pass 保证函数体不为空


## 读取存档
func load_save() -> Dictionary:  # 返回 Dictionary 类型：存档数据的字典结构
	## TODO M5
	return {}  # 占位：MVP 阶段返回空字典，表示无存档数据


## 重置存档（新游戏）
func reset_save() -> void:
	## TODO M5
	pass  # 占位：MVP 阶段暂不实现存档重置逻辑
