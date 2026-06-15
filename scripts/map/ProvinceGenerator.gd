extends RefCounted

const _HexUtils = preload("res://scripts/map/HexUtils.gd")
const _ProvinceData = preload("res://scripts/map/ProvinceData.gd")

static func generate(grid: Dictionary, grid_width: int, grid_height: int) -> Dictionary:
	var provinces: Dictionary = {}
	var next_id: int = 0
	var assigned: Dictionary = {}

	for cube in grid:
		assigned[cube] = false

	var water_regions = _find_contiguous_water_regions(grid, assigned)
	for region in water_regions:
		var prov = _ProvinceData.new()
		prov.id = next_id
		prov.hexes = region
		prov.terrain_primary = grid[region[0]].terrain
		for c in region:
			grid[c].province_id = prov.id
			assigned[c] = true
		prov.capital_hex = region[region.size() / 2]
		provinces[next_id] = prov
		next_id += 1

	var land_provinces = _generate_land_provinces(grid, grid_width, grid_height, assigned)
	for prov in land_provinces:
		prov.id = next_id
		for c in prov.hexes:
			grid[c].province_id = prov.id
			assigned[c] = true
		prov.capital_hex = prov.hexes[prov.hexes.size() / 2]
		provinces[next_id] = prov
		next_id += 1

	_post_process_coastal(provinces, grid)
	return provinces


static func _find_contiguous_water_regions(grid: Dictionary, assigned: Dictionary) -> Array[Array]:
	var regions: Array[Array] = []

	for cube in grid:
		if assigned[cube]:
			continue
		var cell = grid[cube]
		if not cell.is_water():
			continue

		var region: Array[Vector3] = []
		var stack = [cube]
		assigned[cube] = true

		while stack.size() > 0:
			var current = stack.pop_back()
			region.append(current)
			for d in range(6):
				var neighbor = _HexUtils.cube_neighbor(current, d)
				if grid.has(neighbor) and not assigned[neighbor] and grid[neighbor].is_water():
					assigned[neighbor] = true
					stack.append(neighbor)

		regions.append(region)

	return regions


static func _generate_land_provinces(grid: Dictionary, grid_width: int, grid_height: int, assigned: Dictionary) -> Array:
	var step = 4
	# 320×200 grid → step 4 gives ~4000 seeds → ~1500 provinces after filtering
	var seeds: Array[Vector3] = []

	for col in range(0, grid_width, step):
		for row in range(0, grid_height, step):
			var cube = _HexUtils.offset_to_cube(Vector2i(col, row))
			if grid.has(cube) and not assigned[cube] and grid[cube].terrain != Constants.MOUNTAINS:
				seeds.append(cube)

	if seeds.is_empty():
		return []

	var province_of: Dictionary = {}
	var frontier: Array = []

	for i in range(seeds.size()):
		var seed = seeds[i]
		if assigned[seed]:
			continue
		province_of[seed] = i
		frontier.append({"cube": seed, "province": i, "cost": 0})

	var priority = []
	priority.append_array(frontier)
	var idx = 0

	while idx < priority.size():
		var entry = priority[idx]
		idx += 1
		var current = entry.cube as Vector3
		var current_province = entry.province

		for d in range(6):
			var neighbor = _HexUtils.cube_neighbor(current, d)
			if not grid.has(neighbor) or assigned[neighbor]:
				continue

			var neighbor_cell = grid[neighbor]
			if neighbor_cell.is_water() or neighbor_cell.terrain == Constants.MOUNTAINS:
				continue

			if province_of.has(neighbor):
				continue

			var seed_terrain = grid[seeds[current_province]].terrain
			var terrain_cost = 1.0
			if neighbor_cell.terrain != seed_terrain:
				terrain_cost = 3.0

			var total_cost = entry.cost + terrain_cost

			province_of[neighbor] = current_province
			priority.append({"cube": neighbor, "province": current_province, "cost": total_cost})

	var province_hexes: Dictionary = {}
	for cube in province_of:
		var pid = province_of[cube]
		if not province_hexes.has(pid):
			province_hexes[pid] = []
		province_hexes[pid].append(cube)

	var result: Array = []
	var name_pool = _generate_province_names()

	for pid in province_hexes:
		var prov = _ProvinceData.new()
		prov.hexes = province_hexes[pid]
		prov.terrain_primary = grid[prov.hexes[0]].terrain
		prov.name = name_pool[result.size() % name_pool.size()] if result.size() < name_pool.size() else "Province %d" % pid
		result.append(prov)

	for i in range(result.size()):
		result[i].id = i
		for c in result[i].hexes:
			grid[c].province_id = i

	_merge_small_provinces(result, grid, 2)
	# Keep small provinces for better nation matching
	return result


static func _post_process_coastal(provinces: Dictionary, grid: Dictionary) -> void:
	for pid in provinces:
		var prov = provinces[pid]
		if prov.is_water():
			continue
		for c in prov.hexes:
			for d in range(6):
				var neighbor = _HexUtils.cube_neighbor(c, d)
				if grid.has(neighbor) and grid[neighbor].is_water():
					prov.is_coastal = true
					return


static func _merge_small_provinces(provinces: Array, grid: Dictionary, min_size: int) -> void:
	while true:
		var changed = false
		var active: Array[int] = []
		for i in range(provinces.size()):
			active.append(i)

		var hex_to_idx: Dictionary = {}
		for i in active:
			for c in provinces[i].hexes:
				hex_to_idx[c] = i

		var to_remove: Array[int] = []

		for i in active:
			if provinces[i].hexes.size() >= min_size:
				continue

			var neighbor_counts: Dictionary = {}
			for c in provinces[i].hexes:
				for d in range(6):
					var neighbor = _HexUtils.cube_neighbor(c, d)
					if hex_to_idx.has(neighbor):
						var n_idx = hex_to_idx[neighbor]
						if n_idx != i:
							if not neighbor_counts.has(n_idx):
								neighbor_counts[n_idx] = 0
							neighbor_counts[n_idx] += 1

			if neighbor_counts.is_empty():
				continue

			var best_idx = -1
			var best_count = 0
			for n_idx in neighbor_counts:
				if neighbor_counts[n_idx] > best_count:
					best_count = neighbor_counts[n_idx]
					best_idx = n_idx

			if best_idx != -1:
				for c in provinces[i].hexes:
					grid[c].province_id = provinces[best_idx].id
				provinces[best_idx].hexes.append_array(provinces[i].hexes)
				to_remove.append(i)
				changed = true

		if not changed:
			break

		for i in range(to_remove.size() - 1, -1, -1):
			provinces.remove_at(to_remove[i])


static func _generate_province_names() -> Array[String]:
	var file = FileAccess.open("res://assets/data/province_names.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		file.close()
		if json:
			var names: Array[String] = []
			var prefixes = json.get("prefixes", [])
			var roots = json.get("roots", [])
			var suffixes = json.get("suffixes", [])

			for p in prefixes:
				for r in roots:
					names.append(p + r.capitalize())

			for r in roots:
				for s in suffixes:
					names.append(r.capitalize() + " " + s)

			for r in roots:
				names.append(r.capitalize() + "land")

			if not names.is_empty():
				names.shuffle()
				return names

	return []
