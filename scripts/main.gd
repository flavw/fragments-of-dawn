extends Control

const Catalog = preload("res://scripts/catalog.gd")
const Progress = preload("res://scripts/progress.gd")
const Board = preload("res://scripts/board.gd")
var catalog = Catalog.new()
var progress = Progress.new()
var board = Board.new()
var sound = preload("res://scripts/audio_manager.gd").new()
var page: VBoxContainer
var status: Label
var grid: Control
var active: Dictionary
var texture: Texture2D
var selected := -1
const difficulty := 4
const Locale = preload("res://scripts/locale.gd")
const KEY_ICON = preload("res://art/dawn-ui/wallet-key.tres")
const TITLE_FONT = preload("res://fonts/KaushanScript-Regular.ttf")
var language := "en"
var screen := "home"
var toast := ""
var board_area: Control
var unlock_dialog: ConfirmationDialog
var puzzle_rotation_allowed := false
var back_action := Callable()
var exit_dialog: ConfirmationDialog
var wallet_dialog: ConfirmationDialog
var achievements = preload("res://scripts/achievements.gd").new()
var friendships = preload("res://scripts/friendships.gd").new()
var achievement_layer: CanvasLayer
var achievement_banner: PanelContainer
var achievement_animation: Tween
var achievement_wait_until := 0
var pending_key_rewards: Array[int] = []
var next_key_reward_at := 0
var home_wallet: Control
var six_seven_prelude_active := false
var six_seven_prelude_shown := false
var six_seven_replay_available_at := 0
const SIX_SEVEN_REPLAY_COOLDOWN_MS := 10000

func update_mobile_viewport() -> void:
	if not OS.has_feature("mobile"): return
	var window := get_window()
	var landscape := puzzle_rotation_allowed and window.size.x > window.size.y
	window.content_scale_size = Vector2i(854, 480) if landscape else Vector2i(480, 854)

func set_puzzle_rotation(allowed: bool) -> void:
	puzzle_rotation_allowed = allowed
	if not OS.has_feature("mobile"): return
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR if allowed else DisplayServer.SCREEN_PORTRAIT)
	update_mobile_viewport()

func _ready() -> void:
	get_window().size_changed.connect(update_mobile_viewport)
	get_tree().auto_accept_quit = false
	catalog.scan()
	progress.read_save()
	progress.migrate_catalog_ids(catalog.entries)
	language = Locale.initial_language(str(progress.data.get("language", "")), OS.get_locale_language())
	DisplayServer.window_set_title(t("Fragments of Dawn"))
	progress.ensure_permanent(catalog.permanent_ids())
	progress.migrate_initial_collection_policy(catalog.key_locked_ids())
	progress.apply_six_free_policy(catalog.entries)
	achievements.key_earned.connect(refresh_key_balance)
	achievements.setup(progress, catalog)
	friendships.setup(progress, catalog)
	var welcome_key := progress.claim_welcome_key()
	achievement_layer = CanvasLayer.new()
	achievement_layer.layer = 20
	add_child(achievement_layer)
	add_child(sound)
	sound.configure(progress.data.get("audio", {}))

	var theme_file := Theme.new()
	theme_file.default_font_size = 18
	var delicate_font := load("res://fonts/Carlito-Regular.ttf")
	if delicate_font:
		theme_file.default_font = delicate_font
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("292936") if kind != "pressed" else Color("49404a")
		style.set_border_width_all(1)
		style.border_color = Color("b69761")
		if kind == "disabled": style.bg_color = Color("171f32")
		style.set_corner_radius_all(14)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		if kind == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = Color("ffe0a0")
		theme_file.set_stylebox(kind, "Button", style)
	theme_file.set_color("font_color", "Label", Color("e8edf4"))
	theme_file.set_font_size("font_size", "Button", 16)
	theme_file.set_color("font_color", "Button", Color.WHITE)
	theme_file.set_color("font_shadow_color", "Button", Color("163842"))
	theme_file.set_constant("shadow_offset_y", "Button", 1)
	theme = theme_file
	home()
	if welcome_key: show_welcome_key.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		progress.save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		progress.save()

func handle_back() -> void:
	if six_seven_prelude_active: return
	# Dismiss the topmost modal before navigating behind it.
	var children := get_children()
	children.reverse()
	for child in children:
		if child is AcceptDialog and child.visible:
			child.hide()
			child.canceled.emit()
			return
	if screen == "home":
		confirm_exit()
	elif screen == "victory":
		collection(false, active.collection)
	elif back_action.is_valid():
		back_action.call()
	else:
		home()

func confirm_exit() -> void:
	if is_instance_valid(exit_dialog) and not exit_dialog.is_queued_for_deletion(): return
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = t("Exit game?")
	exit_dialog.dialog_text = t("Do you want to exit the game?")
	exit_dialog.ok_button_text = t("Exit")
	exit_dialog.cancel_button_text = t("Cancel")
	exit_dialog.theme = theme
	add_child(exit_dialog)
	exit_dialog.confirmed.connect(func():
		progress.save()
		get_tree().quit()
	)
	exit_dialog.canceled.connect(exit_dialog.queue_free)
	exit_dialog.popup_centered(Vector2i(350, 160))

func _process(_delta: float) -> void:
	process_achievement_queue()
	if not pending_key_rewards.is_empty() and screen != "puzzle" and Time.get_ticks_msec() >= maxi(next_key_reward_at, achievement_wait_until):
		var reward_count: int = pending_key_rewards.pop_front()
		next_key_reward_at = Time.get_ticks_msec() + 2400
		show_completion_reward(reward_count)
		refresh_key_balance()
	if is_instance_valid(status) and progress.save_error:
		status.text = t("Could not save. Check your storage.")

func clear_screen() -> void:
	sound.set_friendship_music(screen in ["friendships", "friendship_dialogue"])
	back_action = Callable()
	set_puzzle_rotation(false)
	for child in get_children():
		if child != sound and child != achievement_layer:
			remove_child(child)
			child.queue_free()
	grid = null
	board_area = null
	status = null

func base(title: String, subtitle: String, decorative_title := true) -> void:
	clear_screen()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 24)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	margin.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)
	label(t("F R A G M E N T S   O F   D A W N"), 13, Color("9be1c4"))
	var heading := label(title, 32)
	if not decorative_title: heading.remove_theme_font_override("font")
	label(subtitle, 16, Color("aab8cd"))
	status = label(toast, 15, Color("9be1c4"))
	status.visible = not toast.is_empty()
	toast = ""

func back_button(action: Callable) -> Button:
	back_action = action
	var back := Button.new()
	back.icon = preload("res://art/dawn-ui/back.svg")
	back.expand_icon = true
	back.add_theme_constant_override("icon_max_width", 18)
	back.tooltip_text = t("Back")
	back.custom_minimum_size = Vector2(44, 44)
	back.add_theme_font_size_override("font_size", 28)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(action)
	return back

func page_back(action: Callable) -> void:
	var back := back_button(action)
	page.add_child(back)
	page.move_child(back, 0)

func cover_card(path: String, title: String, caption: String, height: float, action: Callable, focal_point := Vector2(0.5, 0.5)) -> TextureButton:
	var cover := TextureButton.new()
	cover.mouse_filter = Control.MOUSE_FILTER_PASS
	var cover_texture: Texture2D = load(path)
	var crop := AtlasTexture.new()
	crop.atlas = cover_texture
	cover.texture_normal = crop
	var update_crop := func():
		var source := Vector2(cover_texture.get_size())
		var ratio := cover.size.x / maxf(cover.size.y, 1.0)
		var region_size := Vector2(minf(source.x, source.y * ratio), minf(source.y, source.x / maxf(ratio, 0.01)))
		# Keep the face above the caption, adapting the crop to the actual card size.
		var origin := source * focal_point - region_size * Vector2(0.5, 0.38)
		origin = origin.clamp(Vector2.ZERO, source - region_size)
		crop.region = Rect2(origin, region_size)
	cover.resized.connect(update_crop)
	cover.ignore_texture_size = true
	cover.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	cover.clip_contents = true
	cover.custom_minimum_size.y = height
	cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover.pressed.connect(func(): sound.play_effect("select"))
	cover.pressed.connect(action)
	page.add_child(cover)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([Color(0.04, 0.05, 0.09, 0), Color(0.04, 0.05, 0.09, 0.22), Color(0.04, 0.05, 0.09, 0.88)])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0.45)
	gradient_texture.fill_to = Vector2(0, 1)
	shade.texture = gradient_texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(shade)
	var border := Panel.new()
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = Color("c9ad73")
	border_style.set_border_width_all(1)
	border.add_theme_stylebox_override("panel", border_style)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(border)
	var text_box := VBoxContainer.new()
	text_box.name = "CoverText"
	text_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	text_box.offset_left = 20
	text_box.offset_right = -20
	text_box.offset_top = -82
	text_box.offset_bottom = -16
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(text_box)
	for text_value in [title, caption]:
		var text_label := Label.new()
		text_label.text = text_value
		text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_label.tooltip_text = text_value
		if text_value == title: text_label.add_theme_font_override("font", preload("res://fonts/Carlito-Bold.ttf"))
		text_label.add_theme_font_size_override("font_size", 25 if text_value == title else 18)
		text_label.add_theme_color_override("font_color", Color.WHITE if text_value == title else Color("e1d6bf"))
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(text_label)
	return cover

