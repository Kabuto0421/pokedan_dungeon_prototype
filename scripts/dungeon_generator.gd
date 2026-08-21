class_name DungeonGenerator
extends RefCounted

# SPEC: DungeonGenerator は main.gd が読む自己完結した Dictionary を作る。
# ノードの生成は担当しない。
# SPEC: セル値は整数の地形ID。WALL は移動と効果を止める。FLOOR は通常の歩行可能床。
# FACILITY は歩行可能な特殊部屋で、現時点では見た目の差だけに使う。
const WALL := 0
const FLOOR := 1
const FACILITY := 2
# SPEC: 現在のプロトタイプでは警察密度を意図的に高くする。複雑な敵種を増やさず、
# すぐ戦闘圧を出すため。
const POLICE_MIN_COUNT := 30
const POLICE_MAX_COUNT := 44
const POLICE_MIN_DISTANCE_FROM_SPAWN := 10

var width := 92
var height := 66
var cells: PackedInt32Array
var rooms: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func generate() -> Dictionary:
	rng.randomize()
	cells.resize(width * height)
	cells.fill(WALL)
	rooms.clear()
	# SPEC: 部屋生成は、読みやすい間隔を保った中規模部屋を多めに作る方針。
	var attempts := 220
	while attempts > 0 and rooms.size() < 22:
		attempts -= 1
		var size := Vector2i(rng.randi_range(7, 14), rng.randi_range(6, 11))
		var rect := Rect2i(rng.randi_range(3, width - size.x - 4), rng.randi_range(3, height - size.y - 4), size.x, size.y)
		if _overlaps_existing(rect.grow(2)):
			continue
		var facility := rng.randf() < 0.12 and rooms.size() > 3
		rooms.append({"rect": rect, "center": rect.get_center(), "type": "facility" if facility else "ruins"})
		_carve_room(rect, FACILITY if facility else FLOOR)

	rooms.sort_custom(func(a, b): return a.center.x < b.center.x)
	for i in range(1, rooms.size()):
		_carve_corridor(rooms[i - 1].center, rooms[i].center)
		# SPEC: 追加通路でループを作り、行き止まりの往復を減らす。
	for i in range(maxi(2, rooms.size() / 3)):
		var a: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		var b: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		if a != b and Vector2(a.center).distance_to(Vector2(b.center)) < 36.0:
			_carve_corridor(a.center, b.center)

	var player_spawn: Vector2i = rooms[0].center
	var police_spawns := _generate_police_spawns(player_spawn)
	return {
		"width": width,
		"height": height,
		"cells": cells,
		"rooms": rooms,
		"spawn": player_spawn,
		"police_spawns": police_spawns,
	}

func _overlaps_existing(rect: Rect2i) -> bool:
	for room in rooms:
		if rect.intersects(room.rect):
			return true
	return false

func _carve_room(rect: Rect2i, kind: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
				# SPEC: ruins 部屋は角を少し崩す。facility 部屋は長方形を保つ。
			if kind == FLOOR and ((x in [rect.position.x, rect.end.x - 1]) and (y in [rect.position.y, rect.end.y - 1])) and rng.randf() < 0.75:
				continue
			set_cell(Vector2i(x, y), kind)

func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var horizontal_first := rng.randf() < 0.5
	var corner := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
	_carve_line_3_wide(a, corner)
	_carve_line_3_wide(corner, b)

func _carve_line_3_wide(a: Vector2i, b: Vector2i) -> void:
	var p := a
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	while p != b:
		_carve_brush(p)
		p += step
	_carve_brush(b)

func _carve_brush(p: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var q := p + Vector2i(ox, oy)
			if q.x > 0 and q.y > 0 and q.x < width - 1 and q.y < height - 1:
				if get_cell(q) == WALL:
					set_cell(q, FLOOR)

func get_cell(p: Vector2i) -> int:
	return cells[p.y * width + p.x]

func set_cell(p: Vector2i, value: int) -> void:
	cells[p.y * width + p.x] = value

func _generate_police_spawns(player_spawn: Vector2i) -> Array[Vector2i]:
	var spawns: Array[Vector2i] = []
	# SPEC: 最初の部屋はプレイヤー用。警察はそれ以降の部屋、またはスポーンから
	# 十分離れた床セルに配置する。
	for room_index in range(1, rooms.size()):
		if spawns.size() >= POLICE_MAX_COUNT:
			break
		var room: Dictionary = rooms[room_index]
		var rect: Rect2i = room.rect.grow(-1)
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue

		var room_area := rect.size.x * rect.size.y
		var count := clampi(room_area / 36, 1, 3)
		if room.type == "facility":
			count += 1
		if rng.randf() < 0.35:
			count += 1

		var attempts := count * 18
		while count > 0 and attempts > 0 and spawns.size() < POLICE_MAX_COUNT:
			attempts -= 1
			var cell := Vector2i(
				rng.randi_range(rect.position.x, rect.end.x - 1),
				rng.randi_range(rect.position.y, rect.end.y - 1)
			)
			if not _is_police_spawn_candidate(cell, player_spawn, spawns):
				continue
			spawns.append(cell)
			count -= 1
	_fill_minimum_police_spawns(player_spawn, spawns)
	return spawns

func _fill_minimum_police_spawns(player_spawn: Vector2i, spawns: Array[Vector2i]) -> void:
	if spawns.size() >= POLICE_MIN_COUNT:
		return

	# SPEC: 最低配置数は必ず満たす。部屋ベースの配置で足りない場合は、
	# スポーン距離を守りつつ有効な歩行可能セルから補充する。
	var candidates: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, y)
			if _is_police_spawn_candidate(cell, player_spawn, spawns):
				candidates.append(cell)
	candidates.shuffle()

	for cell in candidates:
		if spawns.size() >= POLICE_MIN_COUNT or spawns.size() >= POLICE_MAX_COUNT:
			return
		if not _is_police_spawn_candidate(cell, player_spawn, spawns):
			continue
		spawns.append(cell)

func _is_police_spawn_candidate(cell: Vector2i, player_spawn: Vector2i, spawns: Array[Vector2i]) -> bool:
	if cell.x <= 0 or cell.y <= 0 or cell.x >= width - 1 or cell.y >= height - 1:
		return false
	if get_cell(cell) == WALL:
		return false
	if _manhattan_distance(cell, player_spawn) < POLICE_MIN_DISTANCE_FROM_SPAWN:
		return false
	return not spawns.has(cell)

func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
