class_name GadgetEditor
extends Control

# SPEC: editor.tscn は3行まで書けるガジェットコードエディタ。小さなDSLを検証し、
# 行ごとの容量コストを表示し、検証済みのプログラム辞書を RunConfig に渡してから
# main.tscn を開く。
# SPEC: target と number を持つ構文:
# timing effect target number element
# 例: land shock around 1 fire
# SPEC: trail 構文:
# timing trail element
# 例: move trail poison
const DESIGN_SIZE := Vector2(1152, 648)
const MAX_LINES := 3
const CAPACITY_LIMIT := 5
const CODE_FONT_PATH := "res://assets/fonts/VT323-Regular.ttf"
const CODE_FONT_SIZE := 25
const CODE_BASELINE_OFFSET := Vector2(0, 24)
const JAPANESE_FONT_PATH := "res://assets/fonts/DotGothic16-Regular.ttf"
const JAPANESE_FONT_SIZE := 18
const SLOT_HINT_HEIGHT := 26.0
const SLOT_HINT_GAP := 8.0
const DICTIONARY_TAB_FONT_SIZE := 17
const STATUS_OFFSET := Vector2(760, 11)
const STATUS_TEXT_OFFSET := Vector2(12, 25)
const STATUS_TEXT_WIDTH := 244.0
const STATUS_FONT_SIZE := 20
const GO_BUTTON_OFFSET := Vector2(1034, 11)
const GO_BUTTON_SIZE := Vector2(52, 36)
const MAIN_SCENE_PATH := "res://main.tscn"

const SHELL_POS := Vector2(32, 28)
const HEADER_POS := Vector2(56, 50)
const PROGRAM_POS := Vector2(60, 168)
const MEMORY_POS := Vector2(772, 168)
const OUTPUT_POS := Vector2(60, 502)
const DICTIONARY_MODAL_SIZE := Vector2(760, 372)
const DICTIONARY_CLOSE_SIZE := Vector2(32, 28)
const ROW_START := Vector2(78, 230)
const ROW_STEP := 78.0
const ROW_SIZE := Vector2(652, 62)
const EDIT_OFFSET := Vector2(76, 16)
const EDIT_SIZE := Vector2(276, 30)
const INPUT_FIELD_OFFSET := Vector2(61, 11)
const LINE_NUMBER_OFFSET := Vector2(24, 38)
const BADGE_OFFSET := Vector2(364, 9)
const COST_SLOT_OFFSET := Vector2(414, 12)
const COST_SLOT_SIZE := Vector2(38, 38)
const COST_SLOT_STEP := 38.0
const COST_NUMBER_OFFSET := Vector2(606, 15)
const COST_NUMBER_SIZE := Vector2(40, 32)

const COLOR_TEXT := Color("e7dfc3")
const COLOR_MUTED := Color("9bb9b6")
const COLOR_DIM := Color("526a68")
const COLOR_TEAL := Color("2bdcbf")
const COLOR_TEAL_DARK := Color("13887e")
const COLOR_GO := Color("a4ff66")
const COLOR_GO_DARK := Color("2f682d")
const COLOR_RED := Color("ff4f5d")
const COLOR_RED_DARK := Color("80222b")
const COLOR_SLOT_EMPTY := Color(0.08, 0.14, 0.14, 1.0)
const COLOR_INPUT_TRANSPARENT := Color(1.0, 1.0, 1.0, 0.0)
const COLOR_SELECTION := Color(0.17, 0.86, 0.75, 0.26)
const COLOR_MODAL_BACKDROP := Color(0.0, 0.0, 0.0, 0.62)
const COLOR_MODAL_PANEL := Color(0.035, 0.06, 0.065, 0.98)
const COLOR_MODAL_INNER := Color(0.02, 0.035, 0.038, 0.96)
const COLOR_TRIGGER := Color("7cd7ff")
const COLOR_EFFECT := Color("f0c76a")
const COLOR_TARGET := Color("caa7ff")
const COLOR_ELEMENT := Color("ff8f6a")
const COLOR_VALUE := Color("90f0a0")

const SAMPLE_LINES := [
	"move hit front 1 lightning",
	"land shock around 1 fire",
	"",
]

