class_name PoliceEnemy
extends Node2D

# SPEC: PoliceEnemy は見た目とHPを持つノード。追跡や攻撃の判断は main.gd に置き、
# カメラ可視範囲によるAI最適化を一箇所で扱う。
const POLICE_SPRITE_SHEET_PATH := "res://assets/sprites/enemies/police_officer_directions_28.png"
const HP_SLOT_EMPTY_PATH := "res://assets/sprites/editor_ui/part_capacity_unit_empty.png"
const HP_SLOT_FILLED_PATH := "res://assets/sprites/editor_ui/part_capacity_unit_filled.png"
const SPRITE_CELL_SIZE := Vector2i(28, 28)
const SPRITE_DRAW_SIZE := 28.0
const MOVE_DURATION := 0.16
const MAX_HP := 5
# SPEC: 内部HPは半HP単位で扱う。HP_UNIT == 2 のため、表示上のHPスロット1個は
# land/move/wall の 0.5 ダメージ2回分を表せる。
const HP_UNIT := 2
const HP_SLOT_SIZE := Vector2(6, 6)
const HP_SLOT_GAP := 1.0
const HP_MEMORY_Y := -24.0
const DAMAGE_POPUP_DURATION := 0.55
const HIT_FLASH_DURATION := 0.14

var tile_size := 24
var grid_cell := Vector2i.ZERO
var facing_dir := Vector2i.DOWN
var sprite_sheet: Texture2D
var hp_slot_empty_texture: Texture2D
var hp_slot_filled_texture: Texture2D
var max_hp_units := MAX_HP * HP_UNIT
var current_hp_units := MAX_HP * HP_UNIT
var damage_popups: Array[Dictionary] = []
var hit_flash_time_left := 0.0
var target_cell := Vector2i.ZERO
var move_start := Vector2.ZERO
var move_end := Vector2.ZERO
var move_elapsed := 0.0
var is_moving := false

func setup(cell: Vector2i, size: int, direction: Vector2i) -> void:
	# SPEC: setup は生成直後に1回だけ呼ぶ。警察は整数セル上に直接出現し、
	# 以後も整数セル同士の間だけをアニメーションする。
	grid_cell = cell
	tile_size = size
	facing_dir = _normalize_direction(direction)
	max_hp_units = MAX_HP * HP_UNIT
	current_hp_units = max_hp_units
	damage_popups.clear()
	hit_flash_time_left = 0.0
	position = _cell_to_world(grid_cell)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_sprite_sheet()
	_load_hp_memory_textures()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if is_moving:
		_update_move(delta)
	_update_damage_popups(delta)
	_update_hit_flash(delta)
	_update_processing()
	queue_redraw()

func get_grid_cell() -> Vector2i:
	return grid_cell

func get_hp() -> int:
	return ceili(float(current_hp_units) / float(HP_UNIT))

func get_max_hp() -> int:
	return MAX_HP

func is_alive() -> bool:
	return current_hp_units > 0

func take_damage(amount_units: int) -> bool:
	# SPEC: amount_units は main.gd と同じ半HP単位を使う。戻り値 true は死亡を表し、
	# main.gd 側で削除する。
	var applied_units := mini(maxi(amount_units, 0), current_hp_units)
	current_hp_units = maxi(current_hp_units - applied_units, 0)
	if applied_units > 0:
			damage_popups.append({
				"units": applied_units,
				"time_left": DAMAGE_POPUP_DURATION,
				"duration": DAMAGE_POPUP_DURATION,
				"phase": damage_popups.size() * 1.5 + Time.get_ticks_msec() * 0.001,
			})
			hit_flash_time_left = HIT_FLASH_DURATION
			set_process(true)
	queue_redraw()
	return current_hp_units <= 0

func set_facing(direction: Vector2i) -> void:
	facing_dir = _normalize_direction(direction)
	queue_redraw()

func move_to(destination: Vector2i) -> bool:
	# SPEC: 警察はプレイヤーの隣には移動できるが、プレイヤーセルには乗らない。
	# このルールはこのアニメーション関数を呼ぶ前に main.gd 側で保証する。
	if destination == grid_cell:
		return false
	facing_dir = _normalize_direction(destination - grid_cell)
	target_cell = destination
	move_start = position
	move_end = _cell_to_world(target_cell)
	move_elapsed = 0.0
	grid_cell = target_cell
	is_moving = true
	set_process(true)
	queue_redraw()
	return true

func _draw() -> void:
	if sprite_sheet == null:
		_draw_fallback_marker()
		return
	var destination := Rect2(Vector2.ONE * SPRITE_DRAW_SIZE * -0.5, Vector2.ONE * SPRITE_DRAW_SIZE)
	draw_texture_rect_region(sprite_sheet, destination, _get_sprite_region(), _get_hit_modulate())
	_draw_hp_memory()
	_draw_damage_popups()

func _load_sprite_sheet() -> void:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(POLICE_SPRITE_SHEET_PATH))
	if error != OK:
		push_warning("Failed to load police sprite sheet: %s" % POLICE_SPRITE_SHEET_PATH)
		return
	sprite_sheet = ImageTexture.create_from_image(image)

func _load_hp_memory_textures() -> void:
	hp_slot_empty_texture = load(HP_SLOT_EMPTY_PATH)
	hp_slot_filled_texture = load(HP_SLOT_FILLED_PATH)

