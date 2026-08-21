class_name ShogiRookMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 飛車は遮蔽されるまで上下左右へ直線移動する。
	configure(
		"rook",
		"Rook",
		"R",
		[],
		[
			Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(1, 0), Vector2i(0, 1),
		]
	)
