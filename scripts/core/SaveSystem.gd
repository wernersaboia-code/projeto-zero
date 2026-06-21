extends RefCounted

const SAVE_DIR = "user://saves/"


static func save_game(slot: int, game_manager: Node, hex_grid: Node) -> bool:
	var dir = DirAccess.open("user://")
	if not dir:
		return false
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	var data = {
		"version": 1,
		"year": game_manager.game_year,
		"month": game_manager.game_month,
		"day": game_manager.game_day,
		"tick": game_manager.current_tick,
		"player_nation": game_manager.player_nation_id,
		"nations": []
	}

	for nid in hex_grid.nations:
		var nation = hex_grid.nations[nid]
		var ndata = {
			"id": nation.id,
			"treasury": nation.treasury,
			"gdp": nation.gdp,
			"population": nation.population,
			"trade_balance": nation.trade_balance,
			"government": nation.government_type,
			"resources": {},
			"diplomacy": {}
		}
		for rt in nation.resources:
			ndata.resources[str(rt)] = nation.resources[rt]
		for other in nation.diplomacy:
			ndata.diplomacy[str(other)] = nation.diplomacy[other]
		data.nations.append(ndata)

	var path = SAVE_DIR + "save_%d.json" % slot
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var json = JSON.stringify(data, "\t")
	file.store_string(json)
	file.close()
	print("Game saved to ", path)
	return true


static func load_game(slot: int, game_manager: Node, hex_grid: Node) -> bool:
	var path = SAVE_DIR + "save_%d.json" % slot
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text = file.get_as_text()
	file.close()

	var json = JSON.parse_string(text)
	if not json or typeof(json) != TYPE_DICTIONARY:
		return false

	game_manager.game_year = json.get("year", 2025)
	game_manager.game_month = json.get("month", 1)
	game_manager.game_day = json.get("day", 1)
	game_manager.current_tick = json.get("tick", 0)
	game_manager.player_nation_id = json.get("player_nation", -1)

	for ndata in json.get("nations", []):
		var nid = ndata.get("id", -1)
		if not hex_grid.nations.has(nid):
			continue
		var nation = hex_grid.nations[nid]
		nation.treasury = ndata.get("treasury", 10000.0)
		nation.gdp = ndata.get("gdp", 0.0)
		nation.population = ndata.get("population", 0)
		nation.trade_balance = ndata.get("trade_balance", 0.0)
		nation.government_type = ndata.get("government", "democracy")
		for rt_str in ndata.get("resources", {}):
			nation.resources[int(rt_str)] = ndata.resources[rt_str]
		for other_str in ndata.get("diplomacy", {}):
			nation.diplomacy[int(other_str)] = ndata.diplomacy[other_str]

	print("Game loaded from ", path)
	return true


static func get_save_list() -> Array:
	var result = []
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var file = FileAccess.open(SAVE_DIR + fname, FileAccess.READ)
			if file:
				var text = file.get_as_text()
				file.close()
				var json = JSON.parse_string(text)
				if json:
					var slot = int(fname.trim_prefix("save_").trim_suffix(".json"))
					result.append({
						"slot": slot,
						"year": json.get("year", 0),
						"month": json.get("month", 0),
						"day": json.get("day", 0),
						"tick": json.get("tick", 0)
					})
		fname = dir.get_next()
	return result
