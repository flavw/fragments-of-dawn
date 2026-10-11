extends RefCounted
signal key_earned
const DAWN_KEY_ACHIEVEMENTS := ["found_dawn", "beach_dawn", "archery_dawn", "dimensional_dawn", "sweet_dawn", "crystal_haunting", "dusk_dawn"]
const EXPLORATION_KEY_ACHIEVEMENTS := ["fifty", "worlds", "view_ten", "ten", "twenty_five", "music", "six_seven", "efficient_solution"]
const MEDAL_KEY_ACHIEVEMENTS := ["bronze", "silver", "gold"]
const REPLAY_KEY_ACHIEVEMENTS := ["plays_ten", "replay", "ten_replays"]
## Stable IDs are saved independently of artwork counts and translated names.
const DEFINITIONS := [
	["affinity_golden_01", "A Sunny Laugh with Violet", "Uma Risada ao Sol com Violet", "Share another playful moment with Violet by the sea.", "Compartilhe mais um momento divertido com Violet à beira-mar.", "affinity_golden_01", 1, "friendship-heart"],
	["affinity_golden_02", "Moonlit Waves with Selene", "Ondas de Luar com Selene", "Find a shared rhythm with Selene beneath the moonlight.", "Encontre uma sintonia com Selene sob o luar.", "affinity_golden_02", 1, "friendship-heart"],
	["affinity_golden_03", "A New Canvas with Marina", "Uma Nova Tela com Marina", "Inspire Marina with a creative answer on the shore.", "Inspire Marina com uma resposta criativa à beira-mar.", "affinity_golden_03", 1, "friendship-heart"],
	["affinity_golden_04", "Seaside Serenity with Iris", "Serenidade à Beira-Mar com Iris", "Make Iris feel at ease in her peaceful cove.", "Deixe Iris à vontade em sua enseada tranquila.", "affinity_golden_04", 1, "friendship-heart"],
	["affinity_golden_05", "Sunset Celebration with Lia", "Festa ao Pôr do Sol com Lia", "Delight Lia with your enthusiasm for a seaside celebration.", "Encante Lia com seu entusiasmo por uma festa à beira-mar.", "affinity_golden_05", 1, "friendship-heart"],
	["affinity_golden_06", "Seaside Charm with Celeste", "Encanto à Beira-Mar com Celeste", "Charm Celeste with your thoughtful company by the waves.", "Encante Celeste com sua companhia atenciosa junto às ondas.", "affinity_golden_06", 1, "friendship-heart"],
	["affinity_golden_07", "The Last Page with Clara", "A Última Página com Clara", "Share a quiet connection with Clara as the sun sets.", "Compartilhe uma conexão tranquila com Clara ao pôr do sol.", "affinity_golden_07", 1, "friendship-heart"],
	["affinity_golden_08", "A Radiant Day with Flora", "Um Dia Radiante com Flora", "Make Flora feel radiant during your beach reunion.", "Faça Flora se sentir radiante no reencontro na praia.", "affinity_golden_08", 1, "friendship-heart"],
	["affinity_golden_09", "A Pause Between Worlds", "Uma Pausa Entre Mundos", "Touch Dawn’s heart during her seaside pause.", "Toque o coração de Aurora em sua pausa à beira-mar.", "affinity_golden_09", 1, "friendship-heart"],
	["affinity_golden_10", "Petals by the Sea with Aiko", "Pétalas à Beira-Mar com Aiko", "Create a special seaside memory with Aiko.", "Crie uma lembrança especial à beira-mar com Aiko.", "affinity_golden_10", 1, "friendship-heart"],
	["affinity_golden_11", "Jasmine in the Breeze with Yasmin", "Jasmim na Brisa com Yasmin", "Make Yasmin feel welcome on your seaside stroll.", "Faça Yasmin se sentir acolhida no passeio à beira-mar.", "affinity_golden_11", 1, "friendship-heart"],
	["affinity_golden_12", "A Shell and a Secret with Rosa", "Uma Concha e um Segredo com Rosa", "Help Rosa share her thoughts about her little shell.", "Ajude Rosa a compartilhar seus pensamentos sobre a conchinha.", "affinity_golden_12", 1, "friendship-heart"],
	["affinity_violet_garden", "Violet Likes Your Humor", "Violet Gostou do Seu Humor", "Win Violet over with a playful answer in New Friendships.", "Conquiste a simpatia de Violet com uma resposta divertida em Novas Amizades.", "affinity_violet_garden", 1, "friendship-heart"],
	["affinity_selene_serenade", "In Tune with Selene", "Em Sintonia com Selene", "Make Selene feel understood in New Friendships.", "Faça Selene se sentir compreendida em Novas Amizades.", "affinity_selene_serenade", 1, "friendship-heart"],
	["affinity_marina_watercolors", "Different Colors with Marina", "Diferentes Cores com Marina", "Delight Marina with your creativity in New Friendships.", "Encante Marina com sua criatividade em Novas Amizades.", "affinity_marina_watercolors", 1, "friendship-heart"],
	["affinity_iris_stillness", "A Quiet Bond with Iris", "Um Laço Tranquilo com Iris", "Make Iris feel at ease with your thoughtful company in New Friendships.", "Deixe Iris à vontade com sua companhia atenciosa em Novas Amizades.", "affinity_iris_stillness", 1, "friendship-heart"],
	["affinity_quiet_05", "Lia Wants You at Her Picnic", "No Piquenique de Lia", "Share Lia’s enthusiasm in New Friendships.", "Compartilhe o entusiasmo de Lia em Novas Amizades.", "affinity_quiet_05", 1, "friendship-heart"],
	["affinity_quiet_06", "Celeste Enjoys Your Company", "Uma Boa Companhia para Celeste", "Charm Celeste with a considerate answer in New Friendships.", "Encante Celeste com uma resposta atenciosa em Novas Amizades.", "affinity_quiet_06", 1, "friendship-heart"],
	["affinity_quiet_07", "A New Chapter with Clara", "Um Novo Capítulo com Clara", "Find a special connection with Clara in New Friendships.", "Encontre uma conexão especial com Clara em Novas Amizades.", "affinity_quiet_07", 1, "friendship-heart"],
	["affinity_quiet_08", "Flora Found an Adventure Partner", "Uma Companhia de Aventuras para Flora", "Become Flora’s favorite company for an adventure in New Friendships.", "Torne-se uma companhia especial para as aventuras de Flora em Novas Amizades.", "affinity_quiet_08", 1, "friendship-heart"],
	["affinity_quiet_09", "Yasmin Feels at Home", "Yasmin se Sente em Casa", "Make Yasmin feel welcome and heard in New Friendships.", "Faça Yasmin se sentir acolhida e ouvida em Novas Amizades.", "affinity_quiet_09", 1, "friendship-heart"],
	["affinity_quiet_10", "Aiko Shares a Memory", "Uma Lembrança com Aiko", "Show genuine interest in Aiko’s story in New Friendships.", "Demonstre interesse pela história de Aiko em Novas Amizades.", "affinity_quiet_10", 1, "friendship-heart"],
	["affinity_quiet_11", "Dawn Found a Kindred Spirit", "Uma Afinidade com Aurora", "Touch Dawn’s heart with your kindness in New Friendships.", "Toque o coração de Aurora com sua gentileza em Novas Amizades.", "affinity_quiet_11", 1, "friendship-heart"],
	["affinity_quiet_12", "Rosa Opens Her Heart", "Rosa Abriu o Coração", "Help Rosa feel comfortable sharing her thoughts in New Friendships.", "Ajude Rosa a se sentir à vontade para compartilhar seus pensamentos em Novas Amizades.", "affinity_quiet_12", 1, "friendship-heart"],
	["efficient_solution", "Every Move Counts", "Cada Troca Conta", "Complete a puzzle using the minimum possible number of moves.", "Conclua um puzzle usando o mínimo de movimentos possível.", "efficient_solution", 1, "replay"],
	["about_game", "Behind the Fragments", "Por Trás dos Fragmentos", "Open the About the game page.", "Abra a página Sobre o jogo.", "about_game", 1, "dawn"],
	["sixty_nine", "Nice!", "Boa!", "Complete 69 different artworks. Before Six Seven, we already had a classic.", "Conclua 69 artes diferentes. Antes de Six Seven, já tínhamos um clássico.", "unique", 69, "gallery"],
	["seventy_seven", "Lucky Fragments", "Fragmentos da Sorte", "Complete 77 different artworks.", "Conclua 77 artes diferentes.", "unique", 77, "puzzle"],
	["ten_replays", "Back to Wonder", "De Volta ao Encanto", "Complete 10 replays of previously solved artworks.", "Complete 10 repetições de artes já concluídas.", "replays", 10, "replay"],
	["six_seven", "Six Seven!", "Six Seven!", "Complete 67 different artworks. 20 + 20 + 20 + 7… you know the rest.", "Conclua 67 artes diferentes. 20 + 20 + 20 + 7… você sabe o resto.", "unique", 67, "six-seven"],
	["sixty_keys", "Keys to Splendor", "Chaves do Esplendor", "Collect 60 keys in total, including keys already spent.", "Colete 60 chaves no total, incluindo as que já foram gastas.", "collected_keys", 60, "key"],
	["view_twenty", "Gallery Journey", "Jornada pela Galeria", "View 20 different artworks in the gallery.", "Visualize 20 artes diferentes na galeria.", "viewed", 20, "zoom"],
	["fifty_keys", "Golden Reserve", "Reserva Dourada", "Collect 40 keys in total, including keys already spent.", "Colete 40 chaves no total, incluindo as que já foram gastas.", "collected_keys", 40, "key"],
	["quiet_five", "Little Moments", "Pequenos Momentos", "Complete 5 different artworks in Quiet Moments.", "Conclua 5 artes diferentes de Momentos Tranquilos.", "quiet_five", 5, "quiet_five"],
	["fantasy_five", "Fantasy Passport", "Passaporte de Fantasia", "Complete 5 different artworks in High Fantasy.", "Conclua 5 artes diferentes de Alta Fantasia.", "fantasy_five", 5, "fantasy_five"],
	["sweet_five", "Favorite Flavors", "Sabores Favoritos", "Complete 5 different artworks in Sweet Encounters.", "Conclua 5 artes diferentes de Doces Encontros.", "sweet_five", 5, "sweet_five"],
	["velvet_five", "Under the Moonlight", "Sob o Luar", "Complete 5 different artworks in Velvet Evenings.", "Conclua 5 artes diferentes de Noites de Veludo.", "velvet_five", 5, "velvet_five"],
	["three_silver", "Silver at Home", "Prata da Casa", "Earn silver or higher in 3 different collections.", "Ganhe medalha de prata ou superior em 3 coleções diferentes.", "silver", 3, "medal-silver"],
	["all_puzzles", "Every Fragment", "Todos os Fragmentos", "Complete every puzzle currently available in the game.", "Conclua todos os puzzles disponíveis no jogo.", "catalog_solved", 0, "trophy"],
	["dusk_dawn", "Dawn After Dark", "Aurora ao Anoitecer", "Complete Dawn After Dusk. May the moonlight cradle your dreams.", "Conclua Aurora Após o Anoitecer. Que o luar embale seus sonhos.", "dusk_dawn", 1, "dusk_dawn"],
	["sweet_dawn", "Just One More Bite!", "Só Mais Uma Mordida!", "Complete Dawn of Delights. Traveling between worlds works up an appetite.", "Conclua Aurora de Delícias. Viajar entre mundos abre o apetite.", "sweet_dawn", 1, "sweet_dawn"],
	["crystal_haunting", "A Familiar Haunting", "Um Assombro Familiar", "Complete Crystal Haunting. Even Halloween has a little Dawn.", "Conclua Assombro de Cristal. Até o Halloween tem um pouco de Aurora.", "crystal_haunting", 1, "crystal_haunting"],
	["dimensional_dawn", "Dawn Beyond Worlds", "Aurora Além dos Mundos", "Complete Dawn Between Worlds. A new world, a familiar smile.", "Conclua Aurora Entre Mundos. Um mundo novo, um sorriso familiar.", "dimensional_dawn", 1, "dimensional_dawn"],
	["quiet_complete", "First Steps", "Primeiros Passos", "Start a new puzzle after completing every artwork in Quiet Moments.", "Inicie um novo puzzle após concluir todas as artes de Momentos Tranquilos.", "quiet_next", 1, "puzzle"],
	["sporting_five", "Sporting Spirit", "Espírito Esportivo", "Complete 5 different puzzles in Sporting Moments.", "Conclua 5 puzzles diferentes de Momentos Esportivos.", "sporting_five", 5, "sporting_five"],
	["halloween_five", "Trick or Treat", "Gostosuras ou Travessuras", "Complete 5 different puzzles in Halloween Reverie.", "Conclua 5 puzzles diferentes de Devaneios de Halloween.", "halloween_five", 5, "halloween_five"],
	["golden_five", "Sea of Discoveries", "Mar de Descobertas", "Complete 5 different puzzles in Golden Tides.", "Conclua 5 puzzles diferentes de Marés Douradas.", "golden_five", 5, "golden_five"],
	["square", "Perfect Square", "Quadrado Perfeito", "Complete a square puzzle.", "Conclua um puzzle quadrado.", "square", 1, "gallery"],
	["five_keys", "Keys to Discovery", "Chaves da Descoberta", "Collect 5 keys in total, including keys already spent.", "Colete 5 chaves no total, incluindo as que já foram gastas.", "collected_keys", 5, "key"],
	["twenty_keys", "Keys to Wonder", "Chaves do Encanto", "Collect 20 keys in total, including keys already spent.", "Colete 20 chaves no total, incluindo as que já foram gastas.", "collected_keys", 20, "key"],
	["archery_dawn", "Watch That Arrow!", "Cuidado com a Flecha!", "Complete Crystal Archery. Dawn has her sights on a new hobby!", "Resolva Arco de Cristal. Aurora está mirando em um novo hobby!", "archery_dawn", 1, "archery_dawn"],
	["found_dawn", "Found Dawn!", "Encontrou Aurora!", "Complete Garden of Dawn. A familiar smile among the flowers.", "Conclua Jardim da Aurora. Um sorriso familiar entre as flores.", "found_dawn", 1, "dawn"],
	["beach_dawn", "Beachside Dawn", "Aurora à Beira-Mar", "Complete Dawn by the Sea. She came for the sun and stayed for the waves.", "Conclua Aurora à Beira-Mar. Veio pelo sol e ficou pelas ondas.", "beach_dawn", 1, "sea_dawn"],
	["first", "First Fragment", "Primeiro Fragmento", "Complete your first puzzle.", "Resolva o primeiro puzzle.", "unique", 1, "puzzle"],
	["ten", "Small Collection", "Pequena Coleção", "Complete 15 different artworks.", "Conclua 15 artes diferentes.", "unique", 15, "puzzle"],
	["twenty_five", "Collector's Eye", "Olhar de Colecionador", "Complete 25 different artworks.", "Resolva 25 artes diferentes.", "unique", 25, "gallery"],
	["fifty", "Grand Collection", "Grande Acervo", "Complete 50 different artworks.", "Resolva 50 artes diferentes.", "unique", 50, "gallery"],
	["bronze", "First Bronze", "Primeiro Bronze", "Earn a bronze medal or higher.", "Obtenha uma medalha de bronze ou superior.", "bronze", 1, "medal-bronze"],
	["silver", "Silver Shine", "Brilho de Prata", "Earn a silver medal or higher.", "Obtenha uma medalha de prata ou superior.", "silver", 1, "medal-silver"],
	["gold", "Golden Touch", "Toque de Ouro", "Earn your first gold medal.", "Obtenha sua primeira medalha de ouro.", "gold", 1, "medal-gold"],
	["three_gold", "Golden Treasures", "Tesouros Dourados", "Earn gold in 3 different collections.", "Obtenha ouro em 3 coleções diferentes.", "gold", 3, "trophy"],
	["worlds", "Different Worlds", "Mundos Diferentes", "Complete an artwork from each collection in the game.", "Conclua uma arte de cada coleção do jogo.", "worlds", 0, "worlds"],
	["landscape", "New Horizons", "Novos Horizontes", "Complete a landscape puzzle.", "Resolva um puzzle horizontal.", "landscape", 1, "gallery"],
	["portrait", "Complete Portrait", "Retrato Completo", "Complete a portrait puzzle.", "Resolva um puzzle vertical.", "portrait", 1, "gallery"],
	["visit", "First Visit", "Primeira Visita", "Open the gallery.", "Abra a galeria.", "visit", 1, "zoom"],
	["zoom", "Closer Look", "Olhar Atento", "Zoom in on an artwork in the gallery.", "Amplie uma arte na galeria.", "zoom", 1, "zoom"],
	["immersive", "Only Art", "Só a Arte", "Activate immersive gallery mode.", "Ative o modo imersivo da galeria.", "immersive", 1, "zoom"],
	["view_ten", "Gallery Stroll", "Passeio pela Galeria", "View 10 different artworks in the gallery.", "Visualize 10 artes diferentes na galeria.", "viewed", 10, "zoom"],
	["replay", "Another Chance", "Uma Nova Chance", "Complete an artwork again.", "Resolva novamente uma arte já concluída.", "replays", 1, "replay"],
	["plays_ten", "Fresh Starts", "Sempre um Recomeço", "Finish 60 puzzles, including replays.", "Complete 60 partidas, contando repetições.", "plays", 60, "replay"],
	["plays_fifty", "Steady Dedication", "Dedicação Constante", "Finish 55 puzzles, including replays.", "Complete 55 partidas, contando repetições.", "plays", 55, "trophy"],
	["spend", "New Discovery", "Nova Descoberta", "Unlock a puzzle using a key.", "Desbloqueie um puzzle usando uma chave.", "spent", 1, "key"],
	["bonus", "Well Earned", "Chave Merecida", "Earn a key by completing a collection.", "Receba uma chave por concluir uma coleção.", "bonus", 1, "key"],
	["music", "Your Soundtrack", "Sua Trilha", "Choose another track in Options.", "Escolha outra música em Opções.", "music", 1, "music"],
]
var progress
var catalog
var dimensions: Dictionary = {}