# SPEC: これらの配列が Editor 側の正式な語彙。不在の単語は runtime に渡さない。
const TIMINGS := ["attack", "land", "wall", "move"]
const EFFECTS := ["hit", "shock", "move", "trail"]
const TARGETS := ["front", "around", "side"]
const ELEMENTS := ["normal", "fire", "ice", "lightning", "poison"]
# SPEC: 属性コストは加算式。normal は無料にし、すべての完全な命令に属性を
# 入れられるが、属性選択を強制しすぎないようにする。
const ELEMENT_COSTS := {
	"normal": 0,
	"fire": 1,
	"ice": 1,
	"poison": 2,
	"lightning": 2,
}
const DICTIONARY_TABS := [
	{"frame": "chip_attack", "label": "Timing", "category": "timing"},
	{"frame": "chip_land", "label": "Effect", "category": "effect"},
	{"frame": "chip_wall", "label": "Target", "category": "target"},
	{"frame": "chip_number", "label": "Number", "category": "value"},
	{"frame": "chip_trail", "label": "Element", "category": "element"},
]
# SPEC: CODE_DICTIONARY は下部タブに出すプレイヤー向け説明。パーサールールと
# コストルールを変えたらここも必ず同期する。
const CODE_DICTIONARY := {
	"timing": [
		{"segments": [{"text": "attack", "kind": "trigger"}], "description": "攻撃時に発動。武器の向きと移動先を基準に処理します。"},
		{"segments": [{"text": "land", "kind": "trigger"}], "description": "着地時に発動。到達したマスを中心に効果を出します。"},
		{"segments": [{"text": "wall", "kind": "trigger"}], "description": "壁に接している時に発動。地形条件で移動や攻撃を変えます。"},
		{"segments": [{"text": "move", "kind": "trigger"}], "description": "移動時に発動。通ったマスや移動後の状態を扱います。"},
	],
	"effect": [
		{"segments": [{"text": "hit", "kind": "effect"}], "description": "攻撃判定を作ります。target、value、element を順に差します。"},
		{"segments": [{"text": "shock", "kind": "effect"}], "description": "衝撃を発生させます。target、value、element を順に差します。"},
		{"segments": [{"text": "move", "kind": "effect"}], "description": "移動候補を追加します。target、value、element を順に差します。"},
		{"segments": [{"text": "trail", "kind": "effect"}], "description": "移動経路に属性効果を残します。element と組み合わせます。"},
	],
	"target": [
		{"segments": [{"text": "front", "kind": "target"}, {"text": " n", "kind": "value"}], "description": "向いている方向へ n マス。前方攻撃や前方効果に使います。"},
		{"segments": [{"text": "around", "kind": "target"}, {"text": " n", "kind": "value"}], "description": "周囲 n マス。着地時の衝撃や範囲効果に使います。"},
		{"segments": [{"text": "side", "kind": "target"}, {"text": " n", "kind": "value"}], "description": "横方向へ n マス。壁沿いの移動追加などに使います。"},
	],
	"value": [
		{"segments": [{"text": "n", "kind": "value"}], "description": "距離や範囲を表す数値。target ごとに上限があります。"},
		{"segments": [{"text": "front", "kind": "target"}, {"text": " 1-5", "kind": "value"}], "description": "front は 1 から 5 まで指定できます。"},
		{"segments": [{"text": "around", "kind": "target"}, {"text": " 1-3", "kind": "value"}], "description": "around は 1 から 3 まで指定できます。"},
		{"segments": [{"text": "side", "kind": "target"}, {"text": " 1-3", "kind": "value"}], "description": "side は 1 から 3 まで指定できます。"},
		{"segments": [{"text": "var", "kind": "value"}], "description": "後で装備や講義で可変値に差し替える余地があります。"},
	],
	"element": [
		{"segments": [{"text": "normal", "kind": "element"}], "description": "通常属性。追加属性を持たない基準タイプです。cost +0。"},
		{"segments": [{"text": "fire", "kind": "element"}], "description": "火属性。継続ダメージや燃焼系の効果に使います。cost +1。"},
		{"segments": [{"text": "ice", "kind": "element"}], "description": "氷属性。減速や凍結系の効果に使います。cost +1。"},
		{"segments": [{"text": "lightning", "kind": "element"}], "description": "雷属性。連鎖やスタン系の効果に使います。cost +2。"},
		{"segments": [{"text": "poison", "kind": "element"}], "description": "毒属性。ターン経過で効く効果に使います。cost +2。"},
	],
}

const FRAME_NAMES := [
	"backdrop",
	"shell",
	"panel_header",
	"panel_program",
	"panel_memory",
	"panel_output",
	"row_normal",
	"row_selected",
	"row_error",
	"input_field",
	"meter_wide",
	"meter_small",
	"cost_number_normal",
	"cost_number_error",
	"status_normal",
	"status_error",
	"chip_attack",
	"chip_land",
	"chip_wall",
	"chip_number",
	"chip_trail",
]

const PART_NAMES := [
	"editor_panel_frame",
	"code_line_slot_normal",
	"code_line_slot_selected",
	"code_line_slot_error",
	"capacity_unit_empty",
	"capacity_unit_filled",
	"capacity_unit_error",
	"capacity_meter_frame",
	"capacity_meter_fill",
	"capacity_meter_error",
	"input_cursor",
	"syntax_valid_badge",
	"syntax_error_badge",
	"line_cost_chip_frame",
	"gadget_editor_icon",
	"selection_glow_plate",
]

var frames: Dictionary = {}
var parts: Dictionary = {}
var line_edits: Array[LineEdit] = []
var parsed_lines: Array[Dictionary] = []
var row_rects: Array[Rect2] = []
var code_font: Font
var japanese_font: Font
var editor_origin := Vector2.ZERO
var total_cost := 0
var syntax_error := false
var has_draft := false
var over_capacity := false
var program_ready := false
var status_message := ""
var focused_line_index := 0
var active_dictionary_category := ""
var shake_time := 0.0
var go_time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_editor_assets()
	_build_line_edits()
	_update_layout()
	_validate_all()
	_focus_line.call_deferred(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		queue_redraw()


func _process(delta: float) -> void:
	var should_redraw := false
	if over_capacity:
		shake_time += delta
		should_redraw = true
	elif shake_time != 0.0:
		shake_time = 0.0
		should_redraw = true

	if program_ready:
		go_time += delta
		should_redraw = true
	elif go_time != 0.0:
		go_time = 0.0
		should_redraw = true

	if should_redraw:
		queue_redraw()


func _load_editor_assets() -> void:
	code_font = load(CODE_FONT_PATH)
	japanese_font = load(JAPANESE_FONT_PATH)
	for frame_name in FRAME_NAMES:
		frames[frame_name] = load("res://assets/sprites/editor_ui/%s.png" % frame_name)
	for part_name in PART_NAMES:
		parts[part_name] = load("res://assets/sprites/editor_ui/part_%s.png" % part_name)


func _build_line_edits() -> void:
	for i in range(MAX_LINES):
		var edit := LineEdit.new()
		edit.name = "CodeLine%d" % (i + 1)
		edit.max_length = 64
		edit.placeholder_text = SAMPLE_LINES[i]
		edit.expand_to_text_length = false
		edit.context_menu_enabled = true
		edit.add_theme_font_override("font", _get_code_font())
		edit.add_theme_font_size_override("font_size", CODE_FONT_SIZE)
		# SPEC: LineEdit 標準の文字は透明にする。構文カテゴリごとに固定色を付けるため、
		# 色付きコード文字は自前で描画する。
		edit.add_theme_color_override("font_color", COLOR_INPUT_TRANSPARENT)
		edit.add_theme_color_override("font_placeholder_color", COLOR_INPUT_TRANSPARENT)
		edit.add_theme_color_override("font_selected_color", COLOR_INPUT_TRANSPARENT)
		edit.add_theme_color_override("selection_color", COLOR_SELECTION)
		edit.add_theme_color_override("caret_color", COLOR_TEAL)
		_add_empty_line_edit_styles(edit)
		edit.text_changed.connect(_on_line_text_changed.bind(i))
		edit.text_submitted.connect(_on_line_submitted.bind(i))
		edit.focus_entered.connect(_on_line_focus_entered.bind(i))
		edit.gui_input.connect(_on_line_gui_input.bind(i))
		add_child(edit)
		line_edits.append(edit)


func _get_code_font() -> Font:
	return code_font if code_font != null else ThemeDB.fallback_font


func _get_japanese_font() -> Font:
	return japanese_font if japanese_font != null else ThemeDB.fallback_font


func _add_empty_line_edit_styles(edit: LineEdit) -> void:
	for style_name in ["normal", "focus", "read_only", "hover"]:
		edit.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())


