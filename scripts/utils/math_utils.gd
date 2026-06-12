## 数学工具函数脚本
##
## 本脚本提供游戏中常用的数学运算工具函数，所有函数均为 static（静态），
## 无需实例化即可通过 MathUtils.function_name() 直接调用。
## 脚本本身不保存任何状态（无成员变量），是纯函数式工具类。
## 继承 RefCounted 而非 Node，因此不能作为节点添加到场景树，
## 但可以作为资源被任意脚本引用，开销极低。
##
extends RefCounted  # 继承 RefCounted，作为无状态工具类，不能被添加到场景树


## 在矩形区域内随机取一个点，可选择避开中心区域（用于敌人出生点）
##   margin:       距矩形四边的内缩距离，防止点太靠近边缘
##   w:            矩形宽度（像素）
##   h:            矩形高度（像素）
##   avoid_center: 是否避开中心区域，True 时会在中心圆形范围外取点
##   center:       中心点的位置（Vector2），avoid_center 为 True 时有效
##   center_radius: 中心避开半径（像素），中心点周围此范围内不会取点
## 返回值：一个 Vector2，表示随机选取的位置
static func random_in_rect(  # static 关键字：无需实例化即可调用，等同于其他语言的静态方法
	margin: float,  # 距四边的内缩距离参数
	w: float,  # 矩形区域宽度
	h: float,  # 矩形区域高度
	avoid_center: bool = false,  # 是否避开中心区域，默认不避开
	center: Vector2 = Vector2.ZERO,  # 中心点坐标，默认世界原点
	center_radius: float = 0.0,  # 中心避开半径，默认 0（不避开）
) -> Vector2:  # 函数返回类型为 Vector2（二维向量，表示 x/y 坐标）
	var pos: Vector2 = Vector2.ZERO  # 声明 pos 变量，初始化为零向量，用于存储最终选取的点
	if not avoid_center:  # 如果调用者不要求避开中心区域
		# 直接在矩形范围内随机取一个点并返回，randf_range(a,b) 返回 [a,b) 之间的随机浮点数
		return Vector2(  # 构造并返回一个 Vector2 作为结果
			randf_range(margin, w - margin),  # x 坐标：在 [margin, w-margin] 范围内随机
			randf_range(margin, h - margin),  # y 坐标：在 [margin, h-margin] 范围内随机
		)

	# 如果需要避开中心区域，则进入重试循环，最多尝试 50 次
	for _attempt in range(50):  # range(50) 生成 0~49 的序列，_attempt 前缀 _ 表示未使用
		# 在矩形范围内随机取一个点
		pos = Vector2(  # 将随机生成的坐标赋值给 pos
			randf_range(margin, w - margin),  # x 坐标随机
			randf_range(margin, h - margin),  # y 坐标随机
		)
		# distance_to() 计算两个 Vector2 之间的欧几里得距离
		# 如果当前点到中心的距离 >= 避开半径，说明点在安全区域外，接受此点
		if pos.distance_to(center) >= center_radius:  # 点距中心足够远，符合要求
			return pos  # 返回符合条件的点，结束函数
	# 如果 50 次尝试后仍未找到符合条件的点（中心区域太大或矩形太小），返回最后一次生成的点
	return pos  # 降级方案：返回最后生成的点（可能在中心区域内）


## 在圆形范围内均匀随机取一个点
## 使用"开方均匀分布"算法保证点在圆内均匀分布（而非聚集在圆心附近）
##   center: 圆心坐标（Vector2）
##   radius: 圆的半径（像素）
## 返回值：圆内的一个随机 Vector2 坐标
static func random_in_circle(center: Vector2, radius: float) -> Vector2:  # 静态函数，在圆内随机取点
	var angle: float = randf() * TAU  # TAU = 2*PI ≈ 6.283，随机生成一个 [0, 2π) 的角度
	# 关键数学原理：直接在 [0,radius] 均匀取 r 会导致点聚集在圆心
	# 必须对 r 取平方根（sqrt(randf())）才能保证圆内均匀分布
	var r: float = sqrt(randf()) * radius  # 取平方根随机半径，保证圆内均匀分布
	# 极坐标转直角坐标：x = cos(angle) * r, y = sin(angle) * r
	return center + Vector2(cos(angle) * r, sin(angle) * r)  # 返回圆心偏移后的最终坐标


## 从数组中按权重随机选取一个元素（加权随机/轮盘赌算法）
## 常用于：按稀有度抽卡、按概率选敌人类型、随机选择掉落物等
##   items:   Array[Variant] — 候选元素数组，可以是任意类型
##   weights: Array[float] — 对应每个元素的权重，权重越高被选中的概率越大
## 返回值：选中的一个元素（Variant 类型，可以是任意 Godot 数据类型）
## 注意：items 和 weights 的长度必须一致，否则会 push_error 并返回 null
static func weighted_random(items: Array, weights: Array) -> Variant:  # 加权随机选取，返回任意类型
	# 防御性检查：数组为空或长度不一致时，输出错误并返回 null，避免崩溃
	if items.is_empty() or weights.is_empty() or items.size() != weights.size():  # 参数合法性检查
		push_error("MathUtils.weighted_random: items 和 weights 长度不一致或为空")  # 向控制台输出错误信息
		return null  # 返回 null，调用方应处理此返回值
	var total: float = 0.0  # 总权重累加器，用于计算权重总和
	for w in weights:  # 遍历权重数组，计算所有权重之和
		total += float(w)  # 将每个权重转为 float 并累加到 total
	# randf() 返回 [0,1) 的随机浮点数，乘以 total 得到 [0, total) 的随机数
	var r: float = randf() * total  # 生成一个 [0, total) 范围内的随机浮点数
	var cumulative: float = 0.0  # 累积权重计数器，用于遍历时判断随机数落在哪个区间
	# 遍历所有候选元素，找到随机数所在的权重区间
	for i in items.size():  # i 从 0 到 items.size()-1，逐个检查
		cumulative += float(weights[i])  # 将第 i 个元素的权重累加到累积器
		# 当累积权重超过随机数 r 时，说明 r 落在当前元素的权重区间内
		if r <= cumulative:  # 随机数落在当前元素的权重区间内
			return items[i]  # 返回当前元素，加权随机选择完成
	# 理论上不会执行到这里（除非浮点精度问题），作为保险返回最后一个元素
	return items[-1]  # 降级：返回数组最后一个元素（索引 -1 表示倒数第一个）
