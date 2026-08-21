class_name ShogiKingMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 王はすべての隣接セルへ進む。
	configure(
		"king",
		"King",
		"K",
		[
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
		],
		[]
	)