func setup(saved_progress, artwork_catalog) -> void:
	progress = saved_progress
	catalog = artwork_catalog
	if not progress.data.get("achievements") is Dictionary:
		progress.data.achievements = {"unlocked": [], "pending": [], "events": {}, "viewed": [], "medals": {}}
	progress.data.achievements.erase("worlds")
	for entry in catalog.entries:
		var texture: Texture2D = load(entry.path)
		dimensions[entry.id] = texture.get_size()
	# Old saves cannot reconstruct repeats; count only known completed artworks.
	progress.data["total_plays"] = maxi(int(progress.data.get("total_plays", 0)), progress.data.solved.size())
	evaluate()

func state() -> Dictionary:
	return progress.data.achievements

func event(kind: String, artwork_id := "") -> void:
	if kind == "start_puzzle":
		if artwork_id not in progress.data.unlocked or artwork_id in progress.data.solved: return
		if int(metrics().get("quiet_complete", 0)) != 1: return
		kind = "quiet_next"
	if kind == "viewed":
		if artwork_id in state().viewed: return
		state().viewed.append(artwork_id)
	else:
		if state().events.get(kind, 0) == 1: return
		state().events[kind] = 1
	evaluate()

func metrics() -> Dictionary:
	var result: Dictionary = state().events.duplicate()
	result.unique = progress.data.solved.size()
	for encounter_id in progress.data.get("friendships", {}):
		var record: Dictionary = progress.data.friendships[encounter_id]
		result["affinity_" + str(encounter_id)] = int(int(record.get("best_quality", record.get("reward_total", 0))) >= 2)
	result.found_dawn = int("res://content/images/01_Quiet_Moments/11_Garden_of_Dawn.webp" in progress.data.solved)
	result.beach_dawn = int("res://content/images/02_Golden_Tides/01_Dawn by the Sea.webp" in progress.data.solved)
	result.archery_dawn = 0
	result.crystal_haunting = 0
	result.dimensional_dawn = 0
	result.sweet_dawn = 0
	result.dusk_dawn = 0
	for entry in catalog.entries:
		if entry.id in progress.data.solved:
			if entry.path.get_file() == "08_Dawn_After_Dusk.webp": result.dusk_dawn = 1
			if entry.path.get_file() == "07_Dawn_of_Delights.webp": result.sweet_dawn = 1
			if entry.path.get_file() == "04_Crystal_Haunting.webp": result.crystal_haunting = 1
			if entry.path.get_file() == "03_Dawn_Between_Worlds.webp": result.dimensional_dawn = 1
		if entry.path.get_file() == "03_Crystal_Archery.webp" and entry.id in progress.data.solved:
			result.archery_dawn = 1
	result.plays = int(progress.data.get("total_plays", 0))
	result.replays = int(progress.data.get("total_replays", 0))
	result.spent = int(progress.data.get("keys_spent", 0))
	result.collected_keys = progress.collected_keys()
	result.bonus = progress.data.get("rewarded_collections", []).size()
	result.viewed = state().viewed.size()
	result.worlds = 0
	result.catalog_solved = catalog.entries.filter(func(e): return e.id in progress.data.solved).size()
	for name in catalog.collections():
		var entries: Array = catalog.entries.filter(func(e): return e.collection == name)
		var done := entries.filter(func(e): return e.id in progress.data.solved).size()
		match name:
			"High Fantasy": result.fantasy_five = done
			"Sweet Encounters": result.sweet_five = done
			"Velvet Evenings": result.velvet_five = done
			"Quiet Moments":
				result.quiet_five = done
				result.quiet_complete = int(done == entries.size() and not entries.is_empty())
			"Sporting Moments": result.sporting_five = done
			"Halloween Reverie": result.halloween_five = done
			"Golden Tides": result.golden_five = done
		var tier := 3 if done == entries.size() else (2 if done * 100 >= entries.size() * 70 else (1 if done * 100 >= entries.size() * 50 else 0))
		state().medals[name] = maxi(int(state().medals.get(name, 0)), tier)
		if done > 0: result.worlds += 1
	for tier in ["bronze", "silver", "gold"]: result[tier] = 0
	for highest in state().medals.values():
		if highest >= 1: result.bronze += 1
		if highest >= 2: result.silver += 1
		if highest >= 3: result.gold += 1
	for id in progress.data.solved:
		var size: Vector2 = dimensions.get(id, Vector2.ZERO)
		if size.x > size.y: result.landscape = 1
		if size.y > size.x: result.portrait = 1
		if size.x == size.y and size.x > 0: result.square = 1
	return result

