extends RefCounted

var progress
var catalog
var encounters: Array = []

func setup(saved_progress, artwork_catalog) -> void:
	progress = saved_progress
	catalog = artwork_catalog
	encounters = JSON.parse_string(FileAccess.get_file_as_string("res://content/friendships.json"))
	if not progress.data.get("friendships") is Dictionary: progress.data["friendships"] = {}

func available(encounter: Dictionary) -> bool:
	return collection_available(collection_name(encounter)) and catalog.entries.any(func(entry): return entry.path == encounter.art and entry.id in progress.data.solved)

func collection_name(encounter: Dictionary) -> String:
	return str(encounter.get("collection", "Quiet Moments"))

func collection_completed(name: String) -> int:
	return encounters.filter(func(e): return collection_name(e) == name and completed(e)).size()

func collection_available(name: String) -> bool:
	return name != "Golden Tides" or collection_completed("Quiet Moments") >= 12

func character_name(encounter: Dictionary, language: String) -> String:
	return text(encounter.display_name, language) if encounter.has("display_name") else str(encounter.name)

func completed(encounter: Dictionary) -> bool:
	return progress.data.friendships.get(encounter.id, {}).get("completed", false)

func finish(encounter: Dictionary, branch: int, choice: int) -> Dictionary:
	if not available(encounter) or branch < 0 or branch >= encounter.branches.size(): return {}
	var options: Array = encounter.branches[branch].choices
	if choice < 0 or choice >= options.size(): return {}
	var record: Dictionary = progress.data.friendships.get(encounter.id, {"endings": []})
	var ending := "%d:%d" % [branch, choice]
	if ending not in record.endings: record.endings.append(ending)
	record.completed = true
	progress.data.friendships[encounter.id] = record
	var earned := 0
	var received := clampi(int(record.get("reward_total", record.get("first_reward", 0))), 0, 2)
	var answer_quality := clampi(int(options[choice].reward), 0, 2)
	record["best_quality"] = maxi(int(record.get("best_quality", received)), answer_quality)
	var target := mini(answer_quality, 1)
	for i in range(maxi(0, target - received)):
		if progress.grant_key(): earned += 1
	record["reward_total"] = received + earned
	record.erase("first_reward")
	progress.save()
	return {"total": received + earned, "earned": earned, "ending": options[choice].ending}

func text(localized: Dictionary, language: String) -> String:
	return str(localized.get(language, localized.get("en", "")))
