extends RefCounted

var entries: Array[Dictionary] = []
var artwork_titles: Dictionary = {}

func scan() -> void:
	entries.clear()
	artwork_titles.clear()
	var translations_path := "res://content/artwork_titles.json"
	if FileAccess.file_exists(translations_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(translations_path))
		if parsed is Dictionary: artwork_titles = parsed
	_scan_folder("res://content/images")
	entries.sort_custom(func(a, b): return a.path < b.path)

func _scan_folder(folder: String) -> void:
	for file in ResourceLoader.list_directory(folder):
		if file.ends_with("/"):
			_scan_folder(folder.path_join(file.trim_suffix("/")))
		elif file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg"]:
			var path := folder.path_join(file)
			if ResourceLoader.exists(path, "Texture2D"):
				var identity := path
				var naming := parse_filename(file.get_basename())
				var title: String = naming.title
				var subtitle: String = naming.subtitle
				var relative := path.trim_prefix("res://content/images/")
				var collection := "Other Discoveries"
				if "/" in relative:
					collection = display_name(relative.get_slice("/", 0))
				if "/02_Golden_Tides/" in path:
					collection = "Golden Tides"
					# Keep saved progress attached to artworks after changing their order.
					if file == "09_Dawn by the Sea.webp":
						identity = folder.path_join("01_Dawn by the Sea.webp")
					elif file == "01_Lavender Shore.webp":
						identity = folder.path_join("04_Lavender Shore.webp")
				elif "/05_Sporting_Moments/" in path:
					# Preserve saved unlocks, completions and sessions after reordering.
					identity = path.replace("/05_Sporting_Moments/", "/06_Sporting_Moments/")
				entries.append({"id": identity, "title": title, "subtitle": subtitle, "path": path, "collection": collection})

func ids() -> Array:
	return entries.map(func(e): return e.id)

func artwork_title(entry: Dictionary, language: String) -> String:
	var relative := str(entry.path).trim_prefix("res://content/images/")
	var names = artwork_titles.get(relative, artwork_titles.get(relative.get_file(), {}))
	if not names is Dictionary or names.is_empty():
		for key in artwork_titles.keys():
			if str(key).ends_with("/" + relative.get_file()):
				names = artwork_titles[key]
				break
	if names is Dictionary:
		var translated = names.get(language, "")
		if translated is String and not translated.strip_edges().is_empty():
			return translated
	return str(entry.title)

func permanent_ids() -> Array:
	var free_ids: Array = []
	# Only the first six artworks of Quiet Moments are available without keys.
	for entry in entries:
		if entry.collection == "Quiet Moments" and free_ids.size() < 6:
			free_ids.append(entry.id)
	return free_ids

func key_locked_ids() -> Array:
	return ids().filter(func(id): return not id in permanent_ids())

func collections() -> Array:
	var names: Array = []
	for entry in entries:
		if not entry.collection in names: names.append(entry.collection)
	return names

func display_name(value: String) -> String:
	var result := value
	var prefix := result.get_slice("_", 0)
	if prefix.is_valid_int() and "_" in result: result = result.substr(prefix.length() + 1)
	return result.replace("_", " ").capitalize()

func parse_filename(value: String) -> Dictionary:
	var parts := value.split("-", true, 1)
	var title := parts[0].strip_edges()
	var prefix := title.get_slice("_", 0)
	if prefix.is_valid_int() and "_" in title: title = title.substr(prefix.length() + 1)
	title = title.replace("_", " ")
	var subtitle := parts[1].strip_edges() if parts.size() > 1 else ""
	return {"title": title, "subtitle": subtitle}