func collection_medal(completed: int, total: int) -> String:
	if total <= 0: return ""
	if completed >= total: return "gold"
	if completed * 100 >= total * 70: return "silver"
	if completed * 100 >= total * 50: return "bronze"
	return ""

func add_collection_medal(cover: Control, completed: int, total: int) -> void:
	var tier := collection_medal(completed, total)
	if tier.is_empty(): return
	cover.get_node("CoverText").offset_right = -96
	var medal := TextureRect.new()
	medal.name = "CollectionMedal"
	medal.texture = load("res://art/dawn-ui/medal-" + tier + ".webp")
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	medal.offset_left = -92
	medal.offset_right = -8
	medal.offset_top = -92
	medal.offset_bottom = -8
	medal.set_meta("tier", tier)
	cover.add_child(medal)

func label(text_value: String, font_size := 18, color := Color("e8edf4")) -> Label:
	var node := Label.new()
	node.text = text_value
	if font_size >= 22: node.add_theme_font_override("font", TITLE_FONT)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	page.add_child(node)
	return node

func button(text_value: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text_value
	node.custom_minimum_size.y = 64
	node.pressed.connect(func(): sound.play_effect("select"))
	node.pressed.connect(action)
	page.add_child(node)
	return node

func artwork(tex: Texture2D, height: float) -> void:
	var view := TextureRect.new()
	view.texture = tex
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size.y = height
	page.add_child(view)

func puzzle_grid(entries: Array, gallery: bool) -> GridContainer:
	var cards := GridContainer.new()
	cards.columns = 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 6)
	cards.add_theme_constant_override("v_separation", 6)
	page.add_child(cards)
	for entry in entries:
		cards.add_child(puzzle_card(entry, gallery))
	return cards

func puzzle_card(entry: Dictionary, gallery: bool) -> VBoxContainer:
	var solved: bool = entry.id in progress.data.solved
	var unlocked: bool = entry.id in progress.data.unlocked
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 3)
	card.set_meta("puzzle_id", entry.id)
	card.set_meta("puzzle_card", true)

	var image_button := TextureButton.new()
	# Let ScrollContainer receive drags and cancel the button press when scrolling starts.
	image_button.mouse_filter = Control.MOUSE_FILTER_PASS
	image_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	image_button.texture_normal = load(entry.path)
	var source_size := Vector2(image_button.texture_normal.get_size())
	if source_size.y > source_size.x:
		var portrait_crop := AtlasTexture.new()
		portrait_crop.atlas = image_button.texture_normal
		portrait_crop.region = Rect2(0, 0, source_size.x, minf(source_size.y, source_size.x * 1.1))
		image_button.texture_normal = portrait_crop
	image_button.ignore_texture_size = true
	image_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	image_button.custom_minimum_size = Vector2(0, 215)
	image_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_button.clip_contents = true
	image_button.tooltip_text = catalog.artwork_title(entry, language)
	image_button.modulate = Color(0.45, 0.49, 0.56) if not unlocked else Color.WHITE
	image_button.set_meta("puzzle_image", true)
	image_button.set_meta("puzzle_id", entry.id)
	image_button.pressed.connect(func(): sound.play_effect("select"))
	image_button.pressed.connect(func():
		if gallery: show_image(entry)
		else: choose_puzzle(entry)
	)
	card.add_child(image_button)

	var outline := ReferenceRect.new()
	outline.editor_only = false
	outline.border_color = Color("9be1c4") if solved else Color("51627b")
	outline.border_width = 2
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_button.add_child(outline)

	if not unlocked:
		var lock := TextureRect.new()
		lock.name = "PuzzleLock"
		lock.texture = preload("res://art/dawn-ui/lock.svg")
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -18
		lock.offset_right = 18
		lock.offset_top = -18
		lock.offset_bottom = 18
		image_button.add_child(lock)

	var title := Label.new()
	title.text = catalog.artwork_title(entry, language)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("e8edf4") if unlocked or gallery else Color("8290a6"))
	title.custom_minimum_size.y = 22
	card.add_child(title)

	if not gallery and unlocked:
		var badge := TextureRect.new()
		badge.texture = load("res://art/dawn-ui/completed.svg" if solved else "res://art/dawn-ui/ready.svg")
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -38
		badge.offset_right = -6
		badge.offset_top = 6
		badge.offset_bottom = 38
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_button.add_child(badge)
		image_button.tooltip_text += " — " + t("Completed" if solved else "Ready to play")
	return card

func home_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(20)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func ornament_style(tint := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var region := AtlasTexture.new()
	region.atlas = load("res://art/dawn-ui/button.webp")
	region.region = Rect2(35, 100, 2095, 515)
	style.texture = region
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.modulate_color = tint
	return style

func ornament_button(control: Button, tint := Color.WHITE) -> void:
	control.add_theme_stylebox_override("normal", ornament_style(tint))
	control.add_theme_stylebox_override("hover", ornament_style(tint.lightened(0.12)))
	control.add_theme_stylebox_override("pressed", ornament_style(tint.darkened(0.18)))
	control.add_theme_stylebox_override("disabled", ornament_style(Color(0.6, 0.6, 0.6, 0.7)))
	control.add_theme_color_override("font_color", Color("302337"))
	control.add_theme_color_override("font_hover_color", Color("302337"))
	control.add_theme_color_override("font_pressed_color", Color("302337"))
	control.add_theme_color_override("font_focus_color", Color("302337"))
	control.add_theme_color_override("font_hover_pressed_color", Color("302337"))
	control.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)

func home() -> void:
	screen = "home"
	clear_screen()
	var background := TextureRect.new()
	background.texture = load("res://art/dawn-ui/hero.webp")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var veil := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.23, 0.44, 0.66, 1.0])
	gradient.colors = PackedColorArray([Color(0.06, 0.07, 0.14, 0.03), Color(0.06, 0.07, 0.14, 0), Color(0.06, 0.07, 0.14, 0.10), Color(0.06, 0.07, 0.14, 0.45), Color(0.06, 0.07, 0.14, 0.78)])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(0, 1)
	veil.texture = fade
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var ornament := TextureRect.new()
	ornament.texture = load("res://art/dawn-ui/frame.webp")
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_SCALE
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.z_index = 1
	add_child(ornament)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 28)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var top := HBoxContainer.new()
	page.add_child(top)
	key_balance(29.04)
	var balance := page.get_child(page.get_child_count() - 1)
	page.remove_child(balance)
	balance.alignment = BoxContainer.ALIGNMENT_CENTER
	balance.get_child(0).texture = KEY_ICON
	balance.get_child(1).add_theme_font_size_override("font_size", 26)
	balance.get_child(1).add_theme_color_override("font_color", Color("fff0d1"))
	balance.get_child(1).add_theme_color_override("font_shadow_color", Color("171623"))
	balance.get_child(1).add_theme_constant_override("shadow_offset_y", 2)
	var wallet := PanelContainer.new()
	home_wallet = wallet
	wallet.custom_minimum_size = Vector2(116, 60)
	var wallet_style := StyleBoxTexture.new()
	var wallet_panel := AtlasTexture.new()
	wallet_panel.atlas = load("res://art/dawn-ui/wallet-panel.webp")
	wallet_panel.region = Rect2(79, 148, 1648, 549)
	wallet_style.texture = wallet_panel
	wallet_style.content_margin_left = 12
	wallet_style.content_margin_right = 21
	wallet_style.content_margin_top = 8
	wallet_style.content_margin_bottom = 8
	wallet.add_theme_stylebox_override("panel", wallet_style)
	wallet.add_child(balance)
	top.add_child(wallet)
	var wallet_hit := Button.new()
	wallet_hit.flat = true
	wallet_hit.tooltip_text = t("Your keys")
	wallet_hit.set_meta("home_wallet", true)
	wallet_hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wallet_hit.pressed.connect(show_wallet_offer)
	# A plain Control keeps this hit target outside PanelContainer's layout.
	var wallet_overlay := Control.new()
	wallet_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_child(wallet_overlay)
	wallet_overlay.add_child(wallet_hit)
	var top_space := Control.new()
	top_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_space)
	var breathing_room := Control.new()
	breathing_room.custom_minimum_size.y = 80
	breathing_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(breathing_room)
	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 12)
	page.add_child(title_margin)
	var game_title := label(t("Fragments\nof Dawn"), 66, Color("fff4df"))
	game_title.reparent(title_margin)
	game_title.add_theme_constant_override("line_spacing", -8)
	game_title.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.09, 0.8))
	game_title.add_theme_constant_override("shadow_offset_y", 2)
	status = label(toast, 14, Color("f4d9a6"))
	status.visible = not toast.is_empty()
	toast = ""
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	for is_gallery in [false, true]:
		var action := Button.new()
		action.text = t("Gallery" if is_gallery else "Play")
		action.custom_minimum_size.y = 66
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.size_flags_stretch_ratio = 1.0 if is_gallery else 1.5
		action.add_theme_font_size_override("font_size", 22)
		action.add_theme_stylebox_override("normal", home_style(Color("262c44") if is_gallery else Color("f0d5a2"), Color("626276") if is_gallery else Color("fff0cf")))
		if not is_gallery:
			action.add_theme_color_override("font_color", Color("29243b"))
			action.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		ornament_button(action)
		if is_gallery:
			for state in ["normal", "hover", "pressed", "disabled"]:
				var glass := ornament_style()
				glass.texture = load("res://art/dawn-ui/gallery.svg")
				glass.modulate_color = Color("b8b8b8") if state == "pressed" else Color.WHITE
				action.add_theme_stylebox_override(state, glass)
			for state in ["font_color", "font_hover_color", "font_pressed_color"]:
				action.add_theme_color_override(state, Color("fff1da"))
		action.pressed.connect(func(): sound.play_effect("select"); collection(is_gallery))
		actions.add_child(action)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 10)
	page.add_child(secondary)
	for item in [["Achievements", "", achievements_screen], ["Options", "res://art/dawn-ui/gear.svg", options_settings]]:
		var control := Button.new()
		control.text = t(item[0])
		if not item[1].is_empty():
			control.icon = load(item[1])
		control.expand_icon = true
		control.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.alignment = HORIZONTAL_ALIGNMENT_CENTER
		control.add_theme_constant_override("h_separation", 0)
		control.add_theme_constant_override("icon_max_width", 38)
		control.add_theme_font_size_override("font_size", 22)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_stretch_ratio = 1.5 if item[0] == "Achievements" else 1.0
		for state in ["normal", "hover", "pressed", "disabled"]:
			var glass := ornament_style()
			glass.texture = load("res://art/dawn-ui/gallery.svg")
			glass.modulate_color = Color("b8b8b8") if state == "pressed" else Color.WHITE
			control.add_theme_stylebox_override(state, glass)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(state, Color("fff1da"))
		control.custom_minimum_size.y = 64
		control.set_meta("home_options" if item[0] == "Options" else "home_achievements", true)
		control.pressed.connect(item[2])
		secondary.add_child(control)

