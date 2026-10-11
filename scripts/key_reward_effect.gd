extends CanvasLayer
## Brief, non-blocking celebration; reuses the wallet artwork.
const KEY = preload("res://art/dawn-ui/wallet-key.tres")
var caption := "+1 key"
signal arrived
var flight_target: Control

class Glow extends Control:
	var shimmer := 0.0:
		set(value):
			shimmer = value
			queue_redraw()
	func _draw() -> void:
		var center := Vector2(110, 110)
		for ring in range(12, 0, -1):
			draw_circle(center, float(ring) * 9.0, Color(1.0, 0.76, 0.30, 0.018))
		for index in range(8):
			var angle := TAU * float(index) / 8.0 + 0.2
			var point := center + Vector2.from_angle(angle) * (75.0 + shimmer * 22.0)
			var length := 3.0 + 4.0 * sin(PI * shimmer)
			var color := Color(1.0, 0.88, 0.57, sin(PI * shimmer))
			draw_line(point - Vector2(length, 0), point + Vector2(length, 0), color, 2.0, true)
			draw_line(point - Vector2(0, length), point + Vector2(0, length), color, 2.0, true)

func _ready() -> void:
	layer = 21
	add_to_group("key_reward_effect")
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := Control.new()
	content.size = Vector2(220, 270)
	content.pivot_offset = Vector2(110, 135)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(content)
	var center_content := func(): content.position = (stage.size - content.size) * 0.5
	stage.resized.connect(center_content)
	center_content.call()
	var glow := Glow.new()
	glow.size = Vector2(220, 220)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(glow)
	var key := TextureRect.new()
	key.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key.texture = KEY
	key.position = Vector2(30, 30)
	key.size = Vector2(160, 160)
	key.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(key)
	var text := Label.new()
	text.text = caption
	text.position = Vector2(0, 213)
	text.size = Vector2(220, 44)
	if is_instance_valid(flight_target):
		text.size = Vector2(300, 80)
		text.position.x = -40
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", preload("res://fonts/Carlito-Bold.ttf"))
	text.add_theme_font_size_override("font_size", 28)
	if is_instance_valid(flight_target): text.add_theme_font_size_override("font_size", 20)
	text.add_theme_color_override("font_color", Color("ffe4ad"))
	text.add_theme_color_override("font_shadow_color", Color("141923"))
	text.add_theme_constant_override("shadow_outline_size", 5)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text)
	content.modulate.a = 0.0
	content.scale = Vector2.ONE * 0.65
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(content, "modulate:a", 1.0, 0.25)
	tween.tween_property(content, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "shimmer", 1.0, 2.2)
	tween.tween_property(key, "modulate", Color(1.2, 1.1, 0.9), 0.3).set_delay(0.3)
	tween.tween_property(key, "modulate", Color.WHITE, 0.5).set_delay(0.6)
	if is_instance_valid(flight_target):
		tween.chain().tween_callback(func():
			stage.resized.disconnect(center_content)
			content.pivot_offset = Vector2(110, 110)
			var start := content.position
			var flight := create_tween().set_parallel(true)
			flight.tween_method(func(amount: float):
				if not is_instance_valid(flight_target): return
				var destination: Vector2 = stage.get_global_transform().affine_inverse() * flight_target.get_global_rect().get_center() - Vector2(110, 110)
				var bend := Vector2(destination.x, start.y - 80)
				content.position = start.lerp(bend, amount).lerp(bend.lerp(destination, amount), amount)
			, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			flight.tween_property(content, "scale", Vector2.ONE * 0.18, 0.9)
			flight.tween_property(text, "modulate:a", 0.0, 0.25)
			flight.tween_property(glow, "modulate:a", 0.0, 0.7)
			flight.chain().tween_callback(func():
				arrived.emit()
				if is_instance_valid(flight_target):
					var flash := flight_target.create_tween()
					flash.tween_property(flight_target, "modulate", Color(1.25, 1.15, 0.90), 0.15)
					flash.tween_property(flight_target, "modulate", Color.WHITE, 0.35)
				queue_free()
			)
		)
	else:
		tween.tween_property(content, "modulate:a", 0.0, 0.4).set_delay(1.8)
		tween.chain().tween_callback(queue_free)
