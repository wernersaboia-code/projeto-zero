extends RefCounted

const _HexUtils = preload("res://scripts/map/HexUtils.gd")
const _ProvinceData = preload("res://scripts/map/ProvinceData.gd")
const _NationData = preload("res://scripts/map/NationData.gd")
const _SR2030Loader = preload("res://scripts/map/SR2030Loader.gd")


static func generate(provinces: Dictionary, grid: Dictionary, _target_nations: int = 35) -> Dictionary:
	var nations: Dictionary = {}
	_SR2030Loader.get_geo_match()

	# Step 1: classify every land cell by country
	var cell_country: Dictionary = {}  # cube_key -> country_id

	for cube in grid:
		var cell = grid[cube]
		if cell.is_water():
			continue
		var offset = cell.offset_coords
		var cid = _SR2030Loader.find_country_for_cell(offset.x, offset.y)
		if cid >= 0:
			cell_country[cube] = cid

	var matched_cells = cell_country.size()
	var total_land = 0
	for cube in grid:
		if not grid[cube].is_water():
			total_land += 1

	print("Cell geolocation: ", matched_cells, "/", total_land, " cells matched")

	if matched_cells == 0:
		return {}

	var country_cells: Dictionary = {}
	for cube in cell_country:
		var cid = cell_country[cube]
		if not country_cells.has(cid):
			country_cells[cid] = []
		country_cells[cid].append(cube)
	print("Nations: ", country_cells.size())

	# Step 3: for each province, find plurality country
	var province_country: Dictionary = {}  # province_id -> country_id
	for pid in provinces:
		var prov = provinces[pid]
		if prov.is_water():
			continue
		var votes: Dictionary = {}
		for cube in prov.hexes:
			if cell_country.has(cube):
				var cid = cell_country[cube]
				votes[cid] = votes.get(cid, 0) + 1
		if votes.is_empty():
			continue
		var best_cid = -1
		var best_count = 0
		for cid in votes:
			if votes[cid] > best_count:
				best_count = votes[cid]
				best_cid = cid
		if best_cid >= 0:
			province_country[pid] = best_cid

	# Step 4: create nations (one per unique country with matched cells)
	var cid_to_nid: Dictionary = {}  # country_id -> nation_id (0-based)
	var nid_counter = 0

	for cid in country_cells:
		cid_to_nid[cid] = nid_counter
		nid_counter += 1

	# Step 5: assign provinces to nations
	var assigned: Dictionary = {}  # province_id -> nation_id
	for pid in province_country:
		var cid = province_country[pid]
		var nid = cid_to_nid[cid]
		assigned[pid] = nid

	# Flood-fill unmatched provinces
	var frontier: Array = []
	for pid in assigned:
		frontier.append({"province": pid, "nation": assigned[pid]})

	var frontier_idx = 0
	while frontier_idx < frontier.size():
		var entry = frontier[frontier_idx]
		frontier_idx += 1
		var current_pid = entry.province
		var current_nation = entry.nation

		for c in provinces[current_pid].hexes:
			for d in range(6):
				var neighbor = _HexUtils.cube_neighbor(c, d)
				if not grid.has(neighbor):
					continue
				var neighbor_pid = grid[neighbor].province_id
				if neighbor_pid == -1 or neighbor_pid == current_pid:
					continue
				if not provinces.has(neighbor_pid):
					continue
				if provinces[neighbor_pid].is_water():
					continue
				if assigned.has(neighbor_pid):
					continue
				assigned[neighbor_pid] = current_nation
				frontier.append({"province": neighbor_pid, "nation": current_nation})

	# Step 5: create nation for every matched country
	for cid in cid_to_nid:
		var nid = cid_to_nid[cid]
		var nation = _NationData.new()
		nation.id = nid
		var cdata = _SR2030Loader.get_country_by_id(cid)
		if not cdata.is_empty():
			nation.name = cdata.name
			nation.color = _hex_to_color(cdata.color)
		else:
			nation.name = "Nation %d" % nid
			nation.color = Color.from_hsv(float(nid) / 30.0 * 0.85, 0.6, 0.7)
		if nid == 0:
			nation.is_player = true
		nations[nid] = nation

	# Step 6: assign provinces to nations (they may cross borders; primary = flood-filled)
	for pid in assigned:
		var nid = assigned[pid]
		nations[nid].province_ids.append(pid)
		provinces[pid].nation_id = nid
		nations[nid].population += provinces[pid].population

	# Step 7: assign individual cells to nations (overrides province assignment)
	for cube in cell_country:
		if grid.has(cube):
			var cell = grid[cube]
			cell.owner_nation_id = cid_to_nid[cell_country[cube]]

	for nid in nations:
		var nation = nations[nid]
		if not nation.province_ids.is_empty():
			nation.capital_province_id = nation.province_ids[0]
			provinces[nation.capital_province_id].is_coastal = true

	return nations


static func _hex_to_color(hex_str: String) -> Color:
	if hex_str.length() != 8:
		return Color.WHITE
	var a = float("0x" + hex_str.substr(0, 2)) / 255.0
	var r = float("0x" + hex_str.substr(2, 2)) / 255.0
	var g = float("0x" + hex_str.substr(4, 2)) / 255.0
	var b = float("0x" + hex_str.substr(6, 2)) / 255.0
	return Color(r, g, b, a)