func _seed_sample_program() -> void:
	for i in range(mini(line_edits.size(), SAMPLE_LINES.size())):
		line_edits[i].text = SAMPLE_LINES[i]


func _update_layout() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = DESIGN_SIZE
	editor_origin = ((viewport_size - DESIGN_SIZE) * 0.5).floor()

	row_rects.clear()
	for i in range(MAX_LINES):
		var row_rect := Rect2(editor_origin + ROW_START + Vector2(0, i * ROW_STEP), ROW_SIZE)
		row_rects.append(row_rect)
		if i < line_edits.size():
			line_edits[i].position = row_rect.position + EDIT_OFFSET
			line_edits[i].size = EDIT_SIZE


func _on_line_text_changed(new_text: String, line_index: int) -> void:
	if new_text.contains("\n"):
		var edit := line_edits[line_index]
		edit.text = new_text.replace("\n", " ")
		edit.caret_column = edit.text.length()
	_validate_all()


func _on_line_submitted(_new_text: String, line_index: int) -> void:
	_focus_line(mini(line_index + 1, MAX_LINES - 1))


func _on_line_focus_entered(line_index: int) -> void:
	focused_line_index = line_index
	queue_redraw()


func _on_line_gui_input(event: InputEvent, line_index: int) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_TAB:
			_apply_completion(line_index)
			line_edits[line_index].accept_event()
		KEY_UP:
			_focus_line(maxi(line_index - 1, 0))
			line_edits[line_index].accept_event()
		KEY_DOWN:
			_focus_line(mini(line_index + 1, MAX_LINES - 1))
			line_edits[line_index].accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			_focus_line(mini(line_index + 1, MAX_LINES - 1))
			line_edits[line_index].accept_event()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not active_dictionary_category.is_empty():
		if _get_dictionary_close_rect().has_point(event.position) or not _get_dictionary_modal_rect().has_point(event.position):
			active_dictionary_category = ""
			queue_redraw()
		accept_event()
		return

	if program_ready and _get_go_button_rect().has_point(event.position):
		_go_to_main()
		accept_event()
		return

	for i in range(DICTIONARY_TABS.size()):
		var rect := _get_dictionary_tab_rect(i)
		if rect.has_point(event.position):
			active_dictionary_category = DICTIONARY_TABS[i]["category"]
			queue_redraw()
			accept_event()
			return


func _focus_line(line_index: int) -> void:
	if line_edits.is_empty():
		return

	focused_line_index = clampi(line_index, 0, line_edits.size() - 1)
	var edit := line_edits[focused_line_index]
	edit.grab_focus()
	edit.caret_column = edit.text.length()
	queue_redraw()


func _apply_completion(line_index: int) -> void:
	var edit := line_edits[line_index]
	var completion := _get_completion_for_line(edit.text)
	if completion.is_empty():
		_focus_line(mini(line_index + 1, MAX_LINES - 1))
		return

	edit.text = completion
	edit.caret_column = edit.text.length()
	_validate_all()


func _validate_all() -> void:
	# SPEC: 空行は有効でコスト0。書きかけ行は、必要なスロットが埋まっていないため
	# GO を出さない。
	parsed_lines.clear()
	total_cost = 0
	syntax_error = false
	has_draft = false

	for edit in line_edits:
		var parsed := _parse_line(edit.text)
		parsed_lines.append(parsed)
		if parsed.get("draft", false):
			has_draft = true
		elif parsed.valid:
			total_cost += parsed.cost
		else:
			syntax_error = true

	over_capacity = total_cost > CAPACITY_LIMIT
	# SPEC: GO は、空行以外がすべて完成していて、合計コストが現在の容量内に
	# 収まっている時だけ表示する。
	program_ready = not syntax_error and not has_draft and not over_capacity
	if syntax_error:
		status_message = "存在しない構文です。"
	elif over_capacity:
		status_message = "容量上限を超えています！"
	elif has_draft:
		status_message = "未完成行があります。"
	else:
		status_message = "容量 %d/%d" % [total_cost, CAPACITY_LIMIT]

	queue_redraw()


func _collect_program_lines() -> Array[Dictionary]:
	var program: Array[Dictionary] = []
	for edit in line_edits:
		var line := edit.text.strip_edges().to_lower()
		if line.is_empty():
			continue

		# SPEC: 実行ログ用に元の1行テキストを保存する。Editor が source を渡さなくなる
		# までは、runtime 側でトークンから再構築しない。
		var tokens := line.split(" ", false)
		if tokens.size() == 3 and tokens[1] == "trail":
			program.append({
				"timing": tokens[0],
				"effect": tokens[1],
				"element": tokens[2],
				"source": line,
			})
		elif tokens.size() == 5:
			program.append({
				"timing": tokens[0],
				"effect": tokens[1],
				"target": tokens[2],
				"amount": int(tokens[3]),
				"element": tokens[4],
				"source": line,
			})
	return program