func collection_cover_path(name: String, entries: Array) -> String:
	var chosen: String = {"Quiet Moments": "11_Garden_of_Dawn.webp", "Golden Tides": "05_Ember Coast.webp", "Sweet Encounters": "02_Strawberry_Bliss.webp", "Halloween Reverie": "09_Jasmine_Familiar.webp", "Velvet Evenings": "06_Silver_Whisper.webp"}.get(name, "")
	for entry in entries:
		if entry.path.get_file() == chosen: return entry.path
	return entries[0].path

func collection(gallery: bool, folder: String = "") -> void:
	if gallery: achievements.event("visit")
	screen = "gallery" if gallery else "collection"
	if gallery:
		base(t("Gallery") if folder.is_empty() else t(folder), collection_phrase(folder) if not folder.is_empty() else t("A quiet collection of discovered moments."))
		page_back(home if folder.is_empty() else func(): collection(true))
		if folder.is_empty(): add_friendship_button()
	else:
		base(t("Play") if folder.is_empty() else t(folder), collection_phrase(folder) if not folder.is_empty() else t("Choose a world to explore, at your own pace."), folder.is_empty())
		page_back(home if folder.is_empty() else func(): collection(false))
	if gallery and folder.is_empty():
		var visible_collections: int = 0
		for name in catalog.collections():
			var gallery_items = catalog.entries.filter(func(e): return e.collection == name)
			var gallery_done = gallery_items.filter(func(e): return e.id in progress.data.solved).size()
			if gallery_done == 0:
				continue
			visible_collections += 1
			var gallery_cover := cover_card(collection_cover_path(name, gallery_items), t(name), t("%d / %d completed") % [gallery_done, gallery_items.size()], 240, func(): collection(true, name), {
				"Quiet Moments": Vector2(0.36, 0.24), "Golden Tides": Vector2(0.46, 0.17), "High Fantasy": Vector2(0.50, 0.23), "Sweet Encounters": Vector2(0.46, 0.285), "Sporting Moments": Vector2(0.50, 0.30), "Halloween Reverie": Vector2(0.50, 0.23), "Velvet Evenings": Vector2(0.40, 0.40)
			}.get(name, Vector2(0.5, 0.35)))
			gallery_cover.set_meta("gallery_collection", name)
		if visible_collections == 0:
			label(t("Complete your first puzzle to start your gallery."))
		return
	if not gallery and folder.is_empty():
		progress_summary()
		var focal_points := {
			"Quiet Moments": Vector2(0.36, 0.24),
			"Golden Tides": Vector2(0.46, 0.17),
			"High Fantasy": Vector2(0.50, 0.23),
			"Sweet Encounters": Vector2(0.46, 0.285),
			"Sporting Moments": Vector2(0.50, 0.30),
			"Halloween Reverie": Vector2(0.50, 0.23), "Velvet Evenings": Vector2(0.40, 0.40),
		}
		for name in catalog.collections():
			var items = catalog.entries.filter(func(e): return e.collection == name)
			var done = items.filter(func(e): return e.id in progress.data.solved).size()
			var cover := cover_card(collection_cover_path(name, items), t(name), t("%d puzzles  ·  %d completed  →") % [items.size(), done], 240, func(): collection(false, name), focal_points.get(name, Vector2(0.5, 0.35)))
			cover.set_meta("collection_cover", name)
			add_collection_medal(cover, done, items.size())
		return
	var visible_entries: Array = catalog.entries.filter(func(entry):
		return (gallery and entry.collection == folder and entry.id in progress.data.solved) or (not gallery and entry.collection == folder)
	)
	if visible_entries.is_empty():
		label(t("Complete your first puzzle to unlock an artwork here."))
	else:
		puzzle_grid(visible_entries, gallery)
	if not gallery: label(t("Tap a locked puzzle to unlock it."), 14)

func add_friendship_button() -> void:
	var heading: Label = page.get_child(2)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)
	page.move_child(header, 2)
	heading.reparent(header)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heart := Button.new()
	heart.name = "FriendshipHeart"
	heart.flat = true
	heart.custom_minimum_size = Vector2(52, 52)
	heart.tooltip_text = t("New Friendships")
	var crystal := TextureRect.new()
	crystal.texture = load("res://art/dawn-ui/friendship-heart.webp")
	crystal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crystal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crystal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crystal.material = ShaderMaterial.new()
	crystal.material.shader = load("res://art/dawn-ui/crystal-heart-shine.gdshader")
	heart.add_child(crystal)
	crystal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crystal.offset_left = 4
	crystal.offset_top = 4
	crystal.offset_right = -4
	crystal.offset_bottom = -4
	heart.pressed.connect(func(): sound.play_effect("select"); friendships_screen())
	header.add_child(heart)

func friendships_screen(folder: String = "") -> void:
	screen = "friendships"
	base(t("New Friendships") if folder.is_empty() else t(folder), t("A familiar face, a new story."))
	var margin: MarginContainer = page.get_parent().get_parent()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 92)
	margin.add_theme_constant_override("margin_bottom", 88)
	var frame := TextureRect.new()
	frame.name = "FriendshipFrame"
	frame.texture = load("res://art/dawn-ui/frame.webp")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_back(func(): collection(true) if folder.is_empty() else friendships_screen())
	if folder.is_empty():
		for name in ["Quiet Moments", "Golden Tides"]:
			var items: Array = catalog.entries.filter(func(e): return e.collection == name)
			var accessible: bool = friendships.collection_available(name)
			var encounter_count: int = friendships.encounters.filter(func(e): return friendships.collection_name(e) == name).size()
			var caption: String = t("%d / %d conversations completed") % [friendships.collection_completed(name), encounter_count] if accessible else t("Locked · %d / 12 conversations") % friendships.collection_completed("Quiet Moments")
			var cover := cover_card(collection_cover_path(name, items), t(name), caption, 240, func(): friendships_screen(name), Vector2(0.36, 0.24))
			cover.disabled = not accessible
			if not accessible: cover.modulate = Color(0.55, 0.55, 0.65)
		if not friendships.collection_available("Golden Tides"):
			label(t("Talk to all 12 characters in Quiet Moments first."), 18)
		return
	if not friendships.collection_available(folder):
		friendships_screen()
		return
	label(t("Earn up to 1 key per encounter. Try again to discover the best dialogue."), 18)
	for encounter in friendships.encounters:
		if friendships.collection_name(encounter) != folder: continue
		var character: String = friendships.character_name(encounter, language)
		var available: bool = friendships.available(encounter)
		var focus: Array = encounter.get("focus", [0.5, 0.22])
		var cover := cover_card(encounter.art, character, "", 300, func():
			if friendships.available(encounter): friendship_dialogue(encounter)
			else: offer_friendship_puzzles(encounter)
		, Vector2(focus[0], focus[1]))
		cover.get_node("CoverText").get_child(1).hide()
		cover.get_node("CoverText").offset_top = -52
		var icon_path := "res://art/dawn-ui/ready.svg"
		if not available:
			icon_path = "res://art/dawn-ui/lock.svg"
			cover.modulate = Color(0.55, 0.55, 0.65)
			var entry: Dictionary = catalog.entries.filter(func(item): return item.path == encounter.art)[0]
			cover.tooltip_text = t("Complete %s to meet %s.") % [catalog.artwork_title(entry, language), character]
		elif int(progress.data.friendships.get(encounter.id, {}).get("best_quality", progress.data.friendships.get(encounter.id, {}).get("reward_total", 0))) >= 2:
			icon_path = "res://art/dawn-ui/friendship-heart.svg"
		elif friendships.completed(encounter):
			icon_path = "res://art/dawn-ui/completed.svg"
		var badge := TextureRect.new()
		badge.name = "FriendshipState"
		badge.texture = load(icon_path)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -44
		badge.offset_right = -8
		badge.offset_top = 8
		badge.offset_bottom = 44
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(badge)
	if not friendships.encounters.any(func(e): return friendships.collection_name(e) == folder):
		label(t("New encounters are on their way."), 20)

