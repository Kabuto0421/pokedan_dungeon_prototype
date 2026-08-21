class_name ShogiDragonMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 龍は飛車の上下左右直線移動に、斜め1マス移動を足したもの。
	configure(
		"dragon",
		"Dragon",
		"+R",
		[
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1),
		],
		[
			Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(1, 0), Vector2i(0, 1),
		]
	)
