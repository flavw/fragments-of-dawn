extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog = load("res://scripts/catalog.gd").new()
	catalog.scan()
	assert(catalog.entries.size() == 80)
	assert(catalog.collections().size() == 7)
	assert(catalog.permanent_ids().size() == 6)
	var progress = load("res://scripts/progress.gd").new()
	progress.path = "user://source-check.json"
	progress.data = {"version": 1, "unlocked": ["test"], "solved": [], "sessions": {}}
	for count in range(3): assert(progress.complete("test") == 0)
	assert(progress.complete("test") == 1)
	assert(progress.keys() == 1)
	var achievements = load("res://scripts/achievements.gd").new()
	achievements.setup(progress, catalog)
	assert(achievements.DEFINITIONS.size() == 74)
	for definition in achievements.DEFINITIONS:
		assert(achievements.icon(definition) != null)
		for language in ["en", "pt", "es"]:
			assert(not achievements.title(definition, language).is_empty())
			assert(not achievements.description(definition, language).is_empty())
	var friends = load("res://scripts/friendships.gd").new()
	friends.setup(progress, catalog)
	assert(friends.encounters.size() == 24)
	for encounter in friends.encounters:
		assert(ResourceLoader.exists(encounter.art))
	for name in ["Carlito-Regular.ttf", "Carlito-Bold.ttf", "KaushanScript-Regular.ttf"]:
		var font: Font = load("res://fonts/" + name)
		for character in "áéíóúãõçñ": assert(font.has_char(character.unicode_at(0)))
	var scene = load("res://main.tscn").instantiate()
	scene.progress.path = "user://source-ui-check.json"
	root.add_child(scene)
	await process_frame
	for language in ["en", "pt", "es"]:
		scene.language = language
		scene.achievements_screen()
		await process_frame
	print("PASS: catalogue, four-win rewards, 74 achievement icons, 24 encounters, font accents and trilingual UI")
	scene.queue_free()
	await process_frame
	quit()
