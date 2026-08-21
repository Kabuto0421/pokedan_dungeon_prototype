class_name ShogiPromotedKnightMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 成桂は金と同じ移動を使う。
	configure(
		"promoted_knight",
		"Promoted Knight",
		"+N",
		[
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(0, 1),
		],
		[]
	)