func offer_friendship_puzzles(encounter: Dictionary) -> void:
	var folder: String = friendships.collection_name(encounter)
	var dialog := ConfirmationDialog.new()
	dialog.title = t("Play %s") % t(folder)
	dialog.dialog_text = t("Complete %s's artwork to unlock this encounter.") % friendships.character_name(encounter, language)
	dialog.dialog_autowrap = true
	dialog.get_ok_button().text = t("Play")
	dialog.get_cancel_button().text = t("Cancel")
	dialog.confirmed.connect(func():
		dialog.queue_free()
		collection(false, folder)
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(mini(400, int(get_viewport_rect().size.x) - 32), 190))

func friendship_dialogue(encounter: Dictionary, branch: int = -1, result: Dictionary = {}) -> void:
	if not friendships.available(encounter):
		friendships_screen()
		return
	screen = "friendship_dialogue"
	clear_screen()
	var background := TextureRect.new()
	var artwork: Texture2D = load(encounter.art)
	var crop := AtlasTexture.new()
	crop.atlas = artwork
	background.texture = crop
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var update_crop := func():
		var source := Vector2(artwork.get_size())
		var ratio := background.size.x / maxf(background.size.y, 1.0)
		var region_size := Vector2(minf(source.x, source.y * ratio), minf(source.y, source.x / maxf(ratio, 0.01)))
		var focus: Array = encounter.get("focus", [0.5, 0.22])
		var origin := source * Vector2(focus[0], focus[1]) - region_size * Vector2(0.5, 0.24)
		crop.region = Rect2(origin.clamp(Vector2.ZERO, source - region_size), region_size)
	background.resized.connect(update_crop)
	update_crop.call()
	var return_to_folder := func(): friendships_screen(friendships.collection_name(encounter))
	var back := back_button(return_to_folder)
	add_child(back)
	back.position = Vector2(16, 24)
	var panel := PanelContainer.new()
	panel.name = "FriendshipDialogue"
	var style := home_style(Color("1c1c30"), Color("d6b77a"))
	style.bg_color.a = 0.85
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_bottom = -16
	var fit := func():
		if is_instance_valid(panel): panel.offset_top = -minf(get_viewport_rect().size.y * 0.53, 440.0)
	background.resized.connect(fit)
	fit.call()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var name_label := achievement_label(friendships.character_name(encounter, language), 28, Color("ffe3a0"))
	name_label.add_theme_font_override("font", TITLE_FONT)
	body.add_child(name_label)
	var dialogue: String = friendships.text(encounter.intro if branch < 0 else encounter.branches[branch].dialogue, language)
	if not result.is_empty(): dialogue = friendships.text(result.ending, language)
	body.add_child(achievement_label(dialogue, 20))
	if not result.is_empty():
		var reward_text := t("A pleasant moment to remember.")
		if result.earned == 1: reward_text = t("You received 1 key.")
		elif result.earned > 1: reward_text = t("You received %d keys.") % result.earned
		if result.earned > 0 or result.total < 1:
			body.add_child(achievement_label(reward_text, 18, Color("e8cf97")))
		friendship_choice(body, t("Talk again"), func(): friendship_dialogue(encounter))
		friendship_choice(body, t("Back"), return_to_folder)
	elif branch < 0:
		for index in range(encounter.branches.size()):
			friendship_choice(body, friendships.text(encounter.branches[index].label, language), func(): friendship_dialogue(encounter, index))
	else:
		for index in range(encounter.branches[branch].choices.size()):
			friendship_choice(body, friendships.text(encounter.branches[branch].choices[index].label, language), func():
				var outcome: Dictionary = friendships.finish(encounter, branch, index)
				if outcome.is_empty(): return
				var answer_reward: int = int(encounter.branches[branch].choices[index].reward)
				achievements.evaluate()
				friendship_dialogue(encounter, branch, outcome)
				if outcome.get("earned", 0) > 0:
					show_completion_reward(outcome.earned, "join" if answer_reward == 2 else "key_received")
				elif answer_reward == 2: sound.play_effect("join")
				if answer_reward == 0: sound.play_effect("move")
			)

func friendship_choice(parent: VBoxContainer, caption: String, action: Callable) -> void:
	var choice := Button.new()
	choice.text = caption
	choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice.custom_minimum_size.y = 58
	choice.add_theme_font_size_override("font_size", 18)
	choice.pressed.connect(func():
		choice.disabled = true
		sound.play_effect("select")
		action.call()
	)
	parent.add_child(choice)

func collection_phrase(name: String) -> String:
	var phrases := {
		"Quiet Moments": "Soft light, quiet hearts, and moments worth keeping.",
		"Golden Tides": "Where every wave carries a little golden memory.",
		"High Fantasy": "Legends bloom where magic meets the brave.",
		"Sweet Encounters": "A little sweetness, a closer look, a moment to savor.",
		"Sporting Moments": "Every movement holds a spark of joy.",
		"Halloween Reverie": "When lanterns glow, familiar faces awaken a little magic.",
		"Velvet Evenings": "Soft lamplight, quiet rooms, and dreams just out of reach.",
	}
	return t(phrases.get(name, "Discoveries waiting beyond the familiar."))

func progress_summary() -> void:
	var total: int = catalog.entries.size()
	var done: int = catalog.ids().filter(func(id): return id in progress.data.solved).size()
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 5)
	page.add_child(summary)
	var text_label := label(t("%d / %d completed") % [done, total], 19, Color("f1d49a"))
	text_label.reparent(summary)
	var bar := ProgressBar.new()
	bar.max_value = maxi(total, 1)
	bar.value = done
	style_gold_progress_bar(bar)
	summary.add_child(bar)

func style_gold_progress_bar(bar: ProgressBar) -> void:
	bar.show_percentage = false
	bar.custom_minimum_size.y = 5
	var track := StyleBoxFlat.new()
	track.bg_color = Color("24283b")
	track.corner_radius_top_left = 3
	track.corner_radius_top_right = 3
	track.corner_radius_bottom_left = 3
	track.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("eac46e")
	fill.shadow_color = Color(1.0, 0.70, 0.22, 0.20)
	fill.shadow_size = 3
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)

func choose_puzzle(entry: Dictionary) -> void:
	if entry.id in progress.data.unlocked:
		play(entry)
		return
	if progress.keys() <= 0:
		show_wallet_offer()
		return
	if is_instance_valid(unlock_dialog):
		return
	unlock_dialog = ConfirmationDialog.new()
	unlock_dialog.dialog_autowrap = true
	unlock_dialog.add_theme_font_size_override("font_size", 22)
	unlock_dialog.add_theme_font_size_override("title_font_size", 25)
	unlock_dialog.title = t("Unlock puzzle")
	var balance_key := "Balance: %d key" if progress.keys() == 1 else "Balance: %d keys"
	unlock_dialog.dialog_text = "%s\n%s" % [t("Unlock %s?") % catalog.artwork_title(entry, language), t(balance_key) % progress.keys()]
	unlock_dialog.ok_button_text = t("Use 1") if progress.keys() > 0 else t("Your keys")
	unlock_dialog.get_ok_button().icon = KEY_ICON
	unlock_dialog.get_ok_button().add_theme_constant_override("icon_max_width", 40)
	unlock_dialog.get_ok_button().add_theme_font_size_override("font_size", 20)
	unlock_dialog.get_ok_button().custom_minimum_size = Vector2(0, 56)
	unlock_dialog.cancel_button_text = t("Cancel")
	unlock_dialog.get_cancel_button().add_theme_font_size_override("font_size", 20)
	unlock_dialog.get_cancel_button().custom_minimum_size = Vector2(0, 56)
	unlock_dialog.confirmed.connect(func():
		var dialog := unlock_dialog
		unlock_dialog = null
		dialog.hide()
		dialog.queue_free()
		if progress.spend_key(entry.id, catalog.key_locked_ids()):
			achievements.evaluate()
			sound.play_effect("key_received")
			refresh_key_balance()
			animate_puzzle_unlock(entry)
	)
	unlock_dialog.canceled.connect(func():
		unlock_dialog.hide()
		unlock_dialog.queue_free()
		unlock_dialog = null
	)
	add_child(unlock_dialog)
	unlock_dialog.popup_centered(Vector2i(390, 230))

