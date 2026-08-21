class_name DungeonPlayer
extends CharacterBody2D

# SPEC: DungeonPlayer はプレイヤー固有の状態だけを持つ。グリッド座標、選択中の
# 移動先、向き、武器ロードアウト、HP、プレイヤースプライト演出が対象。
# SPEC: ダンジョンのターン進行は landed シグナルを起点にする。main.gd がこれを受け、
# 移動完了後にガジェットコードと警察ターンを実行する。
signal landed(cell: Vector2i, previous_cell: Vector2i, forward_dir: Vector2i)

const MOVE_DURATION := 0.14
const ShogiMoveSetScript := preload("res://scripts/movement/shogi_move_set.gd")
const PLAYER_SPRITE_SHEET_PATH := "res://assets/sprites/adventurer_weapon_directions_64.png"
const SPRITE_CELL_SIZE := Vector2i(64, 64)
const PLAYER_SPRITE_DRAW_SIZE := 28.0
const MAX_HP := 5
const DAMAGE_POPUP_DURATION := 0.58
const HIT_FLASH_DURATION := 0.16
# SPEC: スプライトシートの行は武器の見た目を表す。武器IDは下の移動ロードアウトにも
# 使うため、対応するスプライト行がない武器は有効化しない。
const PLAYER_WEAPON_ROWS := {
	"hammer": 0,
	"axe": 1,
	"sword": 2,
}
# SPEC: 武器は移動ルールそのもの。ハンマーは歩、剣は銀、斧は桂馬として開始する。
# 新しい武器はここに追加し、対応するスプライトも用意する。
const WEAPON_LOADOUTS := [
	{"weapon_id": "hammer", "weapon_name": "Hammer", "move_pattern_id": "pawn"},
	{"weapon_id": "sword", "weapon_name": "Sword", "move_pattern_id": "silver"},
	{"weapon_id": "axe", "weapon_name": "Axe", "move_pattern_id": "knight"},
]

var tile_size := 24
var map_data: Dictionary
var grid_cell := Vector2i.ZERO
var selected_cell := Vector2i.ZERO
var forward_dir := Vector2i.UP

# SPEC: legal_moves は現在の将棋移動パターンと一時的なガジェットボーナスから作る
# 整数の移動先セルだけを含む。blocked_cells は生存中の警察マスへの着地を防ぐが、
# プレイヤー自身の現在セルだけは例外。
var move_patterns: Array = []
var move_pattern_index := 0
var loadout_index := 0
var legal_moves: Array[Vector2i] = []
var extra_legal_moves: Array[Vector2i] = []
var blocked_cells: Array[Vector2i] = []
var weapon_id := "hammer"
var player_sprite_sheet: Texture2D
var current_hp := MAX_HP
var damage_popups: Array[Dictionary] = []
var hit_flash_time_left := 0.0

var target_cell := Vector2i.ZERO
var move_start := Vector2.ZERO
var move_end := Vector2.ZERO
var move_elapsed := 0.0
var is_moving := false
var input_locked := false

func setup(data: Dictionary, size: int) -> void:
	# SPEC: setup はダンジョン再生成ごとに呼ばれる。HP、ロードアウト、移動選択、
	# ダメージ演出状態を初期化する。
	map_data = data
	tile_size = size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_player_sprite_sheet()
	move_patterns = ShogiMoveSetScript.create_all()
	_set_weapon_loadout(0, false)
	current_hp = MAX_HP
	damage_popups.clear()
	hit_flash_time_left = 0.0
	grid_cell = Vector2i(data.spawn)
	selected_cell = grid_cell
	position = _cell_to_world(grid_cell)
	_refresh_legal_moves()

