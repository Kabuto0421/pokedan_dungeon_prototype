extends Node2D

# SPEC: main.tscn はプレイ中のダンジョンループを管理する。階層生成、
# プレイヤーと警察の生成、保存済みガジェットコードの実行、個別ノードに
# 属さない戦闘フィードバックの描画をここで扱う。
# SPEC: ゲーム上の位置はすべて整数グリッド座標で扱う。描画時だけ TILE で
# ピクセル座標へ変換し、ゲームロジックはピクセル位置に依存させない。
# SPEC: ターン順は「プレイヤーの1手を解決 -> 該当するガジェット行を実行 ->
# 画面付近の警察が行動 -> 短い待ち時間後にプレイヤー入力を解放」。
# 移動なら move/land/wall、F攻撃なら attack が1手になる。
const LandEffectPatternScript := preload("res://scripts/effects/land_effect_pattern.gd")
const PoliceEnemyScript := preload("res://scripts/enemies/police_enemy.gd")

const TILE := 24
const CAMERA_ZOOM := 1.8
const LAND_EFFECT_TEXTURE_PATH := "res://assets/sprites/effects/element_connection_atlas_24.png"
const LAND_EFFECT_DURATION := 0.85
const POLICE_TURN_LOCK_DURATION := 0.18
const POLICE_VISIBILITY_MARGIN := 16.0
# SPEC: 警察HPは 0.5 HP を扱うために半HP単位で管理する。land/move/wall は
# 0.5 HP、基本攻撃は 1 HP を与える。プレイヤーHPは整数で管理する。
const DAMAGE_UNIT := 2
const PLAYER_ATTACK_DAMAGE_UNITS := DAMAGE_UNIT
const PLAYER_LAND_DAMAGE_UNITS := 1
const PLAYER_MOVE_DAMAGE_UNITS := 1
const PLAYER_WALL_DAMAGE_UNITS := 1
const POLICE_ATTACK_DAMAGE := 1
# SPEC: ヒット演出は意図的に短くする。1手の結果を即座に読ませつつ、
# ターン制のテンポを落とさないための値。
const IMPACT_FLASH_DURATION := 0.22
const COMBAT_POPUP_DURATION := 0.62
const CAMERA_SHAKE_DURATION := 0.16
const HIT_STOP_DURATION := 0.06
const HIT_STOP_TIME_SCALE := 0.14
const EXECUTION_LOG_DURATION := 1.7
const EXECUTION_LOG_MAX := 4
# SPEC: DEFAULT_PROGRAM_LINES は editor.tscn を通らず main.tscn を直接起動した
# 場合だけ使う。Editor で作ったプログラムは RunConfig 経由でこれを置き換える。
const DEFAULT_PROGRAM_LINES := [
	{
		"timing": "land",
		"effect": "shock",
		"target": "around",
		"amount": 2,
		"element": "fire",
	},
]

var generator := DungeonGenerator.new()
var data: Dictionary
var player: DungeonPlayer
var camera: Camera2D
var land_effect_texture: Texture2D
var program_lines: Array[Dictionary] = []
var active_tile_effects: Array[Dictionary] = []
var police_enemies: Array = []
var police_turn_time_left := 0.0
var execution_logs: Array[Dictionary] = []
var impact_flashes: Array[Dictionary] = []
var combat_popups: Array[Dictionary] = []
var camera_shake_time_left := 0.0
var camera_shake_duration := 0.0
var camera_shake_strength := 0.0
var camera_shake_phase := 0.0
var hit_stop_time_left := 0.0
var last_realtime_msec := 0