func _go_to_main() -> void:
	if not program_ready:
		return
	# SPEC: RunConfig は autoload の受け渡し場所。責務は意図的に薄くし、
	# Editor が検証し、main が受け取って実行する。
	RunConfig.set_program(_collect_program_lines())
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _parse_line(source: String) -> Dictionary:
	# SPEC: パーサーは valid / draft / invalid の3状態を返す。draft は
	# 「次のスロット」ヒント用で、容量には数えない。
	var line := source.strip_edges().to_lower()
	if line.is_empty():
		return {"valid": true, "draft": false, "cost": 0, "label": "empty", "detail": "", "next_slot": "timing"}

	var tokens := line.split(" ", false)
	var timing_state := _get_token_state(tokens[0], TIMINGS)
	if timing_state == "partial":
		return _draft_parse("timing")
	if timing_state == "invalid":
		return _invalid_parse("timing")
	if tokens.size() == 1:
		return _draft_parse("effect")

	var effect_state := _get_token_state(tokens[1], EFFECTS)
	if effect_state == "partial":
		return _draft_parse("effect")
	if effect_state == "invalid":
		return _invalid_parse("effect")

	var effect: String = tokens[1]
	if effect == "trail":
		return _parse_trail_effect(tokens)
	return _parse_target_value_effect(tokens, effect)


func _get_completion_for_line(source: String) -> String:
	var raw := source.to_lower()
	var trimmed := raw.strip_edges()
	var tokens := trimmed.split(" ", false) if not trimmed.is_empty() else PackedStringArray()
	var step := _get_completion_step(tokens, raw.ends_with(" "))
	var slot: String = step.get("slot", "")
	if slot.is_empty():
		return ""

	var completed_tokens: Array = []
	for token in tokens:
		completed_tokens.append(str(token))

	var completion_token := _get_completion_token(slot, completed_tokens)
	if bool(step.get("replace_last", false)) and not completed_tokens.is_empty():
		completed_tokens[completed_tokens.size() - 1] = completion_token
	else:
		completed_tokens.append(completion_token)

	var pieces := PackedStringArray()
	for token in completed_tokens:
		pieces.append(str(token))
	var result := " ".join(pieces)
	var parsed := _parse_line(result)
	if parsed.get("draft", false):
		result += " "
	return result


func _parse_trail_effect(tokens: PackedStringArray) -> Dictionary:
	# SPEC: trail は現在 target と number を省略する。実行時に前セルと現在セルへ
	# 効果を残すため、timing + trail + element だけでよい。
	if tokens.size() == 2:
		return _draft_parse("element")
	if tokens.size() > 3:
		return _invalid_parse("trail")

	var element_state := _get_token_state(tokens[2], ELEMENTS)
	if element_state == "partial":
		return _draft_parse("element")
	if element_state == "invalid":
		return _invalid_parse("element")
	return {"valid": true, "draft": false, "cost": 2 + _get_element_cost(tokens[2]), "label": "trail", "detail": tokens[2], "next_slot": ""}


func _parse_target_value_effect(tokens: PackedStringArray, effect: String) -> Dictionary:
	# SPEC: trail 以外の効果は target + number + element を必須にする。
	# スロットを差すようなガジェットプログラミング感を保つため。
	if tokens.size() == 2:
		return _draft_parse("target")
	if tokens.size() > 5:
		return _invalid_parse("overflow")

	var target_state := _get_token_state(tokens[2], TARGETS)
	if target_state == "partial":
		return _draft_parse("target")
	if target_state == "invalid":
		return _invalid_parse("target")
	if tokens.size() == 3:
		return _draft_parse("value")

	var target: String = tokens[2]
	var value := _parse_value_for_target(tokens[3], target)
	if not value.valid:
		return value

	var amount := int(tokens[3])
	if tokens.size() == 4:
		return _draft_parse("element")
	if tokens.size() > 5:
		return _invalid_parse("element")

	var element_state := _get_token_state(tokens[4], ELEMENTS)
	if element_state == "partial":
		return _draft_parse("element")
	if element_state == "invalid":
		return _invalid_parse("element")

	return {
		"valid": true,
		"draft": false,
		"cost": _get_effect_base_cost(effect) + amount + _get_element_cost(tokens[4]),
		"label": effect,
		"detail": "%s %d %s" % [target, amount, tokens[4]],
		"next_slot": "",
	}


func _parse_value_for_target(value: String, target: String) -> Dictionary:
	if not value.is_valid_int():
		return _invalid_parse("number")

	var amount := int(value)
	var maximum := _get_target_maximum(target)
	if amount < 1 or amount > maximum:
		return _invalid_parse("range")

	return {"valid": true}


func _get_token_state(token: String, options: Array) -> String:
	if options.has(token):
		return "exact"
	for option in options:
		var candidate := str(option)
		if candidate.begins_with(token):
			return "partial"
	return "invalid"


func _draft_parse(next_slot: String) -> Dictionary:
	return {"valid": true, "draft": true, "cost": 0, "label": "draft", "detail": "", "next_slot": next_slot}


func _invalid_parse(detail: String) -> Dictionary:
	return {"valid": false, "draft": false, "cost": 0, "label": "invalid", "detail": detail, "next_slot": ""}


func _get_effect_base_cost(effect: String) -> int:
	# SPEC: 効果の基本コストは、距離コストや属性コストと分けている。
	# ここを上げると汎用的な効果を容量内に収めにくくなる。
	match effect:
		"shock", "move":
			return 2
		_:
			return 0


func _get_element_cost(element: String) -> int:
	return int(ELEMENT_COSTS.get(element, 0))


func _get_target_maximum(target: String) -> int:
	# SPEC: front は方向指定が強いため遠くまで届かせる。around と side は小さな盤面で
	# 範囲が読みづらくならないよう上限を低くする。
	return 5 if target == "front" else 3


