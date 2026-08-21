class_name ShogiHorseMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 馬は角の斜め直線移動に、上下左右1マス移動を足したもの。
	configure(
		"horse",
		"Horse",
		"+B",
		[
			Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(1, 0), Vector2i(0, 1),
		],
		[
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1),
		]
	)
