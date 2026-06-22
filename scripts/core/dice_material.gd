## 骰子材质资源（纯数据，无逻辑）
##
## 定义骰体的视觉风格：骰面底色、点数图案样式、稀有度、光效/粒子。
## 每个材质保存为独立的 .tres 文件，在编辑器中可直接创建和编辑。
##
## 用法：
##   1. 在编辑器中：右键 → 新建资源 → DiceMaterial
##   2. 配置材质属性后保存为 .tres
##   3. 在 DiceData 的 dice_material 字段中拖入此资源
##
@tool
class_name DiceMaterial
extends Resource


## 点数绘制样式（决定骰面上"点"的形状）
enum PipStyle {
	CLASSIC,   ## 经典圆点（标准/灌铅骰子）
	FROST,    ## 雪花（冰霜骰子）
	FLAME,    ## 火苗（火焰骰子）
	GLASS,    ## 菱形水晶（玻璃骰子）
	LEAD,     ## 实心圆点（灌铅骰子，更沉重感）
	CURSED,   ## 骷髅/十字（诅咒骰子）
	MOUNTAIN, ## 三角岩块（山岳骰子 — 范围攻击）
}


## ========== 身份 ==========
@export_group("Identity")
## 材质名称（用于调试和 UI 显示）
@export var material_name: String = "标准"
## 点数样式
@export var pip_style: PipStyle = PipStyle.CLASSIC
## 稀有度：影响光效强度和粒子密度
@export_enum("common", "rare", "epic") var rarity: String = "common"


## ========== 骰面外观 ==========
@export_group("Face Appearance")
## 骰面底色
@export var base_color: Color = Color(0.20, 0.20, 0.25, 1.0)
## 骰面边框色
@export var border_color: Color = Color(0.50, 0.50, 0.55, 1.0)
## 高光颜色（光影效果用）
@export var highlight_color: Color = Color(0.35, 0.35, 0.40, 1.0)
## 阴影颜色（光影效果用）
@export var shadow_color: Color = Color(0.10, 0.10, 0.15, 1.0)


## ========== 点数外观 ==========
@export_group("Pip Appearance")
## 点数主色
@export var pip_color: Color = Color(0.92, 0.92, 0.95, 1.0)
## 暴击时点数颜色
@export var crit_pip_color: Color = Color(1.0, 0.85, 0.10, 1.0)


## ========== 特效 ==========
@export_group("VFX")
## 光效着色器（可选；rare/epic 骰子可挂一个 CanvasItem shader）
@export var glow_shader: Shader = null
## 粒子场景（可选；挂载到 DiceEntity 上）
@export var particle_scene: PackedScene = null
## 骰子本体缩放（稀有骰子可以稍大）
@export_range(0.5, 2.0) var scale_modifier: float = 1.0


func _init(
	p_material_name: String = "标准",
	p_pip_style: PipStyle = PipStyle.CLASSIC,
	p_base_color: Color = Color(0.20, 0.20, 0.25),
	p_rarity: String = "common",
) -> void:
	material_name = p_material_name
	pip_style = p_pip_style
	base_color = p_base_color
	rarity = p_rarity

	# 根据样式自动设置默认颜色
	match pip_style:
		PipStyle.CLASSIC:
			pip_color = Color(0.92, 0.92, 0.95)
			crit_pip_color = Color(1.0, 0.85, 0.10)
		PipStyle.FROST:
			pip_color = Color(0.60, 0.90, 1.0)
			crit_pip_color = Color(0.90, 0.98, 1.0)
			highlight_color = Color(0.50, 0.70, 0.90)
			border_color = Color(0.40, 0.70, 1.0)
		PipStyle.FLAME:
			pip_color = Color(1.0, 0.60, 0.15)
			crit_pip_color = Color(1.0, 0.95, 0.30)
			highlight_color = Color(0.80, 0.30, 0.10)
			border_color = Color(1.0, 0.40, 0.10)
		PipStyle.GLASS:
			pip_color = Color(0.70, 0.85, 1.0)
			crit_pip_color = Color(1.0, 1.0, 1.0)
			highlight_color = Color(0.80, 0.90, 1.0)
			border_color = Color(0.50, 0.70, 0.90)
		PipStyle.LEAD:
			pip_color = Color(0.55, 0.55, 0.60)
			crit_pip_color = Color(0.90, 0.85, 0.10)
			highlight_color = Color(0.40, 0.40, 0.45)
			border_color = Color(0.35, 0.35, 0.40)
		PipStyle.CURSED:
			pip_color = Color(0.70, 0.25, 0.25)
			crit_pip_color = Color(1.0, 0.30, 0.30)
			highlight_color = Color(0.30, 0.15, 0.15)
			border_color = Color(0.60, 0.20, 0.20)
		PipStyle.MOUNTAIN:
			pip_color = Color(0.55, 0.45, 0.30)
			crit_pip_color = Color(1.0, 0.70, 0.15)
			highlight_color = Color(0.45, 0.35, 0.25)
			border_color = Color(0.35, 0.25, 0.15)