func _get_completion_step(tokens: PackedStringArray, ends_with_space: bool) -> Dictionary:
	# SPEC: 補完は入力中に勝手に埋める方式ではなく、スロット単位で行う。Tab は
	# 現在の途中トークンを置き換えるか、次に必要なスロットを追加する。
	if tokens.is_empty():
		return {"slot": "timing", "replace_last": false}

	if tokens.size() == 1:
		if not ends_with_space and _get_token_state(tokens[0], TIMINGS) == "partial":
			return {"slot": "timing", "replace_last": true}
		if _get_token_state(tokens[0], TIMINGS) == "exact":
			return {"slot": "effect", "replace_last": false}
		return {}

	if tokens.size() == 2:
		if not ends_with_space and _get_token_state(tokens[1], EFFECTS) == "partial":
			return {"slot": "effect", "replace_last": true}
		if _get_token_state(tokens[1], EFFECTS) != "exact":
			return {}
		return {"slot": "element" if tokens[1] == "trail" else "target", "replace_last": false}

	if tokens[1] == "trail":
		if tokens.size() == 3 and not ends_with_space and _get_token_state(tokens[2], ELEMENTS) == "partial":
			return {"slot": "element", "replace_last": true}
		return {}

	if tokens.size() == 3:
		if not ends_with_space and _get_token_state(tokens[2], TARGETS) == "partial":
			return {"slot": "target", "replace_last": true}
		if _get_token_state(tokens[2], TARGETS) == "exact":
			return {"slot": "value", "replace_last": false}
		return {}

	if tokens.size() == 4:
		if not tokens[3].is_valid_int():
			return {"slot": "value", "replace_last": true}
		if int(tokens[3]) >= 1 and int(tokens[3]) <= _get_target_maximum(tokens[2]):
			return {"slot": "element", "replace_last": false}
		return {}

	if tokens.size() == 5 and not ends_with_space:
		if _get_token_state(tokens[4], ELEMENTS) == "partial":
			return {"slot": "element", "replace_last": true}

	return {}


func _get_completion_token(slot: String, tokens: Array) -> String:
	var current := str(tokens[tokens.size() - 1]) if not tokens.is_empty() else ""
	var options := _get_slot_options(slot, tokens)
	for option in options:
		var candidate := str(option)
		if not current.is_empty() and candidate.begins_with(current):
			return candidate
	return str(options[0]) if not options.is_empty() else ""


func _get_slot_options(slot: String, tokens: Array) -> Array:
	match slot:
		"timing":
			return TIMINGS
		"effect":
			if not tokens.is_empty():
				match str(tokens[0]):
					"land":
						return ["shock", "hit", "trail"]
					"wall":
						return ["move", "hit", "trail"]
					_:
						return ["hit", "trail", "shock", "move"]
			return EFFECTS
		"target":
			if tokens.size() >= 2:
				match str(tokens[1]):
					"shock":
						return ["around", "front", "side"]
					"move":
						return ["side", "front", "around"]
					_:
						return ["front", "around", "side"]
			return TARGETS
		"value":
			return ["1"]
		"element":
			match str(tokens[1]) if tokens.size() >= 2 else "":
				"shock":
					return ["fire", "lightning", "ice", "poison", "normal"]
				"hit":
					return ["lightning", "fire", "ice", "poison", "normal"]
				_:
					return ["normal", "fire", "ice", "lightning", "poison"]
		_:
			return []


func _draw() -> void:
	_update_layout()
	_draw_backdrop()
	_draw_frame("shell", SHELL_POS)
	_draw_header()
	_draw_program_panel()
	_draw_memory_panel()
	_draw_output_panel()
	_draw_status()
	_draw_go_button()
	_draw_dictionary_modal()


func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("091012"))
	_draw_frame("backdrop", Vector2.ZERO)