func _update_move(delta: float) -> void:
	move_elapsed += delta
	var t := minf(move_elapsed / MOVE_DURATION, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	position = move_start.lerp(move_end, eased)
	if t >= 1.0:
		position = move_end
		is_moving = false

func _update_damage_popups(delta: float) -> void:
	for i in range(damage_popups.size() - 1, -1, -1):
		damage_popups[i].time_left -= delta
		if damage_popups[i].time_left <= 0.0:
			damage_popups.remove_at(i)

func _update_hit_flash(delta: float) -> void:
	hit_flash_time_left = maxf(hit_flash_time_left - delta, 0.0)

func _update_processing() -> void:
	set_process(is_moving or not damage_popups.is_empty() or hit_flash_time_left > 0.0)

func _draw_fallback_marker() -> void:
	draw_rect(Rect2(Vector2(-8, -10), Vector2(16, 20)), Color("182335"))
	draw_rect(Rect2(Vector2(-8, -10), Vector2(16, 20)), Color("83f3ff"), false, 2.0)
	draw_line(Vector2.ZERO, Vector2(facing_dir) * 13.0, Color("d7e2ef"), 3.0)
	_draw_hp_memory()
	_draw_damage_popups()

func _draw_hp_memory() -> void:
	# SPEC: 警察HPは Editor の容量メーターと同じメモリスロット表現で描く。
	# 戦闘中のリソースもガジェット的に読めるようにするため。
	var total_width := HP_SLOT_SIZE.x * MAX_HP + HP_SLOT_GAP * float(MAX_HP - 1)
	var origin := Vector2(-total_width * 0.5, HP_MEMORY_Y)

	for index in range(MAX_HP):
		var slot_pos := origin + Vector2(float(index) * (HP_SLOT_SIZE.x + HP_SLOT_GAP), 0.0)
		var slot_rect := Rect2(slot_pos, HP_SLOT_SIZE)
		_draw_hp_slot_base(slot_rect)

		var slot_units := clampi(current_hp_units - index * HP_UNIT, 0, HP_UNIT)
		if slot_units <= 0:
			continue
		var fill_width := HP_SLOT_SIZE.x * float(slot_units) / float(HP_UNIT)
		_draw_hp_slot_fill(Rect2(slot_pos, Vector2(fill_width, HP_SLOT_SIZE.y)), fill_width / HP_SLOT_SIZE.x)

func _draw_hp_slot_base(rect: Rect2) -> void:
	if hp_slot_empty_texture != null:
		draw_texture_rect(hp_slot_empty_texture, rect, false)
	else:
		draw_rect(rect, Color(0.08, 0.09, 0.1, 0.95))
		draw_rect(rect, Color("6b6f66"), false, 1.0)

func _draw_hp_slot_fill(rect: Rect2, fill_ratio: float) -> void:
	if hp_slot_filled_texture != null:
		var texture_size := hp_slot_filled_texture.get_size()
		var source := Rect2(Vector2.ZERO, Vector2(texture_size.x * fill_ratio, texture_size.y))
		draw_texture_rect_region(hp_slot_filled_texture, rect, source)
	else:
		draw_rect(rect.grow(-1.0), Color("31d0c3"))

func _draw_damage_popups() -> void:
	for popup in damage_popups:
		var duration: float = popup.duration
		var progress := 1.0 - clampf(float(popup.time_left) / duration, 0.0, 1.0)
		var alpha := clampf(float(popup.time_left) / duration, 0.0, 1.0)
		var text := _format_damage_units(int(popup.units))
		var jitter := sin(progress * TAU * 2.4 + float(popup.phase)) * 2.0
		var pos := Vector2(-18.0 + jitter, HP_MEMORY_Y - 9.0 - progress * 13.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 12, Color(0, 0, 0, alpha * 0.88))
		draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 12, Color(1.0, 0.28, 0.21, alpha))

func _format_damage_units(units: int) -> String:
	if units % HP_UNIT == 0:
		return "-%d" % int(units / HP_UNIT)
	return "-0.5"

func _get_hit_modulate() -> Color:
	if hit_flash_time_left <= 0.0:
		return Color(1.0, 1.0, 1.0, 1.0)
	var fade := hit_flash_time_left / HIT_FLASH_DURATION
	var pulse := 0.56 + sin(fade * TAU * 2.0) * 0.12
	return Color(1.0, 1.0, 1.0, 1.0).lerp(Color("ff705a"), clampf(pulse, 0.0, 0.82))

func _get_sprite_region() -> Rect2:
	return Rect2(
		Vector2(_get_facing_column() * SPRITE_CELL_SIZE.x, 0),
		Vector2(SPRITE_CELL_SIZE)
	)

func _get_facing_column() -> int:
	match facing_dir:
		Vector2i.UP:
			return 0
		Vector2i.RIGHT:
			return 1
		Vector2i.DOWN:
			return 2
		Vector2i.LEFT:
			return 3
		_:
			return 2

func _normalize_direction(direction: Vector2i) -> Vector2i:
	if direction == Vector2i.ZERO:
		return Vector2i.DOWN
	if absi(direction.x) > absi(direction.y):
		return Vector2i(signi(direction.x), 0)
	return Vector2i(0, signi(direction.y))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * tile_size + Vector2.ONE * tile_size * 0.5