func target(definition: Array) -> int:
	if definition[0] == "worlds": return maxi(1, catalog.collections().size())
	if definition[0] == "all_puzzles": return maxi(1, catalog.entries.size())
	return int(definition[6])

func awards_key(id: String) -> bool:
	return id in DAWN_KEY_ACHIEVEMENTS or id in EXPLORATION_KEY_ACHIEVEMENTS or id in MEDAL_KEY_ACHIEVEMENTS or id in REPLAY_KEY_ACHIEVEMENTS

func evaluate() -> void:
	var values := metrics()
	for definition in DEFINITIONS:
		if definition[0] not in state().unlocked and int(values.get(definition[5], 0)) >= target(definition):
			state().unlocked.append(definition[0])
			state().pending.append(definition[0])
			if awards_key(definition[0]):
				if progress.grant_key(): key_earned.emit()
	progress.save()

func definition_for(id: String) -> Array:
	for definition in DEFINITIONS:
		if definition[0] == id: return definition
	return []

func title(definition: Array, language: String) -> String:
	if language == "es": return preload("res://scripts/locale.gd").text(definition[1], language)
	return definition[2] if language == "pt" else definition[1]

func alphabetical_title(definition: Array, language: String) -> String:
	var value := title(definition, language).to_lower()
	var accents := {"á": "a", "à": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i", "ó": "o", "ô": "o", "õ": "o", "ú": "u", "ü": "u", "ç": "c"}
	for accent in accents:
		value = value.replace(accent, accents[accent])
	if language == "es": value = value.replace("ñ", "n~")
	return value

func sorted_definitions(language: String) -> Array:
	var definitions := DEFINITIONS.duplicate()
	definitions.sort_custom(func(a: Array, b: Array):
		var a_unlocked: bool = a[0] in state().unlocked
		var b_unlocked: bool = b[0] in state().unlocked
		if a_unlocked != b_unlocked: return not a_unlocked
		return alphabetical_title(a, language).naturalnocasecmp_to(alphabetical_title(b, language)) < 0
	)
	return definitions

func description(definition: Array, language: String) -> String:
	if language == "es": return preload("res://scripts/locale.gd").text(definition[3], language)
	return definition[4] if language == "pt" else definition[3]

func icon(definition: Array) -> Texture2D:
	if str(definition[0]).begins_with("affinity_"):
		var encounter_id := str(definition[0]).trim_prefix("affinity_")
		var encounters: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/friendships.json"))
		for encounter in encounters:
			if encounter.id != encounter_id: continue
			var portrait := AtlasTexture.new()
			portrait.atlas = load(encounter.art)
			var source := Vector2(portrait.atlas.get_size())
			var side := minf(source.x, source.y) * 0.32
			var focus: Array = encounter.get("focus", [0.5, 0.22])
			var region_size := Vector2(side, side)
			var origin := source * Vector2(focus[0], focus[1]) - region_size * 0.5
			portrait.region = Rect2(origin.clamp(Vector2.ZERO, source - region_size), region_size)
			return portrait
	if definition[0] in ["spend", "sixty_keys"]:
		var key_portrait := AtlasTexture.new()
		key_portrait.atlas = load("res://art/keys/key-discovery.webp")
		key_portrait.region = Rect2(585, 250, 440, 440)
		return key_portrait
	var format_portraits := {
		"about_game": ["res://art/dawn-ui/hero.webp", Rect2(410, 160, 470, 470)],
		"sixty_nine": ["res://content/images/06_Halloween_Reverie/11_Emerald_Oracle.webp", Rect2(300, 90, 350, 350)],
		"fifty": ["res://content/images/05_Sporting_Moments/04_Sunset_Serve.webp", Rect2(650, 0, 450, 450)],
		"twenty_five": ["res://content/images/03_High_Fantasy/01_Golden_Paladin.webp", Rect2(440, 65, 350, 350)],
		"landscape": ["res://content/images/01_Quiet_Moments/03_Seaside_Watercolors.webp", Rect2(220, 90, 350, 350)],
		"square": ["res://content/images/01_Quiet_Moments/01_Lavender_Garden.webp", Rect2(435, 65, 390, 390)],
		"portrait": ["res://content/images/01_Quiet_Moments/04_Emerald_Stillness.webp", Rect2(330, 65, 365, 365)]
	}
	if format_portraits.has(definition[0]):
		var portrait := AtlasTexture.new()
		portrait.atlas = load(format_portraits[definition[0]][0])
		portrait.region = format_portraits[definition[0]][1]
		return portrait
	var kind: String = definition[7]
	var collection_portraits := {
		"quiet_five": ["res://content/images/01_Quiet_Moments/05_Ember in Bloom.webp", Rect2(350, 25, 340, 340)],
		"golden_five": ["res://content/images/02_Golden_Tides/05_Ember Coast.webp", Rect2(330, 30, 340, 340)],
		"sporting_five": ["res://content/images/05_Sporting_Moments/05_Velvet_Fencing.webp", Rect2(350, 75, 350, 350)],
		"halloween_five": ["res://content/images/06_Halloween_Reverie/05_Honeyed_Hex.webp", Rect2(340, 85, 350, 350)],
		"fantasy_five": ["res://content/images/03_High_Fantasy/05_Happy_Wizard.webp", Rect2(270, 65, 310, 310)],
		"sweet_five": ["res://content/images/04_Sweet_Encounters/04_Matcha_Muse.webp", Rect2(220, 100, 650, 650)],
		"velvet_five": ["res://content/images/07_Velvet_Evenings/05_Sakura_by_Moonlight.webp", Rect2(310, 60, 430, 430)]
	}
	if collection_portraits.has(kind):
		var portrait := AtlasTexture.new()
		portrait.atlas = load(collection_portraits[kind][0])
		portrait.region = collection_portraits[kind][1]
		return portrait
	if kind == "dusk_dawn":
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://content/images/07_Velvet_Evenings/08_Dawn_After_Dusk.webp")
		portrait.region = Rect2(90, 160, 650, 650)
		return portrait
	if kind == "sweet_dawn":
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://content/images/04_Sweet_Encounters/07_Dawn_of_Delights.webp")
		portrait.region = Rect2(200, 70, 640, 640)
		return portrait
	if kind == "crystal_haunting":
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://content/images/06_Halloween_Reverie/04_Crystal_Haunting.webp")
		portrait.region = Rect2(360, 20, 640, 640)
		return portrait
	if kind == "dimensional_dawn":
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://content/images/03_High_Fantasy/03_Dawn_Between_Worlds.webp")
		portrait.region = Rect2(480, 20, 560, 560)
		return portrait
	if kind == "dawn":
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://content/images/01_Quiet_Moments/11_Garden_of_Dawn.webp")
		portrait.region = Rect2(420, 20, 390, 390)
		return portrait
	if kind == "sea_dawn":
		return load("res://content/images/02_Golden_Tides/09_Dawn by the Sea.webp")
	if kind.begins_with("medal-"): return load("res://art/dawn-ui/" + kind + ".webp")
	if kind == "key": return load("res://art/dawn-ui/wallet-key.tres")
	if kind in ["puzzle", "worlds", "immersive"]: return load("res://art/achievements/fragments.webp")
	if kind == "archery_dawn":
		var portrait := AtlasTexture.new()
		portrait.atlas = load("res://content/images/05_Sporting_Moments/03_Crystal_Archery.webp")
		portrait.region = Rect2(320, 0, 660, 660)
		return portrait
	if kind in ["gallery", "trophy", "replay", "zoom", "six-seven"]: return load("res://art/achievements/" + kind + ".webp")
	return load("res://art/achievements/" + kind + ".svg")
