class_name ShogiMoveSet
extends RefCounted

# SPEC: この登録クラスは、対応済みの将棋移動パターンをすべて保持する。
# 実行時に DungeonPlayer が選ぶのは武器に対応するものだけだが、全種類を用意しておくと
# 将来の武器追加時に移動ロジックを書き直さずに済む。
const KingMove := preload("res://scripts/movement/shogi_king_move.gd")
const GoldMove := preload("res://scripts/movement/shogi_gold_move.gd")
const SilverMove := preload("res://scripts/movement/shogi_silver_move.gd")
const PawnMove := preload("res://scripts/movement/shogi_pawn_move.gd")
const LanceMove := preload("res://scripts/movement/shogi_lance_move.gd")
const KnightMove := preload("res://scripts/movement/shogi_knight_move.gd")
const BishopMove := preload("res://scripts/movement/shogi_bishop_move.gd")
const RookMove := preload("res://scripts/movement/shogi_rook_move.gd")
const PromotedPawnMove := preload("res://scripts/movement/shogi_promoted_pawn_move.gd")
const PromotedLanceMove := preload("res://scripts/movement/shogi_promoted_lance_move.gd")
const PromotedKnightMove := preload("res://scripts/movement/shogi_promoted_knight_move.gd")
const PromotedSilverMove := preload("res://scripts/movement/shogi_promoted_silver_move.gd")
const HorseMove := preload("res://scripts/movement/shogi_horse_move.gd")
const DragonMove := preload("res://scripts/movement/shogi_dragon_move.gd")

static func create_all() -> Array:
	# SPEC: クラスではなくインスタンスを返す。DungeonPlayer は選択中パターンを保持し、
	# 更新ごとに get_destinations を呼ぶ。
	return [
		KingMove.new(),
		GoldMove.new(),
		SilverMove.new(),
		PawnMove.new(),
		LanceMove.new(),
		KnightMove.new(),
		BishopMove.new(),
		RookMove.new(),
		PromotedPawnMove.new(),
		PromotedLanceMove.new(),
		PromotedKnightMove.new(),
		PromotedSilverMove.new(),
		HorseMove.new(),
		DragonMove.new(),
	]