func _physics_process(delta: float) -> void:
	if is_moving:
		_update_move(delta)
	_update_damage_feedback(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_move_to(_world_to_cell(get_global_mouse_position()))
		get_viewport().set_input_as_handled()
		return

	if is_moving:
		return

	if event.is_action_pressed("move_left"):
		_select_move_in_direction(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_right"):
		_select_move_in_direction(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up"):
		_select_move_in_direction(Vector2i.UP)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_down"):
		_select_move_in_direction(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("rotate_facing"):
		rotate_facing()
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_Q:
			cycle_weapon_loadout(-1)
			get_viewport().set_input_as_handled()
		KEY_E, KEY_TAB:
			cycle_weapon_loadout(1)
			get_viewport().set_input_as_handled()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			request_move_to(selected_cell)
			get_viewport().set_input_as_handled()

func request_move_to(destination: Vector2i) -> bool:
	# SPEC: 移動は事前計算済みの合法な整数セルに対してのみ開始する。自由なピクセル移動を
	# ゲーム状態に入れない。
	if input_locked or not is_alive() or is_moving or not legal_moves.has(destination):
		return false
	target_cell = destination
	selected_cell = destination
	move_start = position
	move_end = _cell_to_world(target_cell)
	move_elapsed = 0.0
	is_moving = true
	return true

func cycle_weapon_loadout(delta: int) -> void:
	if move_patterns.is_empty() or WEAPON_LOADOUTS.is_empty():
		return
	_set_weapon_loadout(posmod(loadout_index + delta, WEAPON_LOADOUTS.size()))

func rotate_facing() -> void:
	# SPEC: Rキーはローカルな将棋盤を時計回りに回す。移動オフセットは新しい向きに
	# 対して再計算する。
	forward_dir = Vector2i(-forward_dir.y, forward_dir.x)
	_refresh_legal_moves()

func set_move_pattern_by_id(piece_id: String) -> bool:
	for i in range(WEAPON_LOADOUTS.size()):
		if WEAPON_LOADOUTS[i].move_pattern_id == piece_id:
			_set_weapon_loadout(i)
			return true
	return false

func set_weapon_sprite(next_weapon_id: String) -> bool:
	for i in range(WEAPON_LOADOUTS.size()):
		if WEAPON_LOADOUTS[i].weapon_id == next_weapon_id:
			_set_weapon_loadout(i)
			return true
	return false

func get_current_move_pattern():
	return move_patterns[move_pattern_index]

func get_current_move_name() -> String:
	return "%s / %s" % [WEAPON_LOADOUTS[loadout_index].weapon_name, get_current_move_pattern().display_name]

func get_current_move_short_name() -> String:
	return get_current_move_pattern().short_name

func get_move_pattern_index() -> int:
	return loadout_index

func get_move_pattern_count() -> int:
	return WEAPON_LOADOUTS.size()

func get_legal_moves() -> Array[Vector2i]:
	return legal_moves

func set_extra_legal_moves(cells: Array[Vector2i]) -> void:
	var next_moves := _normalize_move_list(cells)
	if _move_lists_equal(extra_legal_moves, next_moves):
		return
	extra_legal_moves = next_moves
	_refresh_legal_moves()

func set_blocked_cells(cells: Array[Vector2i]) -> void:
	var next_cells := _normalize_move_list(cells)
	if _move_lists_equal(blocked_cells, next_cells):
		return
	blocked_cells = next_cells
	_refresh_legal_moves()

func set_input_locked(locked: bool) -> void:
	input_locked = locked

func get_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return MAX_HP

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> bool:
	# SPEC: プレイヤーHPは整数で管理する。戻り値 true は HP が 0 になり、
	# 入力ロックを維持すべき状態を表す。
	var applied := mini(maxi(amount, 0), current_hp)
	current_hp = maxi(current_hp - applied, 0)
	if applied > 0:
		damage_popups.append({
			"amount": applied,
			"time_left": DAMAGE_POPUP_DURATION,
			"duration": DAMAGE_POPUP_DURATION,
			"phase": damage_popups.size() * 1.9 + Time.get_ticks_msec() * 0.001,
		})
		hit_flash_time_left = HIT_FLASH_DURATION
	if current_hp <= 0:
		input_locked = true
	queue_redraw()
	return current_hp <= 0

func get_selected_cell() -> Vector2i:
	return selected_cell

func get_grid_cell() -> Vector2i:
	return grid_cell

func get_forward_dir() -> Vector2i:
	return forward_dir

func get_facing_label() -> String:
	match forward_dir:
		Vector2i.UP:
			return "North"
		Vector2i.RIGHT:
			return "East"
		Vector2i.DOWN:
			return "South"
		Vector2i.LEFT:
			return "West"
		_:
			return "Unknown"

func _update_move(delta: float) -> void:
	move_elapsed += delta
	var t := minf(move_elapsed / MOVE_DURATION, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	position = move_start.lerp(move_end, eased)
	if t >= 1.0:
		# SPEC: grid_cell は移動アニメーションが着地した瞬間だけ更新する。効果、警察との
		# 衝突、コード実行を最終セルに揃えるため。
		var previous_cell := grid_cell
		position = move_end
		grid_cell = target_cell
		is_moving = false
		_refresh_legal_moves()
		landed.emit(grid_cell, previous_cell, forward_dir)

func _update_damage_feedback(delta: float) -> void:
	hit_flash_time_left = maxf(hit_flash_time_left - delta, 0.0)
	for i in range(damage_popups.size() - 1, -1, -1):
		damage_popups[i].time_left -= delta
		if damage_popups[i].time_left <= 0.0:
			damage_popups.remove_at(i)

func _select_move_in_direction(direction: Vector2i) -> void:
	if legal_moves.is_empty():
		return

	# SPEC: WASD/矢印の選択は、まず現在選択中のセルからその方向にある最寄りの
	# 合法セルを選ぶ。見つからなければプレイヤー位置を基準に選び直す。
	var anchor := selected_cell if legal_moves.has(selected_cell) else grid_cell
	var candidates := _find_candidates_from_anchor(anchor, direction)
	if candidates.is_empty() and anchor != grid_cell:
		candidates = _find_candidates_from_anchor(grid_cell, direction)

	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _is_better_selection_candidate(a, b, anchor, direction)
	)

	selected_cell = candidates[0]

func _find_candidates_from_anchor(anchor: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for destination in legal_moves:
		var offset := destination - anchor
		if offset == Vector2i.ZERO:
			continue
		if _projection(offset, direction) > 0:
			candidates.append(destination)
	return candidates

func _is_better_selection_candidate(a: Vector2i, b: Vector2i, anchor: Vector2i, direction: Vector2i) -> bool:
	var offset_a := a - anchor
	var offset_b := b - anchor
	var perpendicular_a := _perpendicular_distance(offset_a, direction)
	var perpendicular_b := _perpendicular_distance(offset_b, direction)
	if perpendicular_a != perpendicular_b:
		return perpendicular_a < perpendicular_b

	var projection_a := _projection(offset_a, direction)
	var projection_b := _projection(offset_b, direction)
	if projection_a != projection_b:
		return projection_a < projection_b

	var distance_a: int = absi(offset_a.x) + absi(offset_a.y)
	var distance_b: int = absi(offset_b.x) + absi(offset_b.y)
	if distance_a != distance_b:
		return distance_a < distance_b

	var origin_distance_a := _distance_from_origin(a)
	var origin_distance_b := _distance_from_origin(b)
	if origin_distance_a != origin_distance_b:
		return origin_distance_a < origin_distance_b

	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x

func _projection(offset: Vector2i, direction: Vector2i) -> int:
	return offset.x * direction.x + offset.y * direction.y

func _perpendicular_distance(offset: Vector2i, direction: Vector2i) -> int:
	return absi(offset.x * direction.y - offset.y * direction.x)

func _direction_from_origin(destination: Vector2i) -> Vector2i:
	var delta := destination - grid_cell
	return Vector2i(signi(delta.x), signi(delta.y))

func _distance_from_origin(destination: Vector2i) -> int:
	var delta := destination - grid_cell
	return maxi(absi(delta.x), absi(delta.y))

func _refresh_legal_moves() -> void:
	if map_data.is_empty() or move_patterns.is_empty():
		legal_moves.clear()
		selected_cell = grid_cell
		return

	# SPEC: 現在の武器移動は ShogiMovePattern に委譲する。追加の合法移動は
	# wall move などのガジェット効果から来る。
	legal_moves = get_current_move_pattern().get_destinations(grid_cell, Callable(self, "_can_stand_on"), forward_dir)
	for cell in extra_legal_moves:
		if _can_stand_on(cell) and not legal_moves.has(cell):
			legal_moves.append(cell)
	legal_moves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a := _distance_from_origin(a)
		var distance_b := _distance_from_origin(b)
		if distance_a != distance_b:
			return distance_a < distance_b
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	var forward_cell := grid_cell + forward_dir
	if legal_moves.has(forward_cell):
		selected_cell = forward_cell
	else:
		selected_cell = legal_moves[0] if not legal_moves.is_empty() else grid_cell

func _can_stand_on(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_data.width or cell.y >= map_data.height:
		return false
	if cell != grid_cell and blocked_cells.has(cell):
		return false
	return map_data.cells[cell.y * map_data.width + cell.x] != DungeonGenerator.WALL

func _normalize_move_list(cells: Array[Vector2i]) -> Array[Vector2i]:
	var normalized: Array[Vector2i] = []
	for cell in cells:
		if not normalized.has(cell):
			normalized.append(cell)
	normalized.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return normalized

func _move_lists_equal(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func _set_weapon_loadout(next_index: int, refresh_moves := true) -> void:
	loadout_index = posmod(next_index, WEAPON_LOADOUTS.size())
	var loadout: Dictionary = WEAPON_LOADOUTS[loadout_index]
	weapon_id = loadout.weapon_id

	for i in range(move_patterns.size()):
		if move_patterns[i].piece_id == loadout.move_pattern_id:
			move_pattern_index = i
			break

	if refresh_moves:
		_refresh_legal_moves()
	queue_redraw()

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * tile_size + Vector2.ONE * tile_size * 0.5

func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floor(world_position.x / tile_size), floor(world_position.y / tile_size))

func _draw() -> void:
	if player_sprite_sheet == null:
		_draw_fallback_marker()
		_draw_damage_popups()
		return
	var destination := Rect2(Vector2.ONE * PLAYER_SPRITE_DRAW_SIZE * -0.5, Vector2.ONE * PLAYER_SPRITE_DRAW_SIZE)
	# SPEC: 64px の元絵を 28px 正方形に描画する。24px タイルに収めつつ、
	# 視認性のために少しだけはみ出す設計。
	draw_texture_rect_region(player_sprite_sheet, destination, _get_sprite_region(), _get_hit_modulate())
	_draw_damage_popups()

func _load_player_sprite_sheet() -> void:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(PLAYER_SPRITE_SHEET_PATH))
	if error != OK:
		push_warning("Failed to load player sprite sheet: %s" % PLAYER_SPRITE_SHEET_PATH)
		return
	player_sprite_sheet = ImageTexture.create_from_image(image)

func _draw_fallback_marker() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color("80c9ff"))
	draw_line(Vector2.ZERO, Vector2(forward_dir) * 15.0, Color("ffe082"), 3.0)

func _draw_damage_popups() -> void:
	for popup in damage_popups:
		var duration: float = popup.duration
		var progress := 1.0 - clampf(float(popup.time_left) / duration, 0.0, 1.0)
		var alpha := clampf(float(popup.time_left) / duration, 0.0, 1.0)
		var text := "-%d" % int(popup.amount)
		var jitter := sin(progress * TAU * 2.2 + float(popup.phase)) * 2.0
		var pos := Vector2(-18.0 + jitter, -25.0 - progress * 15.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 13, Color(0.0, 0.0, 0.0, alpha * 0.88))
		draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 13, Color(1.0, 0.26, 0.20, alpha))

func _get_hit_modulate() -> Color:
	if hit_flash_time_left <= 0.0:
		return Color(1.0, 1.0, 1.0, 1.0)
	var fade := hit_flash_time_left / HIT_FLASH_DURATION
	var pulse := 0.48 + sin(fade * TAU * 2.0) * 0.14
	return Color(1.0, 1.0, 1.0, 1.0).lerp(Color("ff6d5a"), clampf(pulse, 0.0, 0.75))

func _get_sprite_region() -> Rect2:
	var column := _get_facing_column()
	var row: int = PLAYER_WEAPON_ROWS[weapon_id]
	return Rect2(
		Vector2(column * SPRITE_CELL_SIZE.x, row * SPRITE_CELL_SIZE.y),
		Vector2(SPRITE_CELL_SIZE)
	)

func _get_facing_column() -> int:
	match forward_dir:
		Vector2i.UP:
			return 0
		Vector2i.RIGHT:
			return 1
		Vector2i.DOWN:
			return 2
		Vector2i.LEFT:
			return 3
		_:
			return 0