func _ready() -> void:
	# SPEC: ヒットストップ中もログやヒット演出は進めたいので、このルートノードは
	# Engine.time_scale が下がっている間も処理されるようにする。
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	last_realtime_msec = Time.get_ticks_msec()
	_load_land_effect_texture()
	_load_program_lines()
	regenerate()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func regenerate() -> void:
	if is_instance_valid(player): player.queue_free()
	_clear_police_enemies()
	active_tile_effects.clear()
	execution_logs.clear()
	impact_flashes.clear()
	combat_popups.clear()
	police_turn_time_left = 0.0
	camera_shake_time_left = 0.0
	camera_shake_duration = 0.0
	camera_shake_strength = 0.0
	hit_stop_time_left = 0.0
	Engine.time_scale = 1.0
	last_realtime_msec = Time.get_ticks_msec()
	data = generator.generate()
	_spawn_police_enemies()
	player = DungeonPlayer.new()
	player.setup(data, TILE)
	player.set_blocked_cells(_get_police_cells())
	add_child(player)
	player.landed.connect(_on_player_landed)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2.ONE * CAMERA_ZOOM
	camera.offset = Vector2.ZERO
	player.add_child(camera)
	_refresh_wall_move_bonus()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("regenerate"):
		regenerate()
		return
	if event.is_action_pressed("attack"):
		_trigger_attack_programs()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if data.is_empty(): return
	# SPEC: ダンジョン床は手続き描画。キャラクターのスプライトは各ノードが描き、
	# 盤面全体にかかるオーバーレイはこのシーンが描く。
	draw_rect(Rect2(Vector2.ZERO, Vector2(data.width, data.height) * TILE), Color("070b0d"))
	for y in range(data.height):
		for x in range(data.width):
			var cell: int = data.cells[y * data.width + x]
			var pos := Vector2(x, y) * TILE
			if cell == DungeonGenerator.WALL:
				continue
			var base := Color("665b48") if cell == DungeonGenerator.FLOOR else Color("47656b")
			var shade := 0.88 + float((x * 13 + y * 7) % 5) * 0.025
			draw_rect(Rect2(pos + Vector2.ONE, Vector2.ONE * (TILE - 2)), base * shade)
			draw_line(pos + Vector2(1, TILE - 2), pos + Vector2(TILE - 2, TILE - 2), Color(0.1,0.1,0.09,0.35), 1)
			if cell == DungeonGenerator.FACILITY and (x + y) % 4 == 0:
				draw_circle(pos + Vector2.ONE * TILE * 0.5, 2.2, Color("72d8d3"))
	_draw_tile_effects()
	_draw_impact_flashes()
	_draw_move_highlights()
	_draw_wall_edges()
	_draw_combat_popups()
	_draw_ui()
	_draw_execution_log()

func _draw_tile_effects() -> void:
	if land_effect_texture == null:
		return

	# SPEC: タイル効果は接続マスク付きセルとして保持する。隣接セルとのつながりから
	# アトラス列を選び、複数マスの効果がつながって見えるようにする。
	for effect in active_tile_effects:
		var duration: float = effect.duration
		var progress := 1.0 - clampf(effect.time_left / duration, 0.0, 1.0)
		var fade := clampf(effect.time_left / duration, 0.0, 1.0)
		var pulse := 0.82 + sin(progress * TAU * 2.0) * 0.12
		var modulate := Color(1.0, 1.0, 1.0, fade * pulse)
		var row := LandEffectPatternScript.get_element_row(effect.element)

		for render_cell in effect.cells:
			var cell: Vector2i = render_cell.cell
			var mask: int = render_cell.mask
			_draw_land_effect_tile(cell, row, mask, modulate)
			if render_cell.origin:
				_draw_land_effect_tile(cell, row, LandEffectPatternScript.ORIGIN_COLUMN, Color(1.0, 1.0, 1.0, minf(modulate.a * 1.25, 1.0)))

func _draw_land_effect_tile(cell: Vector2i, row: int, column: int, modulate: Color) -> void:
	var destination := Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE)
	var source := Rect2(Vector2(column * TILE, row * TILE), Vector2.ONE * TILE)
	draw_texture_rect_region(land_effect_texture, destination, source, modulate)

func _draw_impact_flashes() -> void:
	for flash in impact_flashes:
		var duration: float = flash.duration
		var progress := 1.0 - clampf(float(flash.time_left) / duration, 0.0, 1.0)
		var fade := clampf(float(flash.time_left) / duration, 0.0, 1.0)
		var color: Color = flash.color
		var fill_color := Color(color.r, color.g, color.b, 0.18 * fade)
		var line_color := color.lerp(Color(1.0, 1.0, 1.0), 0.34)
		line_color.a = 0.92 * fade
		var expansion := roundf(progress * 4.0)

		for cell in flash.cells:
			var p := Vector2(cell) * TILE
			draw_rect(Rect2(p + Vector2.ONE * 3.0, Vector2.ONE * (TILE - 6.0)), fill_color)
			draw_rect(
				Rect2(p + Vector2.ONE * (2.0 - expansion), Vector2.ONE * (TILE - 4.0 + expansion * 2.0)),
				line_color,
				false,
				2.0
			)

func _draw_move_highlights() -> void:
	if not is_instance_valid(player):
		return

	for cell in player.get_legal_moves():
		var p := Vector2(cell) * TILE
		draw_rect(Rect2(p + Vector2(5, 5), Vector2.ONE * (TILE - 10)), Color(0.93, 0.82, 0.35, 0.26))
		draw_rect(Rect2(p + Vector2(5, 5), Vector2.ONE * (TILE - 10)), Color(0.96, 0.88, 0.45, 0.55), false, 1.0)

	var selected := player.get_selected_cell()
	if player.get_legal_moves().has(selected):
		var selected_pos := Vector2(selected) * TILE
		draw_rect(Rect2(selected_pos + Vector2(2, 2), Vector2.ONE * (TILE - 4)), Color(1.0, 0.93, 0.38, 0.95), false, 3.0)

