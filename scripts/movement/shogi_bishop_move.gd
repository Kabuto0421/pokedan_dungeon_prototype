class_name ShogiBishopMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 角は遮蔽されるまで斜め方向へ直線移動する。
	configure(
		"bishop",
		"Bishop",
		"B",
		[],
		[
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1),
		]
	)
