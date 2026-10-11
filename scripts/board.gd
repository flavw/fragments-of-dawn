extends RefCounted
const N := 4
var pieces: Array = []
var moves := 0
var initial_minimum := -1
var last_error := ""

func start(_n: int = 4, saved: Dictionary = {}) -> void:
	pieces = range(16)
	moves = 0
	initial_minimum = -1
	var old = saved.get("pieces", [])
	if valid_permutation(old):
		pieces = old.map(func(v): return int(v))
		moves = maxi(0, int(saved.get("moves", 0)))
		initial_minimum = int(saved.get("initial_minimum", -1))
		return
	var attempts := 0
	while (solved() or adjacent_pair_count() > 0) and attempts < 500:
		pieces.shuffle()
		attempts += 1
	if solved() or adjacent_pair_count() > 0:
		pieces = [1, 3, 5, 7, 9, 11, 13, 15, 0, 2, 4, 6, 8, 10, 12, 14]
	initial_minimum = minimum_swaps()

func minimum_swaps() -> int:
	# A permutation cycle of length k takes exactly k - 1 swaps to solve.
	var visited := {}
	var cycles := 0
	for slot in range(pieces.size()):
		if visited.has(slot): continue
		cycles += 1
		var cursor: int = slot
		while not visited.has(cursor):
			visited[cursor] = true
			cursor = int(pieces[cursor])
	return pieces.size() - cycles

func valid_permutation(value: Variant) -> bool:
	if not value is Array or value.size() != 16: return false
	var normalized: Array = value.map(func(v): return int(v))
	normalized.sort()
	return normalized == range(16)

func coord(slot: int) -> Vector2i:
	return Vector2i(slot % N, slot / N)

func joined(a: int, b: int) -> bool:
	return adjacent_pair(a, b) and pieces[a] == a and pieces[b] == b

func adjacent_pair(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= 16 or b >= 16: return false
	var delta := coord(b) - coord(a)
	return absi(delta.x) + absi(delta.y) == 1 and coord(pieces[b]) - coord(pieces[a]) == delta

func swap(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= 16 or b >= 16: return false
	var previous = pieces[a]
	pieces[a] = pieces[b]
	pieces[b] = previous
	moves += 1
	return true

func bond_count() -> int:
	var count := 0
	for slot in range(16):
		for other in [slot + 1, slot + N]:
			if joined(slot, other): count += 1
	return count

func adjacent_pair_count() -> int:
	var count := 0
	for slot in range(16):
		for other in [slot + 1, slot + N]:
			if adjacent_pair(slot, other): count += 1
	return count

func solved() -> bool:
	return pieces == range(16)