func _draw_wall_edges() -> void:
	for y in range(1, data.height - 1):
		for x in range(1, data.width - 1):
			if data.cells[y * data.width + x] != DungeonGenerator.WALL: continue
			var p := Vector2(x, y) * TILE
			var near_floor := false
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if data.cells[(y+d.y)*data.width + x+d.x] != DungeonGenerator.WALL: near_floor = true
			if near_floor:
				draw_rect(Rect2(p, Vector2.ONE * TILE), Color("252820"))
				draw_rect(Rect2(p + Vector2(3,3), Vector2.ONE * (TILE-6)), Color("34352b"), false, 2)

func _draw_ui() -> void:
	var canvas := get_canvas_transform().affine_inverse()
	var top_left := canvas * Vector2(16, 16)
	draw_rect(Rect2(top_left, Vector2(560, 82)), Color(0.02,0.03,0.04,0.88))
	var move_name := "-"
	var move_index := 0
	var move_count := 0
	if is_instance_valid(player):
		move_name = "%s / Facing %s" % [player.get_current_move_name(), player.get_facing_label()]
		move_index = player.get_move_pattern_index() + 1
		move_count = player.get_move_pattern_count()
	var hp_text := "HP: -"
	if is_instance_valid(player):
		hp_text = "HP: %d/%d" % [player.get_hp(), player.get_max_hp()]
	draw_string(ThemeDB.fallback_font, top_left + Vector2(14, 23), "RUINS DELVER  |  %s  |  Move: %s (%d/%d)" % [hp_text, move_name, move_index, move_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e7dfc3"))
	draw_string(ThemeDB.fallback_font, top_left + Vector2(14, 47), "Aim: WASD / Arrow Keys   Confirm: Space / Enter / Click   Attack: F   R: Rotate facing", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("94b9b5"))
	draw_string(ThemeDB.fallback_font, top_left + Vector2(14, 68), "Q/E: Change weapon   G: Regenerate   Rooms: %d   Facility rooms: %d   Police: %d" % [data.rooms.size(), _facility_count(), _get_alive_police_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("94b9b5"))

func _draw_combat_popups() -> void:
	for popup in combat_popups:
		var duration: float = popup.duration
		var progress := 1.0 - clampf(float(popup.time_left) / duration, 0.0, 1.0)
		var alpha := clampf(float(popup.time_left) / duration, 0.0, 1.0)
		var font_size: int = popup.font_size
		var color: Color = popup.color
		color.a *= alpha
		var shadow := Color(0.0, 0.0, 0.0, alpha * 0.86)
		var jitter := sin(progress * TAU * 2.4 + float(popup.phase)) * 2.0
		var position: Vector2 = popup.position + Vector2(jitter, -progress * 18.0)
		draw_string(ThemeDB.fallback_font, position + Vector2(1, 1), str(popup.text), HORIZONTAL_ALIGNMENT_CENTER, 86.0, font_size, shadow)
		draw_string(ThemeDB.fallback_font, position, str(popup.text), HORIZONTAL_ALIGNMENT_CENTER, 86.0, font_size, color)

func _draw_execution_log() -> void:
	var viewport_size := get_viewport_rect().size
	if execution_logs.is_empty() or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var canvas := get_canvas_transform().affine_inverse()
	# SPEC: 実行ログは固定パネルではなくトースト表示。左下でコード実行を伝えるが、
	# プレイヤー視界を隠し続けないことを優先する。
	var font_size := 11
	var max_width := 326.0
	var line_height := 17.0
	for index in range(execution_logs.size()):
		var entry := execution_logs[index]
		var fade := clampf(float(entry.time_left) / float(entry.duration), 0.0, 1.0)
		var color: Color = entry.color
		color.a *= minf(1.0, fade * 1.45)
		var text := str(entry.text)
		var text_width := minf(max_width, maxf(82.0, float(text.length()) * 5.8 + 18.0))
		var progress := 1.0 - fade
		var screen_pos := Vector2(12.0 + progress * 8.0, viewport_size.y - 16.0 - float(index) * line_height - progress * 4.0)
		var line_pos := canvas * screen_pos
		var rect := Rect2(line_pos + Vector2(0.0, -13.0), Vector2(text_width, 16.0))
		draw_rect(rect, Color(0.015, 0.026, 0.028, 0.62 * color.a))
		draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), Color(color.r, color.g, color.b, 0.85 * color.a))
		draw_string(ThemeDB.fallback_font, line_pos + Vector2(8.0, -1.0), text, HORIZONTAL_ALIGNMENT_LEFT, text_width - 12.0, font_size, color)

func _facility_count() -> int:
	var count := 0
	for room in data.rooms:
		if room.type == "facility": count += 1
	return count

func _process(delta: float) -> void:
	var real_delta := _consume_realtime_delta()
	# SPEC: 視覚フィードバックのタイマーは実時間で進める。盤面効果と警察ロックは
	# スケール済み delta を使い、ヒットストップ中は盤面だけ止める。
	_update_hit_stop(real_delta)
	_update_tile_effects(delta)
	_update_impact_flashes(real_delta)
	_update_combat_popups(real_delta)
	_update_execution_logs(real_delta)
	_update_camera_shake(real_delta)
	_update_police_turn_lock(delta)
	_refresh_wall_move_bonus()
	queue_redraw()

func _load_land_effect_texture() -> void:
	land_effect_texture = load(LAND_EFFECT_TEXTURE_PATH)
	if land_effect_texture == null:
		push_warning("Failed to load land effect texture: %s" % LAND_EFFECT_TEXTURE_PATH)

func _spawn_police_enemies() -> void:
	var player_spawn: Vector2i = data.spawn
	# SPEC: スポーン座標は DungeonGenerator が決める。PoliceEnemy は見た目とHPだけを
	# 持ち、AI判断は当面 main.gd に集約する。
	for spawn in data.get("police_spawns", []):
		var spawn_cell: Vector2i = spawn
		var police = PoliceEnemyScript.new()
		police.setup(spawn_cell, TILE, _get_direction_toward(spawn_cell, player_spawn))
		add_child(police)
		police_enemies.append(police)

func _clear_police_enemies() -> void:
	for police in police_enemies:
		if is_instance_valid(police):
			police.queue_free()
	police_enemies.clear()

func _get_police_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for police in police_enemies:
		if is_instance_valid(police) and police.is_alive():
			cells.append(police.get_grid_cell())
	return cells

func _get_alive_police_count() -> int:
	var count := 0
	for police in police_enemies:
		if is_instance_valid(police) and police.is_alive():
			count += 1
	return count

func _get_direction_toward(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta := to_cell - from_cell
	if absi(delta.x) > absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return Vector2i(0, signi(delta.y))
	if delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	return Vector2i.DOWN

func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _on_player_landed(cell: Vector2i, _previous_cell: Vector2i, forward_dir: Vector2i) -> void:
	# SPEC: ガジェットのタイミングは着地時に解決する。move には直前セルを渡し、
	# trail 系が経路を使えるようにする。land/wall は着地後のセルを使う。
	_trigger_timing_programs("move", cell, forward_dir, _previous_cell)
	_trigger_timing_programs("land", cell, forward_dir)
	if _is_touching_wall(cell):
		_trigger_timing_programs("wall", cell, forward_dir)
	_run_police_turn(cell)
	_refresh_wall_move_bonus()

func _run_police_turn(player_cell: Vector2i) -> void:
	if not is_instance_valid(player) or not player.is_alive():
		return
	var occupied := _build_police_occupied_cells()
	var active_world_rect := _get_active_police_world_rect()
	var any_action := false

	# SPEC: AI計算する警察は画面内または画面付近だけ。大量配置する前提なので、
	# 画面外の敵は意図的に追跡も攻撃もしない。
	for police in police_enemies:
		if not is_instance_valid(police) or not police.is_alive():
			continue
		if not _is_police_visible_for_turn(police, active_world_rect):
			continue
		var police_cell: Vector2i = police.get_grid_cell()
		var direction_to_player := _get_direction_toward(police_cell, player_cell)
		if _manhattan_distance(police_cell, player_cell) == 1:
			police.set_facing(direction_to_player)
			# SPEC: 隣接した警察はプレイヤーのマスへ踏み込まず攻撃する。攻撃形状は
			# プレイヤー側と同じ front 1 のタイル効果を再利用する。
			_spawn_police_attack_effect(police_cell, direction_to_player)
			any_action = true
			if not player.is_alive():
				break
			continue

		var next_cell := _choose_police_step(police_cell, player_cell, occupied)
		if next_cell == police_cell:
			police.set_facing(direction_to_player)
			continue
		occupied.erase(police_cell)
		occupied[next_cell] = true
		any_action = police.move_to(next_cell) or any_action

	player.set_blocked_cells(_get_police_cells())
	if any_action:
		police_turn_time_left = POLICE_TURN_LOCK_DURATION
		player.set_input_locked(true)

func _build_police_occupied_cells() -> Dictionary:
	var occupied := {}
	for police in police_enemies:
		if is_instance_valid(police) and police.is_alive():
			occupied[police.get_grid_cell()] = true
	return occupied

func _get_active_police_world_rect() -> Rect2:
	if not is_instance_valid(camera):
		return Rect2(Vector2.ZERO, Vector2(data.width, data.height) * TILE)
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2(data.width, data.height) * TILE)
	var zoom := camera.zoom
	var world_size := Vector2(viewport_size.x / zoom.x, viewport_size.y / zoom.y)
	var center := camera.get_screen_center_position()
	return Rect2(center - world_size * 0.5, world_size).grow(POLICE_VISIBILITY_MARGIN)

func _is_police_visible_for_turn(police, active_world_rect: Rect2) -> bool:
	var police_center := Vector2(police.get_grid_cell()) * TILE + Vector2.ONE * TILE * 0.5
	var police_rect := Rect2(
		police_center - Vector2.ONE * POLICE_VISIBILITY_MARGIN,
		Vector2.ONE * POLICE_VISIBILITY_MARGIN * 2.0
	)
	return active_world_rect.intersects(police_rect)

func _choose_police_step(origin_cell: Vector2i, player_cell: Vector2i, occupied: Dictionary) -> Vector2i:
	var path_step := _find_police_path_step(origin_cell, player_cell, occupied)
	if path_step != origin_cell:
		return path_step

	var candidates: Array[Vector2i] = []
	var preferred_dirs := _get_police_preferred_directions(origin_cell, player_cell)
	for direction in preferred_dirs:
		var cell := origin_cell + direction
		if _can_police_step_to(cell, player_cell, occupied):
			candidates.append(cell)

	if candidates.is_empty():
		return origin_cell

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var distance_a := _manhattan_distance(a, player_cell)
		var distance_b := _manhattan_distance(b, player_cell)
		if distance_a != distance_b:
			return distance_a < distance_b
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	return candidates[0]

func _find_police_path_step(origin_cell: Vector2i, player_cell: Vector2i, occupied: Dictionary) -> Vector2i:
	# SPEC: 警察の経路探索は上下左右の床セルだけを見る単純な BFS。プレイヤーセルは
	# ゴールとして扱うが、実際の移動先にはしない。
	var frontier: Array[Vector2i] = [origin_cell]
	var frontier_index := 0
	var came_from := {origin_cell: origin_cell}

	while frontier_index < frontier.size():
		var current := frontier[frontier_index]
		frontier_index += 1
		if current == player_cell:
			break

		for direction in LandEffectPatternScript.CARDINAL_DIRECTIONS:
			var next_cell := current + direction
			if came_from.has(next_cell):
				continue
			if next_cell != player_cell and not _can_police_path_through(next_cell, occupied):
				continue
			came_from[next_cell] = current
			frontier.append(next_cell)

	if not came_from.has(player_cell):
		return origin_cell

	var step := player_cell
	var previous: Vector2i = came_from[step]
	while previous != origin_cell:
		step = previous
		previous = came_from[step]
	return step

func _get_police_preferred_directions(origin_cell: Vector2i, player_cell: Vector2i) -> Array[Vector2i]:
	var delta := player_cell - origin_cell
	var horizontal := Vector2i(signi(delta.x), 0)
	var vertical := Vector2i(0, signi(delta.y))
	var directions: Array[Vector2i] = []

	if absi(delta.x) >= absi(delta.y):
		if horizontal != Vector2i.ZERO:
			directions.append(horizontal)
		if vertical != Vector2i.ZERO:
			directions.append(vertical)
	else:
		if vertical != Vector2i.ZERO:
			directions.append(vertical)
		if horizontal != Vector2i.ZERO:
			directions.append(horizontal)

	for fallback in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if not directions.has(fallback):
			directions.append(fallback)
	return directions

func _can_police_step_to(cell: Vector2i, player_cell: Vector2i, occupied: Dictionary) -> bool:
	if cell == player_cell:
		return false
	if occupied.has(cell):
		return false
	if data.is_empty():
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= data.width or cell.y >= data.height:
		return false
	return data.cells[cell.y * data.width + cell.x] != DungeonGenerator.WALL

func _can_police_path_through(cell: Vector2i, occupied: Dictionary) -> bool:
	if occupied.has(cell):
		return false
	if data.is_empty():
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= data.width or cell.y >= data.height:
		return false
	return data.cells[cell.y * data.width + cell.x] != DungeonGenerator.WALL

func _spawn_police_attack_effect(police_cell: Vector2i, direction: Vector2i) -> void:
	var cells := LandEffectPatternScript.build_cells(
		police_cell,
		direction,
		"front",
		1,
		Callable(self, "_can_effect_affect_cell")
	)
	if not cells.is_empty():
		_append_tile_effect(cells, "normal", LAND_EFFECT_DURATION * 0.55)
		_damage_player_in_render_cells(cells, POLICE_ATTACK_DAMAGE)

func _update_police_turn_lock(delta: float) -> void:
	if police_turn_time_left <= 0.0:
		return
	police_turn_time_left -= delta
	if police_turn_time_left <= 0.0 and is_instance_valid(player):
		player.set_input_locked(false)

func _load_program_lines() -> void:
	program_lines.clear()
	var source_programs: Array = RunConfig.get_program_lines() if RunConfig.has_editor_program else DEFAULT_PROGRAM_LINES
	# SPEC: 実行時は Editor で検証済みの辞書だけを受け取る想定。不明または不完全な
	# 辞書は無視し、main.tscn 側を壊れにくくする。
	for program in source_programs:
		var program_dict: Dictionary = program
		if not program_dict.has("timing") or not program_dict.has("effect") or not program_dict.has("element"):
			continue
		if String(program_dict.get("effect", "")) != "trail" and (not program_dict.has("target") or not program_dict.has("amount")):
			continue
		program_lines.append(program_dict)

func _trigger_attack_programs() -> void:
	if police_turn_time_left > 0.0 or not is_instance_valid(player) or not player.is_alive() or player.is_moving:
		return
	# SPEC: Fキーでは必ず何かしら攻撃が出る。Editor に attack 行がない場合でも、
	# front 1 normal の基本攻撃で戦闘テストできるようにする。
	if not _has_timing_program("attack"):
		_spawn_default_player_attack(player.get_grid_cell(), player.get_forward_dir())
	else:
		_trigger_timing_programs("attack", player.get_grid_cell(), player.get_forward_dir())
	# SPEC: F攻撃も1手として扱う。攻撃後に警察ターンを回すことで、移動しない戦闘でも
	# 敵が詰める/殴る流れを止めない。
	_run_police_turn(player.get_grid_cell())
	_refresh_wall_move_bonus()

func _has_timing_program(timing: String) -> bool:
	for program in program_lines:
		if String(program.get("timing", "")) == timing:
			return true
	return false

func _spawn_default_player_attack(origin_cell: Vector2i, forward_dir: Vector2i) -> void:
	var cells := LandEffectPatternScript.build_cells(
		origin_cell,
		forward_dir,
		"front",
		1,
		Callable(self, "_can_effect_affect_cell")
	)
	if cells.is_empty():
		return
	_add_execution_log("RUN basic attack front 1 normal", Color("ffe682"))
	_append_tile_effect(cells, "normal", LAND_EFFECT_DURATION * 0.65)
	_damage_police_in_render_cells(cells, PLAYER_ATTACK_DAMAGE_UNITS)

func _trigger_timing_programs(timing: String, origin_cell: Vector2i, forward_dir: Vector2i, previous_cell := Vector2i(999999, 999999)) -> void:
	for program in program_lines:
		if String(program.get("timing", "")) != timing:
			continue
		_spawn_program_effect(origin_cell, forward_dir, program, previous_cell)

func _spawn_program_effect(origin_cell: Vector2i, forward_dir: Vector2i, program: Dictionary, previous_cell: Vector2i) -> void:
	var effect := String(program.get("effect", ""))
	var element := String(program.get("element", "normal"))
	var damage_units := _get_program_damage_units(program)
	# SPEC: 現時点で trail だけは target+amount を使わない。他の効果は
	# LandEffectPattern が作る空間形状として扱う。
	if effect == "trail":
		_spawn_trail_effect(origin_cell, previous_cell, element, damage_units, _get_program_source(program), _get_timing_log_color(String(program.get("timing", ""))))
		return

	var target := String(program.get("target", "around"))
	var amount := int(program.get("amount", 1))
	var cells := LandEffectPatternScript.build_cells(
		origin_cell,
		forward_dir,
		target,
		amount,
		Callable(self, "_can_effect_affect_cell")
	)
	if cells.is_empty():
		return

	_add_execution_log("RUN " + _get_program_source(program), _get_timing_log_color(String(program.get("timing", ""))))
	_append_tile_effect(cells, element)
	_damage_police_in_render_cells(cells, damage_units)

func _spawn_trail_effect(origin_cell: Vector2i, previous_cell: Vector2i, element: String, damage_units: int, source: String, log_color: Color) -> void:
	var cells: Array[Vector2i] = []
	if previous_cell.x < 999999 and _can_effect_affect_cell(previous_cell):
		cells.append(previous_cell)
	if _can_effect_affect_cell(origin_cell):
		cells.append(origin_cell)
	var origin_cells: Array[Vector2i] = [origin_cell]
	var render_cells := LandEffectPatternScript.build_from_cells(cells, origin_cells)
	if render_cells.is_empty():
		return
	_add_execution_log("RUN " + source, log_color)
	_append_tile_effect(render_cells, element, LAND_EFFECT_DURATION * 1.45)
	_damage_police_in_render_cells(render_cells, damage_units)

func _get_program_damage_units(program: Dictionary) -> int:
	# SPEC: ダメージ量は element ではなく timing で決める。属性は将来の状態異常用に
	# 残し、現段階では見た目と Editor のコストだけを変える。
	match String(program.get("timing", "")):
		"attack":
			return PLAYER_ATTACK_DAMAGE_UNITS
		"land":
			return PLAYER_LAND_DAMAGE_UNITS
		"move":
			return PLAYER_MOVE_DAMAGE_UNITS
		"wall":
			return PLAYER_WALL_DAMAGE_UNITS
		_:
			return PLAYER_ATTACK_DAMAGE_UNITS

func _get_program_source(program: Dictionary) -> String:
	var source := String(program.get("source", ""))
	if not source.is_empty():
		return source
	if String(program.get("effect", "")) == "trail":
		return "%s %s %s" % [
			String(program.get("timing", "")),
			String(program.get("effect", "")),
			String(program.get("element", "normal")),
		]
	return "%s %s %s %d %s" % [
		String(program.get("timing", "")),
		String(program.get("effect", "")),
		String(program.get("target", "front")),
		int(program.get("amount", 1)),
		String(program.get("element", "normal")),
	]

func _get_timing_log_color(timing: String) -> Color:
	match timing:
		"attack":
			return Color("ffe682")
		"land":
			return Color("ff9d66")
		"move":
			return Color("78fff2")
		"wall":
			return Color("b8c4d8")
		_:
			return Color("dfe7dd")

func _append_tile_effect(cells: Array[Dictionary], element: String, duration := LAND_EFFECT_DURATION) -> void:
	active_tile_effects.append({
		"cells": cells,
		"element": element,
		"time_left": duration,
		"duration": duration,
	})

func _damage_player_in_render_cells(render_cells: Array[Dictionary], amount: int) -> void:
	if not is_instance_valid(player) or not player.is_alive():
		return
	for render_cell in render_cells:
		var cell: Vector2i = render_cell.cell
		if cell != player.get_grid_cell():
			continue
		_add_impact_flash(_render_cells_to_cells(render_cells), Color("ff5b4a"))
		_trigger_impact(4.2, HIT_STOP_DURATION)
		if player.take_damage(amount):
			_add_execution_log("POLICE HIT player -%d HP / DOWN" % amount, Color("ff5b4a"))
			_add_combat_popup(player.position + Vector2(-43.0, -26.0), "DOWN", Color("ff4e3f"), 15)
		else:
			_add_execution_log("POLICE HIT player -%d HP" % amount, Color("ff5b4a"))
		return

func _damage_police_in_render_cells(render_cells: Array[Dictionary], amount: int) -> void:
	var affected_cells := {}
	# SPEC: 1つの効果で同じ警察に複数回ダメージを与えない。将来、接続描画の都合で
	# 同じ範囲に複数の見た目セルができてもダメージは1回にする。
	for render_cell in render_cells:
		var cell: Vector2i = render_cell.cell
		affected_cells[cell] = true

	var damaged := false
	var defeated_count := 0
	for police in police_enemies:
		if not is_instance_valid(police) or not police.is_alive():
			continue
		if not affected_cells.has(police.get_grid_cell()):
			continue
		damaged = true
		var popup_position := Vector2(police.get_grid_cell()) * TILE + Vector2.ONE * TILE * 0.5 + Vector2(-43.0, -28.0)
		if police.take_damage(amount):
			defeated_count += 1
			_add_combat_popup(popup_position, "DOWN", Color("ff4e3f"), 15)
			police.queue_free()
			_add_execution_log("POLICE DOWN", Color("ff5b4a"))
		else:
			_add_execution_log("POLICE damage %s" % _format_damage_units(amount), Color("ff9d66"))

	if damaged:
		_add_impact_flash(_render_cells_to_cells(render_cells), Color("fff16a"))
		_trigger_impact(4.0 if defeated_count > 0 else 2.4, HIT_STOP_DURATION if defeated_count > 0 else 0.04)
		_remove_dead_police()
		player.set_blocked_cells(_get_police_cells())

func _remove_dead_police() -> void:
	for i in range(police_enemies.size() - 1, -1, -1):
		var police = police_enemies[i]
		if not is_instance_valid(police) or not police.is_alive():
			police_enemies.remove_at(i)

func _add_execution_log(text: String, color: Color) -> void:
	execution_logs.push_front({
		"text": text,
		"color": color,
		"time_left": EXECUTION_LOG_DURATION,
		"duration": EXECUTION_LOG_DURATION,
	})
	while execution_logs.size() > EXECUTION_LOG_MAX:
		execution_logs.pop_back()

func _add_impact_flash(cells: Array[Vector2i], color: Color, duration := IMPACT_FLASH_DURATION) -> void:
	if cells.is_empty():
		return
	impact_flashes.append({
		"cells": cells,
		"color": color,
		"time_left": duration,
		"duration": duration,
	})

func _add_combat_popup(position: Vector2, text: String, color: Color, font_size := 13) -> void:
	combat_popups.append({
		"position": position,
		"text": text,
		"color": color,
		"font_size": font_size,
		"phase": combat_popups.size() * 1.7 + Time.get_ticks_msec() * 0.001,
		"time_left": COMBAT_POPUP_DURATION,
		"duration": COMBAT_POPUP_DURATION,
	})

func _render_cells_to_cells(render_cells: Array[Dictionary]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for render_cell in render_cells:
		var cell: Vector2i = render_cell.cell
		if not cells.has(cell):
			cells.append(cell)
	return cells

func _update_execution_logs(delta: float) -> void:
	for i in range(execution_logs.size() - 1, -1, -1):
		execution_logs[i].time_left -= delta
		if execution_logs[i].time_left <= 0.0:
			execution_logs.remove_at(i)

func _update_impact_flashes(delta: float) -> void:
	for i in range(impact_flashes.size() - 1, -1, -1):
		impact_flashes[i].time_left -= delta
		if impact_flashes[i].time_left <= 0.0:
			impact_flashes.remove_at(i)

func _update_combat_popups(delta: float) -> void:
	for i in range(combat_popups.size() - 1, -1, -1):
		combat_popups[i].time_left -= delta
		if combat_popups[i].time_left <= 0.0:
			combat_popups.remove_at(i)

func _trigger_impact(shake_strength: float, hit_stop_duration: float) -> void:
	# SPEC: このプロトタイプには独立クロックが必要な物理体がないため、
	# ヒットストップは Engine.time_scale で全体にかける。_exit_tree/regenerate で戻す。
	camera_shake_time_left = maxf(camera_shake_time_left, CAMERA_SHAKE_DURATION)
	camera_shake_duration = CAMERA_SHAKE_DURATION
	camera_shake_strength = maxf(camera_shake_strength, shake_strength)
	camera_shake_phase += 1.0
	if hit_stop_duration > 0.0:
		hit_stop_time_left = maxf(hit_stop_time_left, hit_stop_duration)
		Engine.time_scale = HIT_STOP_TIME_SCALE

func _update_camera_shake(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if camera_shake_time_left <= 0.0:
		camera.offset = Vector2.ZERO
		camera_shake_strength = 0.0
		return
	camera_shake_time_left = maxf(camera_shake_time_left - delta, 0.0)
	var fade := camera_shake_time_left / maxf(camera_shake_duration, 0.001)
	var progress := 1.0 - fade
	var strength := camera_shake_strength * fade
	camera.offset = Vector2(
		sin(progress * 82.0 + camera_shake_phase * 1.7),
		cos(progress * 97.0 + camera_shake_phase * 2.3)
	) * strength
	if camera_shake_time_left <= 0.0:
		camera.offset = Vector2.ZERO
		camera_shake_strength = 0.0

func _update_hit_stop(delta: float) -> void:
	if hit_stop_time_left <= 0.0:
		if Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
		return
	hit_stop_time_left = maxf(hit_stop_time_left - delta, 0.0)
	if hit_stop_time_left <= 0.0:
		Engine.time_scale = 1.0

func _consume_realtime_delta() -> float:
	var now := Time.get_ticks_msec()
	if last_realtime_msec <= 0:
		last_realtime_msec = now
		return get_process_delta_time()
	var elapsed := clampf(float(now - last_realtime_msec) / 1000.0, 0.0, 0.1)
	last_realtime_msec = now
	return elapsed

func _format_damage_units(units: int) -> String:
	if units % DAMAGE_UNIT == 0:
		return "-%d" % int(units / DAMAGE_UNIT)
	return "-0.5"

func _update_tile_effects(delta: float) -> void:
	for i in range(active_tile_effects.size() - 1, -1, -1):
		active_tile_effects[i].time_left -= delta
		if active_tile_effects[i].time_left <= 0.0:
			active_tile_effects.remove_at(i)

func _refresh_wall_move_bonus() -> void:
	if not is_instance_valid(player):
		return
	var bonus_moves: Array[Vector2i] = []
	var origin_cell := player.get_grid_cell()
	if _is_touching_wall(origin_cell):
		# SPEC: wall move 行は即時移動ではなく、移動候補セルを追加する。最終的な
		# 移動先はプレイヤーが選ぶ。
		for program in program_lines:
			if String(program.get("timing", "")) != "wall" or String(program.get("effect", "")) != "move":
				continue
			var cells := LandEffectPatternScript.build_cells(
				origin_cell,
				player.get_forward_dir(),
				String(program.get("target", "front")),
				int(program.get("amount", 1)),
				Callable(self, "_can_effect_affect_cell")
			)
			for render_cell in cells:
				var cell: Vector2i = render_cell.cell
				if not bonus_moves.has(cell):
					bonus_moves.append(cell)
	player.set_extra_legal_moves(bonus_moves)

func _is_touching_wall(cell: Vector2i) -> bool:
	for direction in LandEffectPatternScript.CARDINAL_DIRECTIONS:
		if _is_wall_cell(cell + direction):
			return true
	return false

func _is_wall_cell(cell: Vector2i) -> bool:
	if data.is_empty():
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= data.width or cell.y >= data.height:
		return false
	return data.cells[cell.y * data.width + cell.x] == DungeonGenerator.WALL

func _can_effect_affect_cell(cell: Vector2i) -> bool:
	if data.is_empty():
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= data.width or cell.y >= data.height:
		return false
	return data.cells[cell.y * data.width + cell.x] != DungeonGenerator.WALL
