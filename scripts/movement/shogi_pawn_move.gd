class_name ShogiPawnMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 歩は前方1マスに進む。ハンマーの初期移動。
	configure(
		"pawn",
		"Pawn",
		"P",
		[Vector2i(0, -1)],
		[]
	)
