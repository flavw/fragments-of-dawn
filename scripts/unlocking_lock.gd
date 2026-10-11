extends Control

var opening := 0.0

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / 48.0)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("202130")
	backdrop.border_color = Color("d5b478")
	backdrop.set_border_width_all(2)
	backdrop.set_corner_radius_all(14)
	backdrop.shadow_color = Color(1.0, 0.70, 0.22, opening * 0.6)
	backdrop.shadow_size = int(opening * 8)
	draw_style_box(backdrop, Rect2(4, 4, 40, 40))
	var points := PackedVector2Array([Vector2(16, 23)])
	for i in range(25):
		var angle := PI + PI * float(i) / 24.0
		points.append(Vector2(24, 17) + Vector2(cos(angle), sin(angle)) * 8)
	points.append(Vector2(32, 23))
	for i in range(points.size()):
		points[i] = Vector2(32, 23) + (points[i] - Vector2(32, 23)).rotated(opening * 0.55) + Vector2(0, -opening * 3)
	draw_polyline(points, Color("f3d59a"), 3, true)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("d5b478")
	body.set_corner_radius_all(4)
	draw_style_box(body, Rect2(13, 21, 22, 17))
	draw_circle(Vector2(24, 28), 3, Color("202130"))
	draw_line(Vector2(24, 29), Vector2(24, 34), Color("202130"), 3, true)

func set_opening(value: float) -> void:
	opening = value
	queue_redraw()
