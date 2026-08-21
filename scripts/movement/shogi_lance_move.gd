class_name ShogiLanceMove
extends "res://scripts/movement/shogi_move_pattern.gd"

func _init() -> void:
	# SPEC: 香車は遮蔽されるまで前方へ直線移動する。
	configure(
		"lance",
		"Lance",
		"L",
		[],
		[Vector2i(0, -1)]
	)
