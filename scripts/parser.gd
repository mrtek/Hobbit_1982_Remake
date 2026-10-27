class_name Parser
extends RefCounted

var dictionary: Dictionary = {}

func _init() -> void:
	load_dictionary()

func load_dictionary() -> void:
	var file = FileAccess.open("res://data/dictionary.json", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		dictionary = JSON.parse_string(text)
	else:
		push_error("Failed to load dictionary.json")
		dictionary = {}

func parse(raw_input: String) -> Dictionary:
	var clean = raw_input.strip_edges()
	var result = {
		"verb": "",
		"direction": "",
		"object": "",
		"indirect_object": "",
		"preposition": "",
		"target_npc": "",
		"raw_text": clean
	}
	
	if clean.is_empty():
		return result
		
	var lower = clean.to_lower()
	
	# 1. Проверка на обращение к NPC:
	# Формат: "Торин, открой дверь" или 'Скажи Торину "открой дверь"'
	for comp_id in dictionary.get("companions", {}).keys():
		var comp_aliases: Array = dictionary["companions"][comp_id]
		for alias in comp_aliases:
			var prefix1 = alias + ","
			var prefix2 = alias + ":"
			if lower.begins_with(prefix1) or lower.begins_with(prefix2):
				result["target_npc"] = comp_id
				var sub_cmd = lower.substr(prefix1.length()).strip_edges()
				var sub_res = parse(sub_cmd)
				sub_res["target_npc"] = comp_id
				sub_res["raw_text"] = clean
				return sub_res
				
			if lower.begins_with("скажи " + alias) or lower.begins_with("прикажи " + alias):
				result["target_npc"] = comp_id
				var rest = lower.substr(len("скажи " + alias)).strip_edges()
				rest = rest.trim_prefix('"').trim_suffix('"').trim_prefix('«').trim_suffix('»').strip_edges()
				var sub_res = parse(rest)
				sub_res["target_npc"] = comp_id
				sub_res["raw_text"] = clean
				return sub_res

			if lower.begins_with("tell " + alias) or lower.begins_with("say to " + alias) or lower.begins_with("ask " + alias) or lower.begins_with("order " + alias):
				result["target_npc"] = comp_id
				var pfx_len = 0
				for pfx in ["tell " + alias, "say to " + alias, "ask " + alias, "order " + alias]:
					if lower.begins_with(pfx):
						pfx_len = len(pfx)
						break
				var rest = lower.substr(pfx_len).strip_edges()
				if rest.begins_with("to "):
					rest = rest.substr(3).strip_edges()
				rest = rest.trim_prefix('"').trim_suffix('"').trim_prefix('«').trim_suffix('»').strip_edges()
				var sub_res = parse(rest)
				sub_res["target_npc"] = comp_id
				sub_res["raw_text"] = clean
				return sub_res

	# 2. Конструкции осмотра контейнеров и содержимого (сундук, шкаф, бочка, тайник)
	var container_prefixes = [
		"что лежит внутри ",
		"что находится в ",
		"что лежит в ",
		"что внутри ",
		"что в ",
		"вещи внутри ",
		"вещи в ",
		"предметы внутри ",
		"предметы в ",
		"содержимое ",
		"заглянуть внутрь ",
		"заглянуть в ",
		"загляни внутрь ",
		"загляни в ",
		"посмотреть внутрь ",
		"посмотреть в ",
		"посмотри внутрь ",
		"посмотри в ",
		"осмотреть вещи в ",
		"осмотреть внутри ",
		"осмотреть в ",
		"внутри ",
		"what is inside ",
		"what is in ",
		"look inside ",
		"look in ",
		"check inside ",
		"search inside ",
		"search ",
		"inside "
	]
	for prefix in container_prefixes:
		if lower.begins_with(prefix):
			var cont_name = lower.substr(prefix.length()).strip_edges()
			result["verb"] = "examine"
			result["object"] = _clean_article(cont_name)
			result["preposition"] = "in"
			return result

	if lower.begins_with("в ") and not lower in ["в", "восток"]:
		var rest_w = lower.substr(2).strip_edges()
		if not rest_w in dictionary.get("directions", {}).keys():
			result["verb"] = "examine"
			result["object"] = rest_w
			result["preposition"] = "в"
			return result

	# 3. Однобуквенные или быстрые направления
	for dir_key in dictionary.get("directions", {}).keys():
		var dir_aliases: Array = dictionary["directions"][dir_key]
		if lower in dir_aliases:
			result["verb"] = "go"
			result["direction"] = dir_key
			return result
			
	# 4. Быстрые одиночные команды (только если введено ровно одно слово)
	for v_key in ["look", "inventory", "wait", "help", "save", "load"]:
		if lower in dictionary.get("verbs", {}).get(v_key, []):
			result["verb"] = v_key
			return result

	# Разделяем на слова, убирая знаки препинания
	var clean_tokens_str = ""
	for c in lower:
		if c in ".,!?;:\'\"«»":
			clean_tokens_str += " "
		else:
			clean_tokens_str += c
			
	var words = clean_tokens_str.split(" ", false)
	if words.size() == 0:
		return result
		
	# 5. Поиск глагола
	var verb_idx = -1
	for i in range(words.size()):
		var w = words[i]
		for v_key in dictionary.get("verbs", {}).keys():
			if w in dictionary["verbs"][v_key]:
				result["verb"] = v_key
				verb_idx = i
				break
		if result["verb"] != "":
			break
			
	# Если глагол не найден, проверяем, не направление ли это
	if result["verb"] == "":
		for i in range(words.size()):
			var w = words[i]
			for dir_key in dictionary.get("directions", {}).keys():
				if w in dictionary["directions"][dir_key]:
					result["verb"] = "go"
					result["direction"] = dir_key
					return result

	# Если глагол движения, ищем направление среди остальных слов
	if result["verb"] == "go":
		for i in range(words.size()):
			if i == verb_idx:
				continue
			var w = words[i]
			for dir_key in dictionary.get("directions", {}).keys():
				if w in dictionary["directions"][dir_key]:
					result["direction"] = dir_key
					return result
		return result
		
	# 6. Разбор объектов и предлогов (Verb + Object + [Prep] + [Indirect Object])
	var non_verb_words = []
	for i in range(words.size()):
		if i == verb_idx:
			continue
		non_verb_words.append(words[i])
		
	if non_verb_words.size() == 0:
		return result
		
	# Ищем предлог в оставшихся словах
	var prep_idx = -1
	var preps: Array = dictionary.get("prepositions", [])
	for i in range(non_verb_words.size()):
		if non_verb_words[i] in preps:
			prep_idx = i
			result["preposition"] = non_verb_words[i]
			break
			
	if prep_idx != -1:
		var before_prep = non_verb_words.slice(0, prep_idx)
		var after_prep = non_verb_words.slice(prep_idx + 1)
		
		# Если до предлога пусто (например "загляни в сундук"), то объект после предлога
		if before_prep.size() == 0:
			result["object"] = _clean_article(" ".join(after_prep))
		else:
			result["object"] = _clean_article(" ".join(before_prep))
			result["indirect_object"] = _clean_article(" ".join(after_prep))
	else:
		# Без явного предлога
		var last_w = non_verb_words[-1]
		if (last_w.ends_with("ом") or last_w.ends_with("ем")) and non_verb_words.size() > 1:
			result["object"] = _clean_article(" ".join(non_verb_words.slice(0, non_verb_words.size() - 1)))
			result["indirect_object"] = last_w
		else:
			result["object"] = _clean_article(" ".join(non_verb_words))
			
	return result

func _clean_article(text: String) -> String:
	var t = text.strip_edges()
	for art in ["the ", "a ", "an "]:
		if t.begins_with(art):
			return t.substr(len(art)).strip_edges()
	return t

