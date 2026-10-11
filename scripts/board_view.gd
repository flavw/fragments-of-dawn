extends Control
## Draw tiles edge-to-edge, masking only edges that are not joined.
## Masking rather than shrinking textures keeps joined pixels aligned.
signal slot_pressed(slot: int)
signal tutorial_finished
var tutorial_active := false
var tutorial_slots := Vector2i(-1, -1)
var tutorial_second := false
var tutorial_amount := 0.0
var texture: Texture2D
var board: RefCounted
var selected := -1
const N := 4
const GAP := 3.0
var finishing := false
var finish_edges: Array = []
var gap_opacity := 1.0:
	set(value):
		gap_opacity = value
		queue_redraw()

func remember_gaps() -> void:
	finish_edges.clear()
	for slot in range(16):
		for other in [slot + 1, slot + N]:
			if other < 16 and (other == slot + N or slot % N < N - 1) and not joined(slot, other):
				finish_edges.append(Vector2i(slot, other))

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func joined(a: int, b: int) -> bool:
	return board.joined(a, b)

func _gui_input(event: InputEvent) -> void:
	if tutorial_active:
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := size / float(N)
		var col := clampi(int(event.position.x / cell.x), 0, N - 1)
		var row := clampi(int(event.position.y / cell.y), 0, N - 1)
		slot_pressed.emit(row * N + col)
		accept_event()

func _draw() -> void:
	if texture == null or board == null: return
	var cell := size / float(N)
	var source := Vector2(texture.get_size()) / float(N)
	for slot in range(N * N):
		if tutorial_active and tutorial_amount > 0.0 and slot in [tutorial_slots.x, tutorial_slots.y]: continue
		var piece: int = board.pieces[slot]
		var dest := Rect2(Vector2(slot % N, slot / N) * cell, cell)
		var region := Rect2(Vector2(piece % N, piece / N) * source, source)
		draw_texture_rect_region(texture, dest, region)
	var gap_color := Color("111b2b")
	if finishing: gap_color.a = gap_opacity
	for slot in range(N * N):
		var x := slot % N
		var y := slot / N
		if x < N - 1 and ((finishing and Vector2i(slot, slot + 1) in finish_edges) or not joined(slot, slot + 1)):
			draw_line(Vector2((x + 1) * cell.x, y * cell.y), Vector2((x + 1) * cell.x, (y + 1) * cell.y), gap_color, GAP)
		if y < N - 1 and ((finishing and Vector2i(slot, slot + N) in finish_edges) or not joined(slot, slot + N)):
			draw_line(Vector2(x * cell.x, (y + 1) * cell.y), Vector2((x + 1) * cell.x, (y + 1) * cell.y), gap_color, GAP)
	if selected >= 0:
		var box := Rect2(Vector2(selected % N, selected / N) * cell, cell).grow(-2)
		draw_rect(box, Color("fff0a4"), false, 3)
	if tutorial_active:
		for index in range(2 if tutorial_second else 1):
			var slot := tutorial_slots[index]
			var other := tutorial_slots[1 - index]
			var origin := Vector2(slot % N, slot / N) * cell
			var target := Vector2(other % N, other / N) * cell
			var box := Rect2(origin.lerp(target, tutorial_amount), cell)
			if tutorial_amount > 0.0:
				var piece: int = board.pieces[slot]
				draw_texture_rect_region(texture, box, Rect2(Vector2(piece % N, piece / N) * source, source))
			draw_rect(box.grow(-2), Color(1.0, 0.85, 0.4, 0.16))
			draw_rect(box.grow(-2), Color("ffe096"), false, 3.0)

func demonstrate_swap() -> void:
	tutorial_active = true
	var first := 0
	for slot in range(16):
		if board.pieces[slot] != slot:
			first = slot
			break
	tutorial_slots = Vector2i(first, board.pieces.find(first))
	# A returning player may have only one swap left. Keep that final move
	# for the player so the demonstration cannot bypass the victory flow.
	var preview: Array = board.pieces.duplicate()
	var previous: int = preview[tutorial_slots.x]
	preview[tutorial_slots.x] = preview[tutorial_slots.y]
	preview[tutorial_slots.y] = previous
	if preview == range(16):
		for slot in range(16):
			if slot not in [tutorial_slots.x, tutorial_slots.y]:
				tutorial_slots.y = slot
				break
	queue_redraw()
	var demonstration := create_tween()
	demonstration.tween_interval(0.9)
	demonstration.tween_callback(func():
		tutorial_second = true
		queue_redraw()
	)
	demonstration.tween_interval(0.9)
	demonstration.tween_method(func(amount: float):
		tutorial_amount = amount
		queue_redraw()
	, 0.0, 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	demonstration.tween_callback(func():
		var piece: int = board.pieces[tutorial_slots.x]
		board.pieces[tutorial_slots.x] = board.pieces[tutorial_slots.y]
		board.pieces[tutorial_slots.y] = piece
		tutorial_amount = 0.0
		queue_redraw()
	)
	demonstration.tween_interval(1.1)
	demonstration.tween_callback(func():
		tutorial_active = false
		queue_redraw()
		tutorial_finished.emit()
	)