func _draw_header() -> void:
	_draw_frame("panel_header", HEADER_POS)
	_draw_part("editor_panel_frame", Rect2(editor_origin + HEADER_POS + Vector2(24, 20), Vector2(56, 56)), false)
	_draw_part("gadget_editor_icon", Rect2(editor_origin + HEADER_POS + Vector2(958, 20), Vector2(56, 56)), false)

	draw_string(ThemeDB.fallback_font, editor_origin + HEADER_POS + Vector2(112, 38), "Small Gadget", HORIZONTAL_ALIGNMENT_LEFT, -1, 31, COLOR_TEXT)
	draw_string(ThemeDB.fallback_font, editor_origin + HEADER_POS + Vector2(114, 68), "PROGRAM MODULE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, COLOR_MUTED)

	var meter_pos := editor_origin + HEADER_POS + Vector2(708, 26)
	_draw_live_meter("meter_wide", meter_pos, total_cost, CAPACITY_LIMIT, over_capacity)
	draw_string(ThemeDB.fallback_font, meter_pos + Vector2(0, 56), "MEMORY %d/%d" % [total_cost, CAPACITY_LIMIT], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_RED if over_capacity else COLOR_TEXT)


func _draw_program_panel() -> void:
	_draw_frame("panel_program", PROGRAM_POS)
	draw_string(ThemeDB.fallback_font, editor_origin + PROGRAM_POS + Vector2(22, 34), "PROGRAM", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)
	draw_string(ThemeDB.fallback_font, editor_origin + PROGRAM_POS + Vector2(432, 34), "COST", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, COLOR_MUTED)

	for i in range(MAX_LINES):
		_draw_code_row(i)


func _draw_code_row(index: int) -> void:
	if index >= row_rects.size():
		return

	var parsed := parsed_lines[index] if index < parsed_lines.size() else {"valid": true, "cost": 0, "label": "empty"}
	var row_rect := row_rects[index]
	var row_frame := "row_normal"

	if not parsed.valid:
		row_frame = "row_error"
	elif focused_line_index == index:
		row_frame = "row_selected"

	_draw_frame_at(row_frame, row_rect.position)
	_draw_frame_at("input_field", row_rect.position + INPUT_FIELD_OFFSET)
	draw_string(ThemeDB.fallback_font, row_rect.position + LINE_NUMBER_OFFSET, "%d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, 24, 18, COLOR_MUTED)
	_draw_highlighted_line(index, row_rect)
	_draw_next_slot_hint(index, row_rect)

	var badge_name := "syntax_valid_badge" if parsed.valid else "syntax_error_badge"
	_draw_part(badge_name, Rect2(row_rect.position + BADGE_OFFSET, Vector2(44, 44)), true)
	_draw_line_capacity_slots(index, row_rect, parsed)


func _draw_highlighted_line(index: int, row_rect: Rect2) -> void:
	if index >= line_edits.size():
		return

	var text := line_edits[index].text
	if text.is_empty():
		if index != focused_line_index:
			draw_string(_get_code_font(), row_rect.position + EDIT_OFFSET + CODE_BASELINE_OFFSET, SAMPLE_LINES[index], HORIZONTAL_ALIGNMENT_LEFT, EDIT_SIZE.x, CODE_FONT_SIZE, COLOR_DIM)
		return

	var cursor := row_rect.position + EDIT_OFFSET + CODE_BASELINE_OFFSET
	for segment in _get_highlight_segments(text):
		var segment_text: String = segment["text"]
		var color: Color = segment["color"]
		draw_string(_get_code_font(), cursor, segment_text, HORIZONTAL_ALIGNMENT_LEFT, EDIT_SIZE.x - (cursor.x - (row_rect.position.x + EDIT_OFFSET.x)), CODE_FONT_SIZE, color)
		cursor.x += _get_code_font().get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_FONT_SIZE).x


func _get_highlight_segments(source: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var token := ""
	var token_index := 0

	for i in range(source.length()):
		var character := source.substr(i, 1)
		if character == " ":
			if not token.is_empty():
				segments.append({"text": token, "color": _get_token_color(token, token_index)})
				token_index += 1
				token = ""
			segments.append({"text": character, "color": COLOR_TEXT})
		else:
			token += character

	if not token.is_empty():
		segments.append({"text": token, "color": _get_token_color(token, token_index)})

	return segments


func _get_token_color(token: String, token_index: int) -> Color:
	var lower := token.to_lower()
	if ELEMENTS.has(lower):
		return COLOR_ELEMENT
	if lower.is_valid_int():
		return COLOR_VALUE
	match token_index:
		0:
			return COLOR_TRIGGER
		1:
			return COLOR_EFFECT
		2:
			return COLOR_TARGET
		3:
			return COLOR_RED
		_:
			return COLOR_RED


func _draw_next_slot_hint(index: int, row_rect: Rect2) -> void:
	if index != focused_line_index or index >= line_edits.size():
		return

	# SPEC: 色付きヒントはソケット枠だけ。ユーザーが入力した文字に見えるゴースト文字を
	# 入れず、次に必要なカテゴリだけを示す。
	var parsed := parsed_lines[index] if index < parsed_lines.size() else {}
	var next_slot := str(parsed.get("next_slot", ""))
	if next_slot.is_empty():
		return

	var edit := line_edits[index]
	var hint_label := _get_slot_hint_label(next_slot, edit.text)
	var text_width := _get_code_font().get_string_size(edit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_FONT_SIZE).x
	var slot_width := _get_slot_hint_width(next_slot, hint_label)
	var field_size := _get_frame_size("input_field")
	var field_right := row_rect.position.x + INPUT_FIELD_OFFSET.x + field_size.x - 9.0
	var gap := SLOT_HINT_GAP if not edit.text.strip_edges().is_empty() else 0.0
	var slot_pos := row_rect.position + Vector2(EDIT_OFFSET.x + text_width + gap, INPUT_FIELD_OFFSET.y + 7.0)
	var slot_rect := Rect2(slot_pos.round(), Vector2(slot_width, SLOT_HINT_HEIGHT))
	if slot_rect.position.x + slot_rect.size.x > field_right:
		slot_rect.position.x = field_right - slot_rect.size.x
	if slot_rect.position.x < row_rect.position.x + EDIT_OFFSET.x + text_width + 2.0:
		return

	_draw_slot_hint(slot_rect, next_slot, hint_label)


func _draw_line_capacity_slots(line_index: int, row_rect: Rect2, parsed: Dictionary) -> void:
	var cost := int(parsed.cost) if parsed.valid else 0
	var origin := row_rect.position + COST_SLOT_OFFSET
	if over_capacity:
		origin += _shake_offset(line_index)

	for slot in range(CAPACITY_LIMIT):
		var part_name := "capacity_unit_empty"
		if not parsed.valid:
			part_name = "capacity_unit_error"
		elif slot < cost:
			part_name = "capacity_unit_error" if over_capacity else "capacity_unit_filled"
		_draw_part(part_name, Rect2(origin + Vector2(slot * COST_SLOT_STEP, 0), COST_SLOT_SIZE), true)

	var number_rect := Rect2(row_rect.position + COST_NUMBER_OFFSET, COST_NUMBER_SIZE)
	if over_capacity:
		number_rect.position += _shake_offset(line_index)
	var number_frame := "cost_number_error" if not parsed.valid or over_capacity else "cost_number_normal"
	_draw_frame_at(number_frame, number_rect.position)
	draw_string(ThemeDB.fallback_font, number_rect.position + Vector2(2, 24), "%d/%d" % [cost, CAPACITY_LIMIT], HORIZONTAL_ALIGNMENT_RIGHT, 32, 18, COLOR_RED if not parsed.valid or over_capacity else COLOR_TEXT)


func _draw_memory_panel() -> void:
	_draw_frame("panel_memory", MEMORY_POS)
	draw_string(ThemeDB.fallback_font, editor_origin + MEMORY_POS + Vector2(22, 34), "GADGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXT)

	_draw_part("gadget_editor_icon", Rect2(editor_origin + MEMORY_POS + Vector2(36, 64), Vector2(112, 112)), true)

	var meter_pos := editor_origin + MEMORY_POS + Vector2(164, 82)
	_draw_live_meter("meter_small", meter_pos, total_cost, CAPACITY_LIMIT, over_capacity)
	draw_string(ThemeDB.fallback_font, meter_pos + Vector2(0, 58), "%d / %d" % [total_cost, CAPACITY_LIMIT], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, COLOR_RED if over_capacity else COLOR_TEXT)
	draw_string(ThemeDB.fallback_font, meter_pos + Vector2(0, 80), "CAPACITY LIMIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_MUTED)

	var summary_origin := editor_origin + MEMORY_POS + Vector2(26, 202)
	draw_string(ThemeDB.fallback_font, summary_origin, "OUTPUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TEXT)
	for i in range(MAX_LINES):
		var parsed := parsed_lines[i] if i < parsed_lines.size() else {"valid": true, "label": "empty", "detail": "", "cost": 0}
		var y := summary_origin.y + 30 + i * 28
		var color := COLOR_RED if not parsed.valid else COLOR_MUTED
		var label := "%d  %s  cost %d" % [i + 1, parsed.label, int(parsed.cost)]
		if parsed.label != "empty":
			label = "%d  %s  %s  cost %d" % [i + 1, parsed.label, parsed.detail, int(parsed.cost)]
		draw_string(ThemeDB.fallback_font, Vector2(summary_origin.x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 260, 15, color)


func _draw_output_panel() -> void:
	_draw_frame("panel_output", OUTPUT_POS)
	draw_string(ThemeDB.fallback_font, editor_origin + OUTPUT_POS + Vector2(18, 24), "CODE DICTIONARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_MUTED)

	for i in range(DICTIONARY_TABS.size()):
		var tab: Dictionary = DICTIONARY_TABS[i]
		var tab_rect := _get_dictionary_tab_rect(i)
		var category: String = tab["category"]
		var category_color := _get_syntax_category_color(category)
		_draw_frame_at(tab["frame"], tab_rect.position)
		draw_rect(tab_rect, category_color, false, 1.0)
		draw_rect(Rect2(tab_rect.position + Vector2(8, 6), Vector2(6, tab_rect.size.y - 12)), category_color)
		draw_string(ThemeDB.fallback_font, tab_rect.position + Vector2(24, 22), tab["label"], HORIZONTAL_ALIGNMENT_LEFT, tab_rect.size.x - 32, DICTIONARY_TAB_FONT_SIZE, category_color)
		if active_dictionary_category == category:
			draw_rect(tab_rect.grow(-2.0), category_color, false, 2.0)


func _draw_status() -> void:
	var blocked := syntax_error or over_capacity or has_draft
	var status_frame := "status_error" if blocked else "status_normal"
	var color := COLOR_RED if blocked else COLOR_TEAL
	var status_pos := editor_origin + OUTPUT_POS + STATUS_OFFSET
	_draw_frame_at(status_frame, status_pos)
	draw_string(_get_japanese_font(), status_pos + STATUS_TEXT_OFFSET, status_message, HORIZONTAL_ALIGNMENT_LEFT, STATUS_TEXT_WIDTH, STATUS_FONT_SIZE, color)


func _draw_go_button() -> void:
	if not program_ready:
		return

	var rect := _get_go_button_rect()
	var pulse := (sin(go_time * TAU * 1.65) + 1.0) * 0.5
	var jitter := Vector2(round(sin(go_time * 24.0) * 1.0), 0.0)
	rect.position += jitter

	var fill := COLOR_GO_DARK
	fill.a = 0.72 + pulse * 0.16
	var border := COLOR_GO
	border.a = 0.86 + pulse * 0.14
	var glow := COLOR_GO
	glow.a = 0.16 + pulse * 0.22

	draw_rect(rect.grow(4.0), glow)
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 2.0)
	draw_rect(rect.grow(-4.0), Color(border.r, border.g, border.b, 0.28), false, 1.0)
	_draw_centered_string(ThemeDB.fallback_font, rect, "GO", 24, COLOR_TEXT)


func _draw_dictionary_modal() -> void:
	if active_dictionary_category.is_empty():
		return

	var modal_rect := _get_dictionary_modal_rect()
	var title := _get_dictionary_title(active_dictionary_category)
	var category_color := _get_syntax_category_color(active_dictionary_category)

	draw_rect(Rect2(Vector2.ZERO, size), COLOR_MODAL_BACKDROP)
	draw_rect(modal_rect, COLOR_MODAL_PANEL)
	draw_rect(modal_rect, category_color, false, 2.0)
	draw_rect(modal_rect.grow(-5.0), COLOR_MODAL_INNER, false, 1.0)

	draw_string(ThemeDB.fallback_font, modal_rect.position + Vector2(24, 40), "CODE DICTIONARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_MUTED)
	draw_string(ThemeDB.fallback_font, modal_rect.position + Vector2(24, 70), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, category_color)

	var close_rect := _get_dictionary_close_rect()
	draw_rect(close_rect, Color(0.04, 0.08, 0.08, 0.98))
	draw_rect(close_rect, category_color, false, 1.0)
	_draw_centered_string(ThemeDB.fallback_font, close_rect, "X", 15, COLOR_TEXT)

	var header_y := 110.0
	draw_string(_get_japanese_font(), modal_rect.position + Vector2(32, header_y), "構文", HORIZONTAL_ALIGNMENT_LEFT, -1, JAPANESE_FONT_SIZE, COLOR_MUTED)
	draw_string(_get_japanese_font(), modal_rect.position + Vector2(238, header_y), "説明", HORIZONTAL_ALIGNMENT_LEFT, -1, JAPANESE_FONT_SIZE, COLOR_MUTED)
	draw_line(modal_rect.position + Vector2(24, header_y + 13.0), modal_rect.position + Vector2(modal_rect.size.x - 24.0, header_y + 13.0), Color(0.2, 0.42, 0.4, 0.55), 1.0)

	var entries: Array = CODE_DICTIONARY.get(active_dictionary_category, [])
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var row_y := 146.0 + float(i) * 44.0
		var term_rect := Rect2(modal_rect.position + Vector2(30, row_y - 23.0), Vector2(170, 30))
		draw_rect(term_rect, Color(0.015, 0.025, 0.028, 0.96))
		draw_rect(term_rect, Color(0.18, 0.38, 0.36, 0.85), false, 1.0)
		_draw_dictionary_segments(term_rect.position + Vector2(10, 22), entry["segments"])
		draw_string(_get_japanese_font(), modal_rect.position + Vector2(238, row_y), entry["description"], HORIZONTAL_ALIGNMENT_LEFT, modal_rect.size.x - 270.0, JAPANESE_FONT_SIZE, COLOR_TEXT)


func _draw_live_meter(frame_name: String, position: Vector2, used: int, limit: int, is_error: bool) -> void:
	# SPEC: 容量メーターは正確な整数スロットとして描く。ここでは小数のバー表現を避け、
	# 離散的なメモリブロックとして読ませる。
	var meter_pos := position
	if is_error:
		meter_pos += _shake_offset(10)

	_draw_frame_at(frame_name, meter_pos)

	var frame_size := _get_frame_size(frame_name)
	var padding := 4.0
	var gap := 2.0
	var slot_height := frame_size.y - padding * 2.0
	var slot_width := floorf((frame_size.x - padding * 2.0 - gap * float(limit - 1)) / float(limit))
	var slot_origin := meter_pos + Vector2(padding, padding)
	for i in range(limit):
		var slot_rect := Rect2(slot_origin + Vector2(i * (slot_width + gap), 0), Vector2(slot_width, slot_height))
		var fill := COLOR_SLOT_EMPTY
		if i < used:
			fill = COLOR_RED if is_error else COLOR_TEAL
		draw_rect(slot_rect, fill)
		draw_rect(slot_rect, COLOR_RED_DARK if is_error else COLOR_TEAL_DARK, false, 1.0)


func _draw_frame(name: String, design_position: Vector2) -> void:
	_draw_frame_at(name, editor_origin + design_position)


func _draw_frame_at(name: String, position: Vector2) -> void:
	var texture := frames.get(name) as Texture2D
	if texture == null:
		return
	draw_texture(texture, position.floor())


func _draw_part(name: String, area: Rect2, allow_upscale: bool) -> void:
	var texture := parts.get(name) as Texture2D
	if texture == null:
		return

	var texture_size := texture.get_size()
	var scale := minf(area.size.x / texture_size.x, area.size.y / texture_size.y)
	if not allow_upscale:
		scale = minf(scale, 1.0)
	var target_size := (texture_size * scale).floor()
	var target := Rect2((area.position + (area.size - target_size) * 0.5).floor(), target_size)
	draw_texture_rect(texture, target, false)


func _get_frame_size(name: String) -> Vector2:
	var texture := frames.get(name) as Texture2D
	if texture == null:
		return Vector2.ZERO
	return texture.get_size()


func _draw_dictionary_segments(position: Vector2, segments: Array) -> void:
	var cursor := position
	for segment in segments:
		var segment_text: String = segment["text"]
		var kind: String = segment["kind"]
		var color := _get_syntax_category_color(kind)
		draw_string(_get_code_font(), cursor, segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_FONT_SIZE, color)
		cursor.x += _get_code_font().get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_FONT_SIZE).x


func _draw_slot_hint(slot_rect: Rect2, slot: String, hint_label: String = "") -> void:
	var color := _get_syntax_category_color(slot)
	var fill := color
	var inner := color
	fill.a = 0.08
	inner.a = 0.18
	color.a = 0.82

	draw_rect(slot_rect, fill)
	draw_rect(slot_rect, color, false, 1.0)
	draw_rect(slot_rect.grow(-4.0), inner, false, 1.0)

	var notch_y := slot_rect.position.y + floorf(slot_rect.size.y * 0.5)
	draw_line(Vector2(slot_rect.position.x + 2.0, notch_y), Vector2(slot_rect.position.x + 8.0, notch_y), color, 1.0)
	draw_line(Vector2(slot_rect.end.x - 8.0, notch_y), Vector2(slot_rect.end.x - 2.0, notch_y), color, 1.0)

	if not hint_label.is_empty():
		var text_color := color
		text_color.a = 0.46
		_draw_centered_string(_get_code_font(), slot_rect, hint_label, 20, text_color)


func _get_slot_hint_width(slot: String, hint_label: String = "") -> float:
	match slot:
		"value":
			var label_width := _get_code_font().get_string_size(hint_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			return maxf(44.0, label_width + 16.0)
		"element":
			return 82.0
		_:
			return 64.0


func _get_slot_hint_label(slot: String, source: String) -> String:
	if slot != "value":
		return ""

	var tokens := source.strip_edges().to_lower().split(" ", false)
	if tokens.size() >= 3 and TARGETS.has(tokens[2]):
		return "1-%d" % _get_target_maximum(tokens[2])
	return "n"


func _draw_centered_string(font: Font, rect: Rect2, text: String, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_height := font.get_height(font_size)
	var baseline := rect.position + Vector2(
		(rect.size.x - text_size.x) * 0.5,
		(rect.size.y - text_height) * 0.5 + font.get_ascent(font_size)
	)
	draw_string(font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _get_syntax_category_color(category: String) -> Color:
	match category:
		"trigger", "timing":
			return COLOR_TRIGGER
		"effect":
			return COLOR_EFFECT
		"target":
			return COLOR_TARGET
		"element":
			return COLOR_ELEMENT
		"value":
			return COLOR_VALUE
		_:
			return COLOR_TEXT


func _get_dictionary_title(category: String) -> String:
	match category:
		"timing":
			return "Timing"
		"effect":
			return "Effect"
		"target":
			return "Target"
		"value":
			return "Number"
		"element":
			return "Element"
		_:
			return "Dictionary"


func _get_dictionary_tab_rect(index: int) -> Rect2:
	var chip_pos := editor_origin + OUTPUT_POS + Vector2(18, 34)
	for i in range(index):
		chip_pos.x += _get_frame_size(DICTIONARY_TABS[i]["frame"]).x + 10
	return Rect2(chip_pos, _get_frame_size(DICTIONARY_TABS[index]["frame"]))


func _get_dictionary_modal_rect() -> Rect2:
	return Rect2((size - DICTIONARY_MODAL_SIZE) * 0.5, DICTIONARY_MODAL_SIZE)


func _get_dictionary_close_rect() -> Rect2:
	var modal_rect := _get_dictionary_modal_rect()
	return Rect2(modal_rect.position + Vector2(modal_rect.size.x - DICTIONARY_CLOSE_SIZE.x - 18.0, 18.0), DICTIONARY_CLOSE_SIZE)


func _get_go_button_rect() -> Rect2:
	return Rect2(editor_origin + OUTPUT_POS + GO_BUTTON_OFFSET, GO_BUTTON_SIZE)


func _shake_offset(seed: int) -> Vector2:
	return Vector2(sin(shake_time * 48.0 + float(seed) * 1.73) * 4.0, 0.0).round()
