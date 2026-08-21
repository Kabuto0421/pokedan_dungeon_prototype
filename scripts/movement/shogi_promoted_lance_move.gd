class_name ShogiPromotedLanceMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 成香は金と同じ移動を使う。
	configure(
		"promoted_lance",
		"Promoted Lance",
		"+L",
		[
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(0, 1),
		],
		[]
	)