func animate_puzzle_unlock(entry: Dictionary) -> void:
	for candidate in page.find_children("*", "TextureButton", true, false):
		if candidate.get_meta("puzzle_id", "") != entry.id: continue
		var image_button: TextureButton = candidate
		var card := image_button.get_parent()
		var old_lock := image_button.get_node_or_null("PuzzleLock")
		if old_lock: old_lock.hide()
		image_button.disabled = true
		var animated_lock := preload("res://scripts/unlocking_lock.gd").new()
		animated_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_button.add_child(animated_lock)
		animated_lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		animated_lock.offset_left = -18
		animated_lock.offset_right = 18
		animated_lock.offset_top = -18
		animated_lock.offset_bottom = 18
		var animation := image_button.create_tween()
		animation.set_parallel(true)
		animation.tween_method(animated_lock.set_opening, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		animation.tween_property(image_button, "modulate", Color.WHITE, 0.65)
		animation.set_parallel(false)
		animation.tween_property(animated_lock, "modulate:a", 0.0, 0.2)
		animation.tween_callback(func():
			var parent := card.get_parent()
			var index := card.get_index()
			var replacement := puzzle_card(entry, false)
			parent.add_child(replacement)
			parent.move_child(replacement, index)
			parent.remove_child(card)
			card.queue_free()
		)
		return

func show_image(entry: Dictionary) -> void:
	if not entry.id in progress.data.solved: return
	achievements.event("viewed", entry.id)
	screen = "image"
	clear_screen()
	var image_margin := MarginContainer.new()
	image_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: image_margin.add_theme_constant_override("margin_" + edge, 8)
	for edge in ["top", "bottom"]: image_margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(image_margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	image_margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	header.add_child(back_button(func(): collection(true)))
	var art_title := Label.new()
	art_title.text = catalog.artwork_title(entry, language)
	art_title.add_theme_font_override("font", TITLE_FONT)
	art_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_title.add_theme_font_size_override("font_size", 22)
	art_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(art_title)
	var viewer := preload("res://scripts/gallery_zoom.gd").new()
	viewer.texture = load(entry.path)
	viewer.zoomed.connect(func(): achievements.event("zoom"))
	viewer.custom_minimum_size.y = 100
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(viewer)
	if "immersive" not in achievements.state().unlocked:
		show_gallery_hint(viewer)
	var gallery_chrome: Array[Control] = [header]
	if not entry.subtitle.is_empty():
		var subtitle := Label.new()
		subtitle.text = t(entry.subtitle)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 14)
		subtitle.add_theme_color_override("font_color", Color("aab8cd"))
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		subtitle.tooltip_text = subtitle.text
		page.add_child(subtitle)
		gallery_chrome.append(subtitle)
	var heart := Button.new()
	heart.name = "GalleryFriendshipHeart"
	heart.icon = load("res://art/dawn-ui/friendship-heart.svg")
	heart.expand_icon = true
	heart.add_theme_constant_override("icon_max_width", 32)
	heart.tooltip_text = t("New Friendships")
	heart.custom_minimum_size = Vector2(44, 44)
	heart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	heart.pressed.connect(func(): sound.play_effect("select"); open_artwork_friendship(entry))
	header.add_child(heart)
	viewer.tapped.connect(func():
		var show_controls := not header.visible
		if not show_controls:
			achievements.event("immersive")
			var hint := viewer.get_node_or_null("GalleryHint")
			if hint != null: hint.queue_free()
		for control in gallery_chrome: control.visible = show_controls
		for edge in ["left", "right"]:
			image_margin.add_theme_constant_override("margin_" + edge, 8 if show_controls else 0)
		for edge in ["top", "bottom"]:
			image_margin.add_theme_constant_override("margin_" + edge, 12 if show_controls else 0)
	)

func open_artwork_friendship(entry: Dictionary) -> void:
	var matches: Array = friendships.encounters.filter(func(encounter): return encounter.art == entry.path)
	if not matches.is_empty() and friendships.available(matches[0]):
		friendship_dialogue(matches[0])
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "ArtworkFriendshipOffer"
	dialog.title = t("New Friendships")
	dialog.dialog_text = t("This encounter is not available yet. Open New Friendships to explore other encounters?")
	dialog.dialog_autowrap = true
	dialog.get_ok_button().text = t("New Friendships")
	dialog.get_cancel_button().text = t("Cancel")
	dialog.confirmed.connect(func():
		dialog.queue_free()
		friendships_screen()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(mini(400, int(get_viewport_rect().size.x) - 32), 190))

func show_gallery_hint(viewer: Control) -> void:
	var hint := PanelContainer.new()
	hint.name = "GalleryHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.anchor_left = 0.06
	hint.anchor_right = 0.94
	hint.offset_left = 0
	hint.offset_right = 0
	hint.offset_top = -100
	hint.offset_bottom = -20
	var style := home_style(Color(0.08, 0.09, 0.14, 0.92), Color("d8b56a"))
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	hint.add_theme_stylebox_override("panel", style)
	var text := Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = t("Tap the artwork to hide the controls and enjoy every detail. Tap again to bring them back.")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 17)
	text.add_theme_color_override("font_color", Color("fff0d3"))
	hint.add_child(text)
	viewer.add_child(hint)
	var fade := hint.create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(hint, "modulate:a", 0.0, 0.6)
	fade.tween_callback(hint.queue_free)

func play(entry: Dictionary) -> void:
	if not entry.id in progress.data.unlocked: return
	active = entry
	texture = load(entry.path)
	board.start(difficulty, progress.data.sessions.get(session_key(), {}))
	achievements.event("start_puzzle", entry.id)
	selected = -1
	screen = "puzzle"
	clear_screen()
	if sound.selection == "random": sound.select_track("random")
	set_puzzle_rotation(texture.get_width() > texture.get_height())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 8)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)
	header.add_child(back_button(func(): collection(false, active.collection)))
	var title := Label.new()
	title.text = catalog.artwork_title(entry, language)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_font_override("font", TITLE_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	status = Label.new()
	status.visible = false
	page.add_child(status)
	board_area = Control.new()
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(board_area)
	grid = preload("res://scripts/board_view.gd").new()
	grid.texture = texture
	grid.board = board
	grid.slot_pressed.connect(tap)
	board_area.add_child(grid)
	board_area.resized.connect(resize_tiles)
	draw_board()
	save_session()
	if progress.data.solved.is_empty():
		show_puzzle_help()
		return
	if entry.path.get_file() == "03_Seaside_Watercolors.webp":
		show_rotation_tip()

func show_puzzle_help() -> void:
	var hint := MarginContainer.new()
	hint.name = "PuzzleHelp"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Label.new()
	text.text = t("Tap two pieces\nto swap their positions.")
	text.add_theme_font_size_override("font_size", 28)
	text.add_theme_color_override("font_color", Color("fff0d3"))
	text.add_theme_color_override("font_outline_color", Color("111421"))
	text.add_theme_constant_override("outline_size", 5)
	text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	text.add_theme_constant_override("shadow_offset_y", 2)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(text)
	board_area.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_left = 12
	hint.offset_right = -12
	hint.offset_top = 8
	hint.offset_bottom = 8
	grid.tutorial_finished.connect(func():
		if board.moves == 0: board.initial_minimum = board.minimum_swaps()
		save_session()
		hint.queue_free()
		if active.path.get_file() == "03_Seaside_Watercolors.webp":
			show_rotation_tip.call_deferred()
	, CONNECT_ONE_SHOT)
	grid.demonstrate_swap()

func show_rotation_tip() -> void:
	if progress.data.get("rotation_tip_hidden", false): return
	var dialog := AcceptDialog.new()
	dialog.set_meta("rotation_tip", true)
	dialog.theme = theme
	dialog.title = t("A wider view")
	# Give the custom content a stable minimum size. Measuring a wrapped
	# label in a zero-width container can otherwise inflate the popup height.
	var content := Control.new()
	content.custom_minimum_size = Vector2(340, 220)
	var icon := TextureRect.new()
	icon.texture = load("res://art/dawn-ui/rotate-phone.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(70, 0)
	icon.size = Vector2(200, 112)
	content.add_child(icon)
	var message := Label.new()
	message.text = t("Turn your phone sideways to enjoy this artwork in a larger view.")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 20)
	message.position = Vector2(0, 126)
	message.size = Vector2(340, 90)
	content.add_child(message)
	dialog.add_child(content)
	dialog.ok_button_text = t("Close")
	dialog.add_theme_font_size_override("font_size", 20)
	dialog.get_ok_button().add_theme_font_size_override("font_size", 20)
	dialog.get_ok_button().custom_minimum_size = Vector2(140, 48)
	var dismiss := dialog.add_button(t("Don't show again"), false, "hide_tip")
	dismiss.add_theme_font_size_override("font_size", 18)
	dismiss.custom_minimum_size.y = 48
	dialog.custom_action.connect(func(action: String):
		if action == "hide_tip":
			progress.data["rotation_tip_hidden"] = true
			progress.save()
			dialog.queue_free()
	)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(mini(420, int(get_viewport_rect().size.x) - 32), 330))

