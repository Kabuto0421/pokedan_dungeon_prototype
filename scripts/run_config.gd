extends Node

# SPEC: RunConfig は editor.tscn から main.tscn へ渡すための autoload。
# editor.tscn が検証を担当し、main.tscn はこの辞書配列を次の実行用の
# ガジェットコードとして扱う。
var has_editor_program := false
var program_lines: Array[Dictionary] = []

func set_program(lines: Array[Dictionary]) -> void:
	# SPEC: 後続の Editor 編集が実行中データを変えないよう、深い複製で保存する。
	program_lines = lines.duplicate(true)
	has_editor_program = true

func clear_program() -> void:
	# SPEC: clear 後は、main.tscn を直接起動した時や将来のリセット導線で
	# DEFAULT_PROGRAM_LINES に戻る。
	program_lines.clear()
	has_editor_program = false

func get_program_lines() -> Array[Dictionary]:
	return program_lines.duplicate(true)
