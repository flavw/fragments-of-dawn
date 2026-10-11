extends RefCounted

const PUZZLES_PER_KEY := 4
const MAX_KEYS := 99
var path := "user://progress.json"
var data: Dictionary = {"version": 1, "unlocked": [], "solved": [], "sessions": {}}
var save_error := false

func keys() -> int:
	return clampi(int(data.get("keys", 0)), 0, MAX_KEYS)

func collected_keys() -> int:
	# Existing saves retain the minimum lifetime total recoverable from balance and spending.
	return maxi(int(data.get("keys_collected", 0)), keys() + int(data.get("keys_spent", 0)))

func migrate_catalog_ids(entries: Array) -> void:
	var changed := false
	for entry in entries:
		if entry.id == entry.path: continue
		var aliases := [str(entry.path)]
		for previous_id in aliases:
			for field in ["unlocked", "solved"]:
				if previous_id in data[field]:
					data[field].erase(previous_id)
					if entry.id not in data[field]: data[field].append(entry.id)
					changed = true
			for session in data.sessions.keys():
				if str(session).begins_with(previous_id + "|"):
					var replacement := str(entry.id) + "|" + str(session).get_slice("|", 1)
					if not data.sessions.has(replacement): data.sessions[replacement] = data.sessions[session]
					data.sessions.erase(session)
					changed = true
	if changed: save()

func grant_key() -> bool:
	if keys() >= MAX_KEYS: return false
	data["keys_collected"] = collected_keys() + 1
	data.keys = keys() + 1
	save()
	return true

func claim_welcome_key() -> bool:
	if data.get("welcome_key_claimed", false): return false
	data["welcome_key_claimed"] = true
	var granted := grant_key()
	save()
	return granted

func spend_key(id: String, allowed_ids: Array) -> bool:
	if keys() < 1 or id not in allowed_ids or id in data.unlocked:
		return false
	data.keys = keys() - 1
	data["keys_spent"] = int(data.get("keys_spent", 0)) + 1
	data.unlocked.append(id)
	save()
	return true

func read_save() -> void:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and parsed.get("version") == 1 and parsed.get("unlocked") is Array and parsed.get("solved") is Array and parsed.get("sessions") is Dictionary:
			data = parsed
			data.erase("next_daily")
			data.erase("last_seen")
			return

func save() -> void:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = true
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var error := DirAccess.rename_absolute(path + ".tmp", path)
	save_error = error != OK

func complete(id: String, collection_ids: Array = [], collection_name: String = "") -> int:
	if not id in data.unlocked:
		return 0
	var earned := 0
	data["total_plays"] = maxi(int(data.get("total_plays", 0)), data.solved.size()) + 1
	if id in data.solved: data["total_replays"] = int(data.get("total_replays", 0)) + 1
	if not id in data.solved:
		data.solved.append(id)
	# Every finished play counts, including replays, without a daily limit.
	data.completion_count = int(data.get("completion_count", 0)) + 1
	if int(data.completion_count) >= PUZZLES_PER_KEY:
		data.completion_count = int(data.completion_count) - PUZZLES_PER_KEY
		if grant_key(): earned += 1
		data["completion_keys_earned"] = int(data.get("completion_keys_earned", 0)) + 1
	var rewarded_collections: Array = data.get("rewarded_collections", [])
	if not collection_name.is_empty() and not collection_ids.is_empty() and collection_name not in rewarded_collections:
		if collection_ids.all(func(art_id): return art_id in data.solved):
			rewarded_collections.append(collection_name)
			data["rewarded_collections"] = rewarded_collections
			if grant_key(): earned += 1
			if grant_key(): earned += 1
	for key in data.sessions.keys():
		if key.begins_with(id + "|"):
			data.sessions.erase(key)
	save()
	return earned

func ensure_permanent(ids: Array) -> void:
	var changed := false
	for id in ids:
		if not id in data.unlocked:
			data.unlocked.append(id)
			changed = true
	if changed: save()

func migrate_initial_collection_policy(key_locked_ids: Array) -> void:
	if data.get("initial_collection_policy", false):
		return
	data.unlocked = data.unlocked.filter(func(id): return not id in key_locked_ids or id in data.solved)
	data.initial_collection_policy = true
	save()

func apply_six_free_policy(entries: Array) -> void:
	if data.get("six_free_policy", false): return
	var former_free: Array = []
	var seen: Array = []
	var quiet_index := 0
	for entry in entries:
		if entry.collection == "Quiet Moments":
			quiet_index += 1
			if quiet_index > 6: former_free.append(entry.id)
		elif entry.collection not in seen:
			former_free.append(entry.id)
		if entry.collection not in seen: seen.append(entry.collection)
	data.unlocked = data.unlocked.filter(func(id): return id not in former_free or id in data.solved)
	data["six_free_policy"] = true
	save()