func session_key() -> String:
	return str(active.id) + "|" + str(difficulty)

func save_session() -> void:
	progress.data.sessions[session_key()] = {"pieces": board.pieces.duplicate(), "moves": board.moves, "initial_minimum": board.initial_minimum}
	progress.save()

func draw_board() -> void:
	grid.selected = selected
	grid.queue_redraw()
	resize_tiles()

func resize_tiles() -> void:
	if not is_instance_valid(grid) or not is_instance_valid(board_area): return
	var image_size := Vector2(texture.get_size())
	var factor := minf(board_area.size.x / image_size.x, board_area.size.y / image_size.y)
	grid.size = image_size * maxf(0, factor)
	grid.position = (board_area.size - grid.size) / 2.0

func tap(slot: int) -> void:
	if screen != "puzzle": return
	if grid.tutorial_active: return
	if selected == -1:
		selected = slot
		sound.play_effect("select")
	elif selected == slot:
		selected = -1
	else:
		var bonds_before: int = board.bond_count()
		grid.remember_gaps()
		if not board.swap(selected, slot):
			status.text = board.last_error
			sound.play_effect("invalid")
			return
		status.text = ""
		selected = -1
		save_session()
		if board.solved():
			var collection_ids: Array = catalog.entries.filter(func(e): return e.collection == active.collection).map(func(e): return e.id)
			var earned: int = progress.complete(active.id, collection_ids, active.collection)
			if board.initial_minimum > 0 and board.moves <= board.initial_minimum + 1:
				achievements.event("efficient_solution")
			if earned == 3:
				pending_key_rewards.append(1)
				pending_key_rewards.append(2)
			elif earned > 0:
				pending_key_rewards.append(earned)
			achievements.evaluate()
			achievement_wait_until = Time.get_ticks_msec() + 3500
			sound.play_effect("victory")
			screen = "victory"
			grid.selected = -1
			grid.finishing = true
			grid.pivot_offset = grid.size / 2.0
			grid.scale = Vector2(1.06, 1.06)
			grid.modulate = Color(1.08, 1.03, 0.90, 1.0)
			grid.queue_redraw()
			var transition := grid.create_tween()
			transition.set_parallel(true)
			transition.tween_property(grid, "scale", Vector2.ONE, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			transition.tween_property(grid, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			transition.set_parallel(false)
			transition.tween_interval(0.2)
			transition.tween_property(grid, "gap_opacity", 0.0, 0.55)
			transition.tween_interval(0.35)
			await transition.finished
			if not is_instance_valid(grid) or screen != "victory": return
			victory()
			return
		sound.play_effect("join" if board.bond_count() > bonds_before else "move")
	draw_board()

func victory() -> void:
	screen = "victory"
	base(catalog.artwork_title(active, language), t("Puzzle completed. Artwork unlocked in your gallery."))
	artwork(texture, minf(size.y * 0.55, 470))
	var art_view: Control = page.get_child(page.get_child_count() - 1)
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.87, 0.56, 0.18)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_view.add_child(glow)
	var shine := glow.create_tween()
	shine.tween_property(glow, "color:a", 0.0, 0.8)
	shine.tween_callback(glow.queue_free)
	var explore_button := button(t("Keep exploring"), func(): collection(false, active.collection))
	var gallery_button := button(t("View in gallery"), func(): show_image(active))
	for control in [explore_button, gallery_button]:
		ornament_button(control)
		if control == gallery_button:
			for state in ["normal", "hover", "pressed", "disabled"]:
				var glass := ornament_style()
				glass.texture = load("res://art/dawn-ui/gallery.svg")
				glass.modulate_color = Color("b8b8b8") if state == "pressed" else Color.WHITE
				control.add_theme_stylebox_override(state, glass)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				control.add_theme_color_override(state, Color("fff1da"))
		control.custom_minimum_size.x = 300
		control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		control.modulate.a = 0.0
		control.disabled = true
		var entrance: Tween = control.create_tween()
		entrance.tween_interval(0.65)
		entrance.tween_property(control, "modulate:a", 1.0, 0.35)
		entrance.tween_callback(func(): control.disabled = false)

func show_completion_reward(count: int = 1, sound_kind: String = "key_received") -> void:
	sound.play_effect(sound_kind)
	var effect = preload("res://scripts/key_reward_effect.gd").new()
	effect.caption = t("+1 key") if count == 1 else t("+%d keys") % count
	add_child(effect)

func refresh_key_balance() -> void:
	for counter in get_tree().get_nodes_in_group("key_balance_count"):
		counter.text = str(progress.keys())

func show_welcome_key() -> void:
	if screen != "home" or not is_instance_valid(home_wallet): return
	for counter in get_tree().get_nodes_in_group("key_balance_count"):
		counter.text = str(maxi(0, progress.keys() - 1))
	var effect = preload("res://scripts/key_reward_effect.gd").new()
	effect.caption = t("A gift to begin your journey") + "\n" + t("+1 key")
	effect.flight_target = home_wallet
	effect.arrived.connect(func():
		refresh_key_balance()
		sound.play_effect("key_received")
	)
	add_child(effect)
	next_key_reward_at = Time.get_ticks_msec() + 3600

func show_wallet_offer() -> void:
	if is_instance_valid(wallet_dialog) and not wallet_dialog.is_queued_for_deletion(): return
	wallet_dialog = ConfirmationDialog.new()
	wallet_dialog.theme = theme
	wallet_dialog.add_theme_font_override("title_font", TITLE_FONT)
	wallet_dialog.add_theme_font_size_override("title_font_size", 28)
	wallet_dialog.title = t("Your keys")
	wallet_dialog.dialog_text = ""
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 400
	content.add_theme_constant_override("separation", 6)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load("res://art/keys/key-discovery.webp")
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size.y = 225
	art.resized.connect(func():
		var height := art.size.x * 941.0 / 1672.0
		if absf(art.custom_minimum_size.y - height) > 1.0: art.custom_minimum_size.y = height
	)
	content.add_child(art)
	var balance := Label.new()
	balance.text = t("Balance: %d key" if progress.keys() == 1 else "Balance: %d keys") % progress.keys()
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 22)
	content.add_child(balance)
	var message := RichTextLabel.new()
	message.bbcode_enabled = true
	message.fit_content = true
	message.scroll_active = false
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_font_override("normal_font", preload("res://fonts/Carlito-Regular.ttf"))
	message.add_theme_font_override("bold_font", preload("res://fonts/Carlito-Bold.ttf"))
	message.custom_minimum_size.x = 400
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("normal_font_size", 18)
	message.add_theme_font_size_override("bold_font_size", 18)
	var completed := int(progress.data.get("completion_count", 0))
	message.text = t("Your next key") + "\n[b]" + (t("%d / %d puzzles solved") % [completed, progress.PUZZLES_PER_KEY]) + "[/b]"
	content.add_child(message)
	var bar := ProgressBar.new()
	bar.max_value = progress.PUZZLES_PER_KEY
	bar.value = completed
	style_gold_progress_bar(bar)
	content.add_child(bar)
	var details := RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_theme_font_override("normal_font", preload("res://fonts/Carlito-Regular.ttf"))
	details.add_theme_font_override("bold_font", preload("res://fonts/Carlito-Bold.ttf"))
	details.custom_minimum_size.x = 400
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("normal_font_size", 18)
	details.add_theme_font_size_override("bold_font_size", 18)
	details.text = t("Solve %d more puzzles to earn a key. Replays count too.") % (progress.PUZZLES_PER_KEY - completed)
	details.text += "\n" + t("Complete a collection to earn 2 extra keys, once per collection.")
	details.text += "\n" + t("Some achievements also reward you with keys.")
	content.add_child(details)
	wallet_dialog.add_child(content)
	wallet_dialog.ok_button_text = t("Keep playing")
	wallet_dialog.cancel_button_text = t("Close")
	var dialog := wallet_dialog
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = 19
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.60)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_layer.add_child(backdrop)
	add_child(backdrop_layer)
	dialog.visibility_changed.connect(func():
		if is_instance_valid(backdrop_layer): backdrop_layer.visible = dialog.visible
	)
	dialog.tree_exiting.connect(backdrop_layer.queue_free)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		collection(false)
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 490))

