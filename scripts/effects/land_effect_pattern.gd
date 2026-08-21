class_name LandEffectPattern
extends RefCounted

# SPEC: LandEffectPattern は target 命令を属性接続アトラス用の描画セルへ変換する。
# ダメージ処理は行わず、main.gd がダメージを決める。
# SPEC: 各グループの最初のセルが見た目上の始点。front/side/around は行動者から
# 1マス離れた場所を始点にし、行動者セル内ではなく、最初の効果セルの行動者寄りに
# エフェクト中心が来るようにする。
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8
# SPEC: アトラス列 0-15 は接続マスク。ORIGIN_COLUMN は始点セルに重ね描きし、
# 波の開始位置を強調する。
const ORIGIN_COLUMN := 16

# SPEC: 属性行の順番は assets/sprites/effects/element_connection_atlas_manifest.json と
# element_connection_atlas_24.png に合わせる。
const ELEMENT_ROWS := {
	"normal": 0,
	"fire": 1,
	"ice": 2,
	"lightning": 3,
	"poison": 4,
}

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

static func build_cells(
	player_cell: Vector2i,
	forward_dir: Vector2i,
	target: String,
	amount: int,
	can_affect_cell: Callable = Callable()
) -> Array[Dictionary]:
	# SPEC: 戻り値の辞書は cell、mask、origin を持つ。描画側は mask で接続タイルを選び、
	# origin で始点オーバーレイを描く。
	var groups := _build_groups(player_cell, forward_dir, target, maxi(amount, 1), can_affect_cell)
	var occupied := {}
	var origins := {}

	for group in groups:
		if group.is_empty():
			continue
		origins[group[0]] = true
		for cell in group:
			occupied[cell] = true

	var cells: Array[Dictionary] = []
	for cell in occupied.keys():
		cells.append({
			"cell": cell,
			"mask": _connection_mask(cell, occupied),
			"origin": origins.has(cell),
		})

	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cell_a: Vector2i = a.cell
		var cell_b: Vector2i = b.cell
		if cell_a.y != cell_b.y:
			return cell_a.y < cell_b.y
		return cell_a.x < cell_b.x
	)
	return cells

static func build_from_cells(cells: Array[Vector2i], origin_cells: Array[Vector2i] = []) -> Array[Dictionary]:
	var occupied := {}
	var origins := {}

	for cell in cells:
		occupied[cell] = true
	for cell in origin_cells:
		origins[cell] = true

	var render_cells: Array[Dictionary] = []
	for cell in occupied.keys():
		render_cells.append({
			"cell": cell,
			"mask": _connection_mask(cell, occupied),
			"origin": origins.has(cell),
		})

	render_cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cell_a: Vector2i = a.cell
		var cell_b: Vector2i = b.cell
		if cell_a.y != cell_b.y:
			return cell_a.y < cell_b.y
		return cell_a.x < cell_b.x
	)
	return render_cells

static func get_element_row(element: String) -> int:
	return int(ELEMENT_ROWS.get(element, ELEMENT_ROWS.normal))

static func _build_groups(
	player_cell: Vector2i,
	forward_dir: Vector2i,
	target: String,
	amount: int,
	can_affect_cell: Callable
) -> Array[Array]:
	# SPEC: target 名は Editor DSL の一部。GadgetEditor.TARGETS とコード辞書に
	# 必ず同期させる。
	match target:
		"front":
			return [_build_line(player_cell + forward_dir, forward_dir, amount, can_affect_cell)]
		"side":
			var left_dir := Vector2i(forward_dir.y, -forward_dir.x)
			var right_dir := Vector2i(-forward_dir.y, forward_dir.x)
			return [
				_build_line(player_cell + left_dir, left_dir, amount, can_affect_cell),
				_build_line(player_cell + right_dir, right_dir, amount, can_affect_cell),
			]
		"around":
			var groups: Array[Array] = []
			for direction in CARDINAL_DIRECTIONS:
				groups.append(_build_line(player_cell + direction, direction, amount, can_affect_cell))
			return groups
		_:
			return []

static func _build_line(start: Vector2i, direction: Vector2i, amount: int, can_affect_cell: Callable) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for step in range(amount):
		var cell := start + direction * step
		# SPEC: 効果は最初の遮蔽セルで止まる。奥が床でも壁を貫通しない。
		if not _can_affect(cell, can_affect_cell):
			break
		cells.append(cell)
	return cells

static func _can_affect(cell: Vector2i, can_affect_cell: Callable) -> bool:
	if can_affect_cell.is_null():
		return true
	return bool(can_affect_cell.call(cell))

static func _connection_mask(cell: Vector2i, occupied: Dictionary) -> int:
	# SPEC: 隣接ビットがアトラス列番号になる。これにより、1枚の正方形タイルシートから
	# 直線や十字の接続表現を描ける。
	var mask := 0
	if occupied.has(cell + Vector2i.UP):
		mask |= UP
	if occupied.has(cell + Vector2i.RIGHT):
		mask |= RIGHT
	if occupied.has(cell + Vector2i.DOWN):
		mask |= DOWN
	if occupied.has(cell + Vector2i.LEFT):
		mask |= LEFT
	return mask
