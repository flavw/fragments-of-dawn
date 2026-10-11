extends Control
signal tapped
signal zoomed
## Independent viewport: pinch, wheel and dragging never scroll the gallery page.
var texture: Texture2D
var zoom := 1.0
var pan := Vector2.ZERO
var touches: Dictionary = {}
var dragging := false
var tap_start := Vector2.ZERO
var tap_time := 0
var tap_cancelled := false
const TAP_DISTANCE := 12.0

func begin_tap(point: Vector2) -> void:
	tap_start = point
	tap_time = Time.get_ticks_msec()
	tap_cancelled = false

func finish_tap(point: Vector2) -> void:
	if not tap_cancelled and point.distance_to(tap_start) <= TAP_DISTANCE and Time.get_ticks_msec() - tap_time < 350:
		tapped.emit()
	tap_cancelled = true
const MAX_ZOOM := 5.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func(): clamp_pan(); queue_redraw())

func fitted_size() -> Vector2:
	if texture == null: return Vector2.ONE
	var source := Vector2(texture.get_size())
	return source * minf(size.x / source.x, size.y / source.y)

func clamp_pan() -> void:
	var limit := (fitted_size() * zoom - size).max(Vector2.ZERO) / 2.0
	pan = pan.clamp(-limit, limit)

func zoom_at(factor: float, anchor: Vector2) -> void:
	var next := clampf(zoom * factor, 1.0, MAX_ZOOM)
	pan = anchor - size / 2.0 - (anchor - size / 2.0 - pan) * (next / zoom)
	zoom = next
	if zoom > 1.0: zoomed.emit()
	clamp_pan()
	queue_redraw()

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	draw_style_box(panel_style(), Rect2(Vector2.ZERO, size))
	if texture:
		var image_size := fitted_size() * zoom
		draw_texture_rect(texture, Rect2((size - image_size) / 2.0 + pan, image_size), false)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111b2b")
	return style

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if not touches.is_empty():
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_at(1.2, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_at(1.0 / 1.2, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: begin_tap(event.position)
			elif dragging: finish_tap(event.position)
			dragging = event.pressed
			if event.double_click:
				tap_cancelled = true
				reset_view()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(tap_start) > TAP_DISTANCE: tap_cancelled = true
		pan += event.relative
		clamp_pan()
		queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and Rect2(Vector2.ZERO, size).has_point(point):
			if touches.is_empty(): begin_tap(point)
			else: tap_cancelled = true
			touches[event.index] = point
			dragging = false
			if event.double_tap:
				tap_cancelled = true
				reset_view()
			get_viewport().set_input_as_handled()
		elif not event.pressed and touches.has(event.index):
			touches.erase(event.index)
			if touches.is_empty(): finish_tap(point)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var old: Vector2 = touches[event.index]
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if point.distance_to(tap_start) > TAP_DISTANCE: tap_cancelled = true
		if touches.size() == 1:
			pan += point - old
		else:
			var other: Vector2 = old
			for index in touches:
				if index != event.index:
					other = touches[index]
					break
			var old_center := (old + other) / 2.0
			var new_center: Vector2 = (point + other) / 2.0
			zoom_at(point.distance_to(other) / maxf(1.0, old.distance_to(other)), old_center)
			pan += new_center - old_center
		touches[event.index] = point
		clamp_pan()
		queue_redraw()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		touches.clear()
		dragging = false
		tap_cancelled = true