func music_sort_title(title: String) -> String:
	var result := title.to_lower()
	var accents := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ü": "u", "ç": "c"}
	for accent in accents:
		result = result.replace(accent, accents[accent])
	if language == "es": result = result.replace("ñ", "n~")
	return result

func audio_volume_control(title: String, node_name: String, level: int, update: Callable) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	page.add_child(group)
	var heading := HBoxContainer.new()
	group.add_child(heading)
	var caption := Label.new()
	caption.text = title
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 20)
	heading.add_child(caption)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d / 10" % level
	value_label.add_theme_color_override("font_color", Color("f5d889"))
	heading.add_child(value_label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0
	slider.max_value = 10
	slider.step = 1
	slider.value = level
	slider.tick_count = 11
	slider.ticks_on_borders = true
	slider.custom_minimum_size.y = 48
	for style_name in ["slider", "grabber_area", "grabber_area_highlight"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("343344") if style_name == "slider" else Color("c9ad76")
		style.set_corner_radius_all(3)
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		slider.add_theme_stylebox_override(style_name, style)
	group.add_child(slider)
	slider.value_changed.connect(func(value: float):
		value_label.text = "%d / 10" % int(value)
		update.call(int(value))
		save_audio_settings()
	)

func options_settings() -> void:
	screen = "options"
	base(t("Options"), t("Make this moment yours."))
	page_back(home)
	var music_heading := label(t("Background music"), 24)
	music_heading.add_theme_font_override("font", preload("res://fonts/Carlito-Bold.ttf"))
	var track_picker := OptionButton.new()
	track_picker.custom_minimum_size.y = 48
	track_picker.add_item("🎲 " + t("Random"))
	track_picker.set_item_metadata(0, "random")
	var ordered_tracks: Array = sound.TRACKS.duplicate()
	ordered_tracks.sort_custom(func(a: Dictionary, b: Dictionary):
		return music_sort_title(t(a.title)).naturalnocasecmp_to(music_sort_title(t(b.title))) < 0
	)
	for track in ordered_tracks:
		track_picker.add_item(str(track.emoji) + " " + t(track.title))
		var index := track_picker.item_count - 1
		track_picker.set_item_metadata(index, track.id)
		if sound.selection == track.id: track_picker.select(index)
	page.add_child(track_picker)
	track_picker.item_selected.connect(func(index):
		var previous_track: String = sound.current_track
		sound.select_track(str(track_picker.get_item_metadata(index)))
		if sound.current_track != previous_track: achievements.event("music")
		save_audio_settings()
		options_settings()
	)
	var now_playing_row := HBoxContainer.new()
	now_playing_row.add_theme_constant_override("separation", 12)
	page.add_child(now_playing_row)
	var now_playing := label(t("Now playing: %s") % t(sound.current_title()), 16)
	now_playing.name = "NowPlaying"
	now_playing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	now_playing.reparent(now_playing_row)
	# Reserve the longest translated title so rerolling never moves the die.
	var track_font := now_playing.get_theme_font("font")
	for track in sound.TRACKS:
		var text_width := track_font.get_string_size(t("Now playing: %s") % t(track.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		now_playing.custom_minimum_size.x = maxf(now_playing.custom_minimum_size.x, ceilf(text_width))
	if sound.selection == "random":
		var shuffle := Button.new()
		shuffle.name = "ShuffleMusic"
		shuffle.icon = preload("res://art/dawn-ui/dice.svg")
		shuffle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shuffle.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		shuffle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shuffle.tooltip_text = t("Another track")
		shuffle.custom_minimum_size = Vector2(48, 48)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("343344") if state in ["hover", "pressed"] else Color("222332")
			style.set_corner_radius_all(6)
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			shuffle.add_theme_stylebox_override(state, style)
		now_playing_row.add_child(shuffle)
		shuffle.pressed.connect(func():
			sound.play_effect("select")
			sound.select_track("random")
			achievements.event("music")
			now_playing.text = t("Now playing: %s") % t(sound.current_title())
		)
	audio_volume_control({"pt": "Volume da música", "en": "Music volume", "es": "Volumen de la música"}.get(language, "Music volume"), "MusicVolume", sound.music_level, sound.set_music_level)
	audio_volume_control({"pt": "Volume dos efeitos sonoros", "en": "Sound effects volume", "es": "Volumen de los efectos"}.get(language, "Sound effects volume"), "EffectsVolume", sound.effects_level, func(level: int):
		sound.set_effects_level(level)
		sound.play_effect("select")
	)
	var language_heading := label(t("Language"), 28)
	language_heading.add_theme_font_override("font", preload("res://fonts/Carlito-Bold.ttf"))
	var language_picker := OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.custom_minimum_size.y = 48
	language_picker.add_theme_font_override("font", preload("res://fonts/Carlito-Regular.ttf"))
	language_picker.add_theme_font_size_override("font_size", 22)
	language_picker.get_popup().add_theme_font_override("font", preload("res://fonts/Carlito-Regular.ttf"))
	language_picker.get_popup().add_theme_font_size_override("font_size", 22)
	for code in ["en", "pt", "es"]:
		language_picker.add_item({"en": "English", "pt": "Português", "es": "Español"}[code])
		var index := language_picker.item_count - 1
		language_picker.set_item_metadata(index, code)
		if language == code: language_picker.select(index)
	page.add_child(language_picker)
	language_picker.item_selected.connect(func(index):
		set_language(str(language_picker.get_item_metadata(index)))
	)
	var footer_actions := HBoxContainer.new()
	footer_actions.name = "OptionsFooter"
	footer_actions.add_theme_constant_override("separation", 12)
	page.add_child(footer_actions)
	var about_button := button(t("About the game"), about_screen)
	about_button.name = "AboutGameButton"
	about_button.reparent(footer_actions)
	about_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about_button.size_flags_stretch_ratio = 1.6
	about_button.add_theme_font_size_override("font_size", 22)
	ornament_button(about_button)
	var options_back := button(t("Back"), home)
	options_back.name = "OptionsBackButton"
	options_back.reparent(footer_actions)
	options_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_back.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var glass := ornament_style()
		glass.texture = load("res://art/dawn-ui/gallery.svg")
		glass.modulate_color = Color("b8b8b8") if state == "pressed" else Color.WHITE
		options_back.add_theme_stylebox_override(state, glass)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		options_back.add_theme_color_override(state, Color("fff1da"))
	for control in page.get_children():
		if control is Button:
			control.add_theme_font_size_override("font_size", 22)
	track_picker.get_popup().add_theme_font_size_override("font_size", 22)

func about_screen() -> void:
	screen = "about"
	var translations: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/about.json"))
	var copy: Dictionary = translations.get(language, translations.en)
	base(copy.title, copy.subtitle)
	page_back(options_settings)
	about_art("res://content/images/01_Quiet_Moments/11_Garden_of_Dawn.webp")
	label(copy.story_title, 28, Color("ffe3a0"))
	label(copy.story, 20)
	about_art("res://content/images/03_High_Fantasy/03_Dawn_Between_Worlds.webp")
	label(copy.developer_title, 28, Color("ffe3a0"))
	label(copy.developer, 20)
	about_art("res://art/dawn-ui/hero.webp")
	label(copy.closing, 20, Color("e8cf97"))
	var divider := HSeparator.new()
	page.add_child(divider)
	var disclosure_heading := label(copy.disclosure_title, 22, Color("e8cf97"))
	disclosure_heading.add_theme_font_override("font", preload("res://fonts/Carlito-Regular.ttf"))
	label(copy.disclosure, 18, Color("bcb8c8"))
	var creator := RichTextLabel.new()
	creator.bbcode_enabled = true
	creator.fit_content = true
	creator.scroll_active = false
	creator.text = copy.creator
	creator.add_theme_font_override("normal_font", preload("res://fonts/Carlito-Regular.ttf"))
	creator.add_theme_font_override("bold_font", preload("res://fonts/Carlito-Bold.ttf"))
	creator.add_theme_font_size_override("normal_font_size", 20)
	creator.add_theme_color_override("default_color", Color("e8cf97"))
	creator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(creator)
	achievements.event("about_game")
	progress.save()

func about_art(path: String) -> void:
	var image: Texture2D = load(path)
	var frame := AspectRatioContainer.new()
	frame.ratio = image.get_width() / float(image.get_height())
	frame.stretch_mode = AspectRatioContainer.STRETCH_WIDTH_CONTROLS_HEIGHT
	frame.custom_minimum_size.y = maxf(1.0, (get_viewport_rect().size.x - 48.0) / frame.ratio)
	page.resized.connect(func():
		if is_instance_valid(frame): frame.custom_minimum_size.y = maxf(1.0, page.size.x / frame.ratio)
	)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(frame)
	var view := TextureRect.new()
	view.texture = image
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(view)
	var border := Panel.new()
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(1)
	style.border_color = Color("c6a669")
	border.add_theme_stylebox_override("panel", style)
	view.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func achievement_label(value: String, font_size: int, color := Color("eee6d7")) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func achievement_content(definition: Array, unlocked: bool, notification := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE if notification else Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = achievements.icon(definition)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(60, 60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.6)
	row.add_child(icon)
	if definition[0] in ["all_puzzles", "bonus", "fifty_keys", "view_twenty", "sixty_keys", "seventy_seven"]:
		var halo := Panel.new()
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.show_behind_parent = true
		var glow_style := StyleBoxFlat.new()
		glow_style.bg_color = Color(1.0, 0.70, 0.22, 0.06)
		glow_style.shadow_color = Color(1.0, 0.70, 0.22, 0.28)
		glow_style.shadow_size = 8
		glow_style.set_corner_radius_all(30)
		if definition[0] in ["sixty_keys", "seventy_seven"]:
			glow_style.set_corner_radius_all(2)
			glow_style.bg_color = Color.TRANSPARENT
			glow_style.set_border_width_all(1)
			glow_style.border_color = Color("eac46e")
		halo.add_theme_stylebox_override("panel", glow_style)
		icon.add_child(halo)
		halo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		halo.offset_left = -30
		halo.offset_top = -30
		halo.offset_right = 30
		halo.offset_bottom = 30
	if definition[0] == "seventy_seven":
		var number := Label.new()
		number.text = "77"
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_override("font", preload("res://fonts/Carlito-Bold.ttf"))
		number.add_theme_font_size_override("font_size", 30)
		number.add_theme_color_override("font_color", Color("fff0bd"))
		number.add_theme_color_override("font_outline_color", Color("181422"))
		number.add_theme_constant_override("outline_size", 5)
		icon.add_child(number)
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text := VBoxContainer.new()
	text.mouse_filter = row.mouse_filter
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if notification: text.add_child(achievement_label(t("Achievement unlocked"), 13, Color("d7bb82")))
	text.add_child(achievement_label(achievements.title(definition, language), 21, Color("ffe3a0") if unlocked else Color("bbb8c4")))
	text.add_child(achievement_label(achievements.description(definition, language), 16))
	if achievements.awards_key(definition[0]):
		var reward_column := VBoxContainer.new()
		reward_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_column.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(reward_column)
		var reward_icon := TextureRect.new()
		reward_icon.name = "AchievementKeyReward"
		reward_icon.texture = preload("res://art/dawn-ui/chave.svg")
		reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reward_icon.custom_minimum_size = Vector2(24, 24)
		reward_icon.modulate = Color.WHITE if unlocked else Color(0.7, 0.7, 0.75)
		reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_column.add_child(reward_icon)
	return row

func achievements_screen() -> void:
	screen = "achievements"
	base(t("Achievements"), t("Small steps. Lasting treasures."))
	page_back(home)
	achievements.evaluate()
	label(t("%d / %d unlocked") % [achievements.state().unlocked.size(), achievements.DEFINITIONS.size()], 18)
	var values: Dictionary = achievements.metrics()
	for definition in achievements.sorted_definitions(language):
		var unlocked: bool = definition[0] in achievements.state().unlocked
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_theme_stylebox_override("panel", home_style(Color("202130"), Color("ad8a4c") if unlocked else Color("414150")))
		page.add_child(card)
		var row := achievement_content(definition, unlocked)
		card.add_child(row)
		var text: VBoxContainer = row.get_child(1)
		var target: int = achievements.target(definition)
		var count: int = target if unlocked else mini(int(values.get(definition[5], 0)), target)
		text.add_child(achievement_label(t("Unlocked") if unlocked else "%d / %d" % [count, target], 14, Color("d8b873")))
		if definition[0] == "six_seven" and unlocked:
			var replay := Button.new()
			replay.name = "SixSevenReplay"
			replay.flat = true
			replay.mouse_filter = Control.MOUSE_FILTER_PASS
			replay.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			replay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			for state in ["normal", "hover", "pressed", "focus"]:
				replay.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			replay.pressed.connect(replay_six_seven)
			card.add_child(replay)
			replay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if not unlocked:
			var bar := ProgressBar.new()
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.max_value = target
			bar.value = count
			bar.show_percentage = false
			bar.custom_minimum_size.y = 5
			text.add_child(bar)

func process_achievement_queue() -> void:
	if not is_instance_valid(achievement_layer): return
	if six_seven_prelude_active: return
	var blocked := Time.get_ticks_msec() < achievement_wait_until or (screen == "victory" and is_instance_valid(grid)) or get_children().any(func(child): return child is AcceptDialog and child.visible)
	if is_instance_valid(achievement_banner):
		achievement_banner.visible = not blocked
		if is_instance_valid(achievement_animation) and achievement_animation.is_valid():
			if blocked: achievement_animation.pause()
			elif not achievement_animation.is_running(): achievement_animation.play()
		return
	if blocked or achievements.state().pending.is_empty(): return
	var id: String = achievements.state().pending[0]
	if id == "six_seven" and not six_seven_prelude_shown:
		show_six_seven_prelude()
		return
	var definition: Array = achievements.definition_for(id)
	if definition.is_empty():
		achievements.state().pending.pop_front()
		progress.save()
		return
	achievement_banner = PanelContainer.new()
	var banner := achievement_banner
	banner.theme = theme
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", home_style(Color(0.10, 0.10, 0.16, 0.96), Color("d8b976")))
	achievement_layer.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_left = 16
	banner.offset_right = -16
	banner.offset_top = -160
	banner.offset_bottom = -160
	banner.add_child(achievement_content(definition, true, true))
	banner.modulate.a = 0
	if sound.effects_enabled: sound.play_effect("join")
	var animation := banner.create_tween()
	achievement_animation = animation
	animation.set_parallel(true)
	animation.tween_property(banner, "position:y", 18.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(banner, "modulate:a", 1.0, 0.35)
	animation.set_parallel(false)
	animation.tween_interval(5.0)
	animation.tween_property(banner, "modulate:a", 0.0, 0.4)
	animation.tween_callback(func():
		achievements.state().pending.erase(id)
		progress.save()
		banner.queue_free()
		achievement_wait_until = Time.get_ticks_msec() + 400
	)

func replay_six_seven() -> void:
	if screen != "achievements" or "six_seven" not in achievements.state().unlocked: return
	if six_seven_prelude_active or Time.get_ticks_msec() < six_seven_replay_available_at: return
	show_six_seven_prelude(true)

func show_six_seven_prelude(replay := false) -> void:
	six_seven_prelude_active = true
	if not replay: six_seven_prelude_shown = true
	six_seven_replay_available_at = Time.get_ticks_msec() + SIX_SEVEN_REPLAY_COOLDOWN_MS
	achievement_wait_until = maxi(achievement_wait_until, Time.get_ticks_msec() + (6000 if replay else 4600))
	var presentation := Control.new()
	presentation.name = "SixSevenPresentation"
	presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presentation.mouse_filter = Control.MOUSE_FILTER_STOP
	achievement_layer.add_child(presentation)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.09, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(dim)
	var art := TextureRect.new()
	art.texture = load("res://art/achievements/six-seven.webp")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(art)
	var fit := func():
		var side := minf(size.x - 32.0, size.y - 100.0)
		art.size = Vector2(side, side)
		art.position = (size - art.size) / 2.0
		art.pivot_offset = art.size / 2.0
	fit.call()
	presentation.resized.connect(fit)
	art.scale = Vector2(0.94, 0.94)
	presentation.modulate.a = 0.0
	sound.play_effect("victory")
	var reveal := presentation.create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(presentation, "modulate:a", 1.0, 0.3)
	reveal.tween_property(art, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.set_parallel(false)
	reveal.tween_interval(5.0 if replay else 3.5)
	reveal.tween_property(presentation, "modulate:a", 0.0, 0.4)
	reveal.tween_callback(func():
		presentation.queue_free()
		six_seven_prelude_active = false
	)

func set_language(code: String) -> void:
	if code not in ["en", "pt", "es"]: return
	language = code
	DisplayServer.window_set_title(t("Fragments of Dawn"))
	progress.data.language = code
	progress.save()
	options_settings()

func t(message: String) -> String:
	return Locale.text(message, language)

func key_image(icon_size: float = 24.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = KEY_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.tooltip_text = t("Keys")
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	return icon

func key_balance(icon_size: float = 32.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_meta("key_balance", true)
	row.add_child(key_image(icon_size))
	var count := Label.new()
	count.add_to_group("key_balance_count")
	count.text = str(progress.keys())
	count.add_theme_color_override("font_color", Color("f5d889"))
	row.add_child(count)
	page.add_child(row)

func save_audio_settings() -> void:
	progress.data.audio = {"music": sound.music_enabled, "effects": sound.effects_enabled, "music_level": sound.music_level, "effects_level": sound.effects_level, "track": sound.selection}
	progress.save()
