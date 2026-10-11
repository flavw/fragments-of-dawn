extends Node
var music := AudioStreamPlayer.new()
var effect := AudioStreamPlayer.new()
var music_enabled := true
var effects_enabled := true
var music_level := 10
var effects_level := 10
const TRACKS := [
	{"id": "sweet_banter", "emoji": "💗", "title": "Sweet Banter"},
	{"id": "enchanted_lanterns", "emoji": "🎃", "title": "Enchanted Lanterns"},
	{"id": "dawns_reverie", "emoji": "🌅", "title": "Dawn’s Reverie"},
	{"id": "dawns_reverie_alternative", "emoji": "☀️", "title": "Dawn’s Reverie II"},
	{"id": "velvet_dawn", "emoji": "🌄", "title": "Velvet Dawn"},
	{"id": "moonlit_garden", "emoji": "🌙", "title": "Moonlit Garden"},
	{"id": "silver_rain", "emoji": "🌧️", "title": "Silver Rain"},
	{"id": "gentle_tides", "emoji": "🌊", "title": "Gentle Tides"},
	{"id": "quiet_stars", "emoji": "✨", "title": "Quiet Stars"},
	{"id": "amber_dreams", "emoji": "💫", "title": "Amber Dreams"},
]
var selection := "dawns_reverie"
var current_track := ""
var friendship_music_active := false
var previous_music: AudioStream
var previous_position := 0.0

func set_friendship_music(active: bool) -> void:
	if active == friendship_music_active: return
	friendship_music_active = active
	if active:
		previous_music = music.stream
		previous_position = music.get_playback_position()
		music.stop()
		music.stream = load("res://audio/sweet_banter.ogg")
		music.stream.loop = true
		if music_enabled: music.play()
	else:
		music.stop()
		music.stream = previous_music
		if music_enabled and music.stream != null: music.play(previous_position)
		previous_music = null

func _ready() -> void:
	add_child(music)
	add_child(effect)
	music.volume_db = -5
	effect.volume_db = -7
	music.finished.connect(func():
		if music_enabled: music.play()
	)

func configure(settings: Dictionary) -> void:
	set_music_level(int(settings.get("music_level", 10 if settings.get("music", true) else 0)))
	set_effects_level(int(settings.get("effects_level", 10 if settings.get("effects", true) else 0)))
	var requested: String = str(settings.get("track", selection))
	if current_track.is_empty() or requested != selection: select_track(requested)
	if music_enabled and not music.playing: music.play()
	elif not music_enabled: music.stop()

func set_music_level(level: int) -> void:
	music_level = clampi(level, 0, 10)
	music_enabled = music_level > 0
	music.volume_linear = db_to_linear(-5.0) * music_level / 10.0
	if not music_enabled: music.stop()
	elif music.stream != null and not music.playing: music.play()

func set_effects_level(level: int) -> void:
	effects_level = clampi(level, 0, 10)
	effects_enabled = effects_level > 0
	effect.volume_linear = db_to_linear(-7.0) * effects_level / 10.0
	if not effects_enabled: effect.stop()

func select_track(track_id: String) -> void:
	var ids: Array = TRACKS.map(func(track): return track.id)
	selection = track_id if track_id in ids else "random"
	if selection == "random":
		var candidates := ids.filter(func(id): return id != current_track)
		current_track = candidates.pick_random()
	else:
		current_track = selection
	music.stop()
	music.stream = load("res://audio/" + current_track + ".ogg")
	music.stream.loop = true
	if music_enabled: music.play()

func current_title() -> String:
	for track in TRACKS:
		if track.id == current_track: return track.title
	return ""

func play_effect(kind: String) -> void:
	if not effects_enabled: return
	effect.stop()
	effect.stream = load("res://audio/" + kind + ".ogg")
	effect.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		music.stream_paused = true
		effect.stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		music.stream_paused = false


func _exit_tree() -> void:
	music.stop()
	effect.stop()
