extends Node2D
class_name HexGrid

const _HexCell = preload("res://scripts/map/HexCell.gd")
const _HexUtils = preload("res://scripts/map/HexUtils.gd")
const _ProvinceData = preload("res://scripts/map/ProvinceData.gd")
const _ProvinceGenerator = preload("res://scripts/map/ProvinceGenerator.gd")
const _NationData = preload("res://scripts/map/NationData.gd")
const _NationGenerator = preload("res://scripts/map/NationGenerator.gd")
const _RiverGenerator = preload("res://scripts/map/RiverGenerator.gd")
const _ResourceGenerator = preload("res://scripts/economy/ResourceGenerator.gd")
const _ResourceData = preload("res://scripts/economy/ResourceData.gd")
const _EconomySystem = preload("res://scripts/economy/EconomySystem.gd")

signal grid_generated()

var cells: Dictionary = {}
var provinces: Dictionary = {}
var nations: Dictionary = {}

var grid_width: int = 320
var grid_height: int = 200
var hex_size: float = 10.0

var show_political_mode: bool = true

var terrain_colors: Dictionary = {}
var _noise_moisture: FastNoiseLite
var _heightmap: Array = []
var _hovered_cell: Vector3 = Vector3(99999, 99999, 99999)
var _nation_border_cache: Array = []
var _province_border_cache: Array = []
var _river_edge_cache: Array = []
var _heightmap_color: Array = []  # Color per cell (from PNG), empty = use procedural colors


func _ready() -> void:
	add_to_group("hex_grid")
	seed(42)
	_setup_heightmap()
	_setup_moisture_noise()
	_load_terrain_colors()
	_generate_terrain()
	_print_terrain_stats()
	_generate_provinces()
	_generate_nations()
	_generate_rivers()
	_generate_resources()
	_build_border_cache()
	grid_generated.emit()
	EventBus.grid_status.emit(cells.size(), provinces.size(), nations.size())
	EventBus.game_tick.connect(_on_game_tick)


func _setup_heightmap() -> void:
	_heightmap.resize(grid_width * grid_height)

	# Try loading from PNG first (real Earth data)
	var img_path = "res://assets/data/maps/earth_heightmap.png"
	if FileAccess.file_exists(img_path):
		var img = Image.new()
		var err = img.load(img_path)
		if err == OK:
			if img.get_width() != grid_width or img.get_height() != grid_height:
				img.resize(grid_width, grid_height, Image.INTERPOLATE_LANCZOS)

			_heightmap_color.resize(grid_width * grid_height)
			for c in grid_width:
				for r in grid_height:
					_heightmap_color[c + r * grid_width] = img.get_pixel(c, r)

			var land_mask = []
			land_mask.resize(grid_width * grid_height)
			for col in grid_width:
				for row in grid_height:
					var p = img.get_pixel(col, row)
					var total = p.r + p.g + p.b
					var b_ratio = p.b / total if total > 0 else 0
					var g_ratio = p.g / total if total > 0 else 0
					var r_ratio = p.r / total if total > 0 else 0
					var bright = total / 3.0
					var land = false
					if bright > 0.65 and b_ratio < 0.45:
						land = true
					elif r_ratio > 0.40 or g_ratio > 0.40:
						land = true
					elif b_ratio > 0.45:
						land = false
					else:
						land = bright > 0.5
					land_mask[col + row * grid_width] = land

		# Step 2: distance from coast for LAND (inward)
			var dist_land = []
			dist_land.resize(grid_width * grid_height)
			for col in grid_width:
				for row in grid_height:
					var idx = col + row * grid_width
					if not land_mask[idx]:
						dist_land[idx] = -1
						continue
					var coastal = false
					for dc in [-1, 0, 1]:
						for dr in [-1, 0, 1]:
							if dc == 0 and dr == 0: continue
							var nc = col + dc
							var nr = row + dr
							if nc < 0 or nc >= grid_width or nr < 0 or nr >= grid_height: continue
							if not land_mask[nc + nr * grid_width]:
								coastal = true
								break
						if coastal: break
					dist_land[idx] = 1 if coastal else 999

			for _pass in 60:
				for col in grid_width:
					for row in grid_height:
						var idx = col + row * grid_width
						if dist_land[idx] == -1: continue
						var best = dist_land[idx]
						for dc in [-1, 0, 1]:
							for dr in [-1, 0, 1]:
								if dc == 0 and dr == 0: continue
								var nc = col + dc
								var nr = row + dr
								if nc < 0 or nc >= grid_width or nr < 0 or nr >= grid_height: continue
								var nv = dist_land[nc + nr * grid_width]
								if nv >= 0 and nv + 1 < best:
									best = nv + 1
						dist_land[idx] = best

			# Step 3: distance from coast for WATER (outward) → coastal shallows
			var dist_water = []
			dist_water.resize(grid_width * grid_height)
			for col in grid_width:
				for row in grid_height:
					var idx = col + row * grid_width
					if land_mask[idx]:
						dist_water[idx] = -1
						continue
					var coastal = false
					for dc in [-1, 0, 1]:
						for dr in [-1, 0, 1]:
							if dc == 0 and dr == 0: continue
							var nc = col + dc
							var nr = row + dr
							if nc < 0 or nc >= grid_width or nr < 0 or nr >= grid_height: continue
							if land_mask[nc + nr * grid_width]:
								coastal = true
								break
						if coastal: break
					dist_water[idx] = 1 if coastal else 999

			for _pass in 10:
				for col in grid_width:
					for row in grid_height:
						var idx = col + row * grid_width
						if dist_water[idx] == -1: continue
						var best = dist_water[idx]
						for dc in [-1, 0, 1]:
							for dr in [-1, 0, 1]:
								if dc == 0 and dr == 0: continue
								var nc = col + dc
								var nr = row + dr
								if nc < 0 or nc >= grid_width or nr < 0 or nr >= grid_height: continue
								var nv = dist_water[nc + nr * grid_width]
								if nv >= 0 and nv + 1 < best:
									best = nv + 1
						dist_water[idx] = best

			var noise = FastNoiseLite.new()
			noise.seed = 42
			noise.frequency = 0.04
			noise.fractal_octaves = 2
			noise.noise_type = FastNoiseLite.TYPE_PERLIN

			var land_count = 0
			var max_dist = 0
			for col in grid_width:
				for row in grid_height:
					var idx = col + row * grid_width
					if land_mask[idx]:
						var d = dist_land[idx]
						if d > max_dist: max_dist = d
						var base = 0.20 + min(d, 60.0) / 30.0
						var n = noise.get_noise_2d(float(col) * 0.15, float(row) * 0.15) * 0.10
						_heightmap[idx] = clamp(base + n, 0.12, 0.90)
						land_count += 1
					else:
						var d = dist_water[idx]
						if d <= 0 or d >= 999:
							_heightmap[idx] = 0.06
						elif d <= 2:
							_heightmap[idx] = 0.16
						else:
							_heightmap[idx] = 0.06 + (0.06 * min(d, 6)) / 8.0

			print("Loaded Earth heightmap: land=", land_count, " max_dist=", max_dist)
		else:
			push_warning("Failed to load earth_heightmap.png, error: ", err)
			_generate_procedural_heightmap()
	else:
		print("No earth_heightmap.png found, using procedural generation")
		_generate_procedural_heightmap()


func _generate_procedural_heightmap() -> void:
	for i in grid_width * grid_height:
		_heightmap[i] = 0.0

	# Continents as [col, row, rx, ry, strength] in grid coordinates (160x100)
	# Low strength (0.35-0.50) to avoid everything becoming mountains
	var continents = [
		# === NORTH AMERICA ===
		[36, 25, 22, 15, 0.45],   # Main body (Canada/US)
		[13, 14, 10, 8, 0.35],    # Alaska / NW Canada
		[46, 29, 8, 8, 0.35],     # US East Coast
		[36, 37, 8, 6, 0.35],     # Mexico
		[43, 44, 4, 5, 0.30],     # Central America (isthmus)
		[43, 34, 4, 4, 0.30],     # Florida
		[41, 17, 8, 5, 0.30],     # Hudson Bay area

		# === SOUTH AMERICA ===
		[53, 58, 10, 24, 0.45],   # Main body
		[50, 48, 8, 10, 0.35],    # Colombia/Venezuela
		[62, 57, 8, 8, 0.35],     # Brazil bulge
		[54, 74, 4, 8, 0.30],     # Patagonia / Chile
		[53, 66, 3, 8, 0.30],     # Andes spine

		# === EUROPE ===
		[84, 22, 10, 10, 0.45],   # Western/Central Europe
		[88, 14, 8, 8, 0.35],     # Scandinavia
		[78, 28, 4, 5, 0.35],     # Iberia
		[79, 20, 2, 3, 0.30],     # British Isles
		[92, 19, 6, 6, 0.35],     # Eastern Europe
		[86, 26, 5, 5, 0.30],     # Italy/Balkans

		# === AFRICA ===
		[91, 56, 18, 26, 0.45],   # Central/South Africa
		[88, 38, 12, 12, 0.40],   # North Africa (Sahara)
		[96, 34, 6, 8, 0.35],     # Egypt / NE Africa
		[101, 61, 2, 4, 0.30],    # Madagascar
		[80, 47, 6, 10, 0.35],    # West Africa coast

		# === ASIA ===
		[118, 22, 34, 22, 0.45],  # Russia + China (main body)
		[115, 39, 3, 8, 0.40],    # India
		[127, 43, 12, 10, 0.35],  # SE Asia mainland
		[120, 14, 16, 8, 0.40],   # Siberia
		[104, 31, 12, 12, 0.35],  # Central Asia / Middle East
		[151, 19, 6, 6, 0.30],    # Kamchatka

		# === OCEANIA ===
		[140, 64, 10, 10, 0.45],  # Australia
		[132, 53, 8, 8, 0.35],    # Indonesia / PNG
		[156, 73, 4, 8, 0.25],    # New Zealand

		# === ISLANDS ===
		[61, 10, 8, 6, 0.35],     # Greenland
		[48, 41, 6, 4, 0.25],     # Caribbean
		[156, 58, 4, 4, 0.25],    # Pacific islands (Fiji/Tonga)
	]

	var noise = FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.08
	noise.fractal_octaves = 2
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	for col in grid_width:
		for row in grid_height:
			var val = 0.0
			for c in continents:
				var dx = float(col - c[0]) / float(c[2])
				var dy = float(row - c[1]) / float(c[3])
				var d2 = dx*dx + dy*dy
				if d2 < 1.0:
					var v = (1.0 - d2) * (1.0 - d2) * c[4]
					if v > val:
						val = v

			# Antarctica
			if row > 87:
				var ant = float(row - 87) / 12.0
				val += ant * ant * 0.5

			# Add noise perturbation
			var n = noise.get_noise_2d(float(col) * 0.3, float(row) * 0.3) * 0.04

			_heightmap[col + row * grid_width] = clamp(val + n, 0.0, 1.0)

	var min_elev = 1.0
	var max_elev = 0.0
	var land_count = 0
	for v in _heightmap:
		if v < min_elev: min_elev = v
		if v > max_elev: max_elev = v
		if v >= 0.25: land_count += 1
	print("Heightmap: min=", min_elev, " max=", max_elev, " land=", land_count, "/", _heightmap.size())

func _setup_moisture_noise() -> void:
	_noise_moisture = FastNoiseLite.new()
	_noise_moisture.seed = 42
	_noise_moisture.frequency = 0.012
	_noise_moisture.fractal_octaves = 3
	_noise_moisture.fractal_lacunarity = 2.0
	_noise_moisture.fractal_gain = 0.5
	_noise_moisture.noise_type = FastNoiseLite.TYPE_PERLIN


func _load_terrain_colors() -> void:
	terrain_colors = {}
	var file = FileAccess.open("res://assets/data/terrain.json", FileAccess.READ)
	if not file:
		_fallback_terrain_colors()
		return
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or not json.has("terrain_types"):
		_fallback_terrain_colors()
		return
	for key in json.terrain_types:
		var t = json.terrain_types[key]
		terrain_colors[t.id] = Color(t.color)
	if terrain_colors.is_empty():
		_fallback_terrain_colors()


func _fallback_terrain_colors() -> void:
	terrain_colors = {
		Constants.DEEP_WATER: Color("#0e2a4a"),
		Constants.SHALLOW_WATER: Color("#1a4a7a"),
		Constants.PLAINS: Color("#6aad3a"),
		Constants.FOREST: Color("#2a6a1e"),
		Constants.HILLS: Color("#8a7a3a"),
		Constants.MOUNTAINS: Color("#7a6a5a"),
		Constants.DESERT: Color("#d4b63a"),
		Constants.TUNDRA: Color("#b8c8b8")
	}


func _generate_terrain() -> void:
	for col in range(grid_width):
		for row in range(grid_height):
			var offset = Vector2i(col, row)
			var cube = _HexUtils.offset_to_cube(offset)

			var cell = _HexCell.new()
			cell.cube_coords = cube
			cell.offset_coords = offset
			cell.terrain = _calculate_terrain(offset)
			cell.elevation = _heightmap[col + row * grid_width]

			cells[cube] = cell

	queue_redraw()


func _calculate_terrain(offset: Vector2i) -> int:
	var col = offset.x
	var row = offset.y

	var ny = float(row) / float(grid_height)
	var elevation = _heightmap[col + row * grid_width]

	if elevation < 0.12:
		return Constants.DEEP_WATER
	elif elevation < 0.20:
		return Constants.SHALLOW_WATER

	# Civ 6-style latitude-based biomes
	var nx = float(col) / float(grid_width)
	var lat = abs(ny - 0.5) * 2.0
	var moisture = _noise_moisture.get_noise_2d(nx * 500.0, ny * 500.0)

	# Elevation: mountains > 0.42, hills > 0.28, flat <= 0.28
	if elevation > 0.42:
		if lat > 0.65:
			return Constants.MOUNTAINS
		elif moisture < -0.2:
			return Constants.HILLS
		else:
			return Constants.MOUNTAINS
	elif elevation > 0.28:
		if lat > 0.80:
			return Constants.TUNDRA
		elif lat > 0.50 and moisture < -0.3:
			return Constants.DESERT
		elif moisture < -0.2:
			return Constants.DESERT
		elif moisture < 0.2:
			return Constants.HILLS
		else:
			return Constants.FOREST

	# Flat land: latitude determines biome
	if lat > 0.85:
		return Constants.TUNDRA
	elif lat > 0.65:
		if moisture < 0.0:
			return Constants.TUNDRA
		elif moisture < 0.4:
			return Constants.PLAINS
		else:
			return Constants.FOREST
	elif lat > 0.50:
		if moisture < -0.3:
			return Constants.DESERT
		elif moisture < 0.1:
			return Constants.PLAINS
		elif moisture < 0.5:
			return Constants.FOREST
		else:
			return Constants.FOREST
	elif lat > 0.15:
		if moisture < -0.1:
			return Constants.DESERT
		elif moisture < 0.2:
			return Constants.PLAINS
		elif moisture < 0.5:
			return Constants.FOREST
		else:
			return Constants.FOREST
	else:
		if moisture < -0.3:
			return Constants.DESERT
		elif moisture < 0.1:
			return Constants.PLAINS
		else:
			return Constants.FOREST


func _print_terrain_stats() -> void:
	var counts = {}
	var elev_ranges = { "low": 0, "mid": 0, "high": 0 }
	for cube in cells:
		var c = cells[cube]
		var t = c.terrain
		counts[t] = counts.get(t, 0) + 1
		var e = c.elevation
		if e < 0.20: elev_ranges.low += 1
		elif e < 0.42: elev_ranges.mid += 1
		else: elev_ranges.high += 1
	var type_names = {Constants.DEEP_WATER:"DEEP_WATER", Constants.SHALLOW_WATER:"SHALLOW_WATER", Constants.PLAINS:"PLAINS", Constants.FOREST:"FOREST", Constants.HILLS:"HILLS", Constants.MOUNTAINS:"MOUNTAINS", Constants.DESERT:"DESERT", Constants.TUNDRA:"TUNDRA"}
	var parts = []
	for k in counts:
		parts.push_back(type_names.get(k, str(k)) + ":" + str(counts[k]))
	print("Terrain: ", ", ".join(parts))
	print("Elevation low(<0.20):", elev_ranges.low, " mid(0.20-0.42):", elev_ranges.mid, " high(>0.42):", elev_ranges.high)


func _generate_provinces() -> void:
	provinces = _ProvinceGenerator.generate(cells, grid_width, grid_height)


func _generate_nations() -> void:
	nations = _NationGenerator.generate(provinces, cells, 30)


func _generate_rivers() -> void:
	_RiverGenerator.generate(cells)


func _generate_resources() -> void:
	_ResourceGenerator.generate(cells)


func _on_game_tick(_tick: int) -> void:
	_EconomySystem.process_turn(nations, cells)


func _build_border_cache() -> void:
	_province_border_cache.clear()
	_nation_border_cache.clear()
	_river_edge_cache.clear()

	for cube in cells:
		var cell = cells[cube] if cells.has(cube) else null
		if not cell:
			continue
		var center = _HexUtils.cube_to_pixel(cube, hex_size)
		var verts = _HexUtils.hex_vertices(center, hex_size)

		for d in range(6):
			var neighbor = _HexUtils.cube_neighbor(cube, d)
			if not cells.has(neighbor):
				continue

			var my_pid = cell.province_id
			var n_pid = cells[neighbor].province_id

			if my_pid == -1 or n_pid == -1:
				continue

			var my_nid = cell.owner_nation_id
			var n_nid = cells[neighbor].owner_nation_id

			var vert_a = verts[d]
			var vert_b = verts[(d + 1) % 6]

			var cube_key = _cube_to_key(cube)
			var neighbor_key = _cube_to_key(neighbor)

			# River edges (only from lower-index cube to avoid duplicates)
			if cube_key < neighbor_key:
				if cell.is_river and not cells[neighbor].is_river:
					var width = 1.0
					if cell.flow_accumulation >= 100:
						width = 3.5
					elif cell.flow_accumulation >= 30:
						width = 2.5
					elif cell.flow_accumulation >= 8:
						width = 1.5
					_river_edge_cache.append([vert_a, vert_b, width])

			if cube_key < neighbor_key:
				if my_nid != n_nid:
					_nation_border_cache.append([vert_a, vert_b, cube])
				elif my_pid != n_pid:
					_province_border_cache.append([vert_a, vert_b])


static func _cube_to_key(c: Vector3) -> int:
	return int(c.x * 10000 + c.y * 100 + c.z)


func _draw() -> void:
	var hover_hex_verts: PackedVector2Array

	for cube in cells:
		var cell = cells[cube]
		var center = _HexUtils.cube_to_pixel(cube, hex_size)
		var verts = _HexUtils.hex_vertices(center, hex_size)

		var final_color: Color
		if _heightmap_color.size() > 0:
			var idx = cell.offset_coords.x + cell.offset_coords.y * grid_width
			final_color = _heightmap_color[idx] if idx < _heightmap_color.size() else Color.GRAY
		else:
			final_color = terrain_colors.get(cell.terrain, Color.GRAY)

		if show_political_mode and cell.owner_nation_id >= 0 and nations.has(cell.owner_nation_id):
			var nation_color = nations[cell.owner_nation_id].color
			final_color = final_color.lerp(nation_color, 0.15)

		draw_colored_polygon(verts, final_color)

		if cube == _hovered_cell:
			hover_hex_verts = verts

	for border in _province_border_cache:
		draw_line(border[0], border[1], Color(0.4, 0.4, 0.4, 0.4), 0.8, true)

	for border in _nation_border_cache:
		var col = Color(0.9, 0.9, 0.9, 0.85)
		if show_political_mode:
			var cube_a = border[2] as Vector3
			if cells.has(cube_a):
				var nid = cells[cube_a].owner_nation_id
				if nid >= 0 and nations.has(nid):
					col = nations[nid].color
		draw_line(border[0], border[1], col, 2.5, true)

	for edge in _river_edge_cache:
		draw_line(edge[0], edge[1], Color(0.2, 0.5, 0.9, 0.85), edge[2], true)

	for cube in cells:
		var cell = cells[cube]
		if cell.resource_type >= 0:
			var center = _HexUtils.cube_to_pixel(cube, hex_size)
			var icon = _ResourceData.get_icon(cell.resource_type)
			var color = _ResourceData.get_color(cell.resource_type)
			var font_size = 7
			draw_string(ThemeDB.fallback_font, center + Vector2(-3, 4), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	if not hover_hex_verts.is_empty():
		draw_colored_polygon(hover_hex_verts, Color(1, 1, 1, 0.15))
		draw_polyline(hover_hex_verts, Color.WHITE, 2.0, true)


func _process(_delta: float) -> void:
	var local_pos = get_global_mouse_position()
	if cells.is_empty():
		return
	var cube = _HexUtils.pixel_to_cube(local_pos, hex_size)
	if cube != _hovered_cell:
		_hovered_cell = cube
		if cells.has(cube):
			var cell = cells[cube]
			EventBus.hex_hovered.emit(_cell_to_dict(cell))
		else:
			EventBus.hex_unhovered.emit()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = get_global_mouse_position()
		var cube = _HexUtils.pixel_to_cube(local_pos, hex_size)
		if cells.has(cube):
			var cell = cells[cube]
			var data = _cell_to_dict(cell)
			EventBus.hex_clicked.emit(data)
			queue_redraw()


func _cell_to_dict(cell) -> Dictionary:
	var data = {
		"cube": cell.cube_coords,
		"offset": cell.offset_coords,
		"terrain": cell.terrain,
		"terrain_name": cell.get_terrain_name(),
		"elevation": cell.elevation,
		"province_id": cell.province_id,
		"population": cell.population,
		"infrastructure": cell.infrastructure,
		"owner_nation_id": cell.owner_nation_id,
		"is_passable": cell.is_passable(),
		"is_water": cell.is_water(),
		"is_river": cell.is_river,
		"flow_accumulation": cell.flow_accumulation,
		"resource_type": cell.resource_type,
		"resource_amount": cell.resource_amount
	}

	if cell.province_id >= 0 and provinces.has(cell.province_id):
		var prov = provinces[cell.province_id]
		data["province_name"] = prov.name
		data["province_hexes"] = prov.hexes.size()
		data["province_is_coastal"] = prov.is_coastal

	if cell.owner_nation_id >= 0 and nations.has(cell.owner_nation_id):
		var nation = nations[cell.owner_nation_id]
		data["nation_name"] = nation.name
		data["nation_color"] = nation.color.to_html(false)
		data["is_player"] = nation.is_player

	return data


func get_cell(cube: Vector3):
	return cells.get(cube, null)


func get_cells_in_range(center: Vector3, radius: int):
	var result: Array = []
	var cubes = _HexUtils.cube_spiral(center, radius)
	for c in cubes:
		if cells.has(c):
			result.append(cells[c])
	return result


func get_province(province_id: int):
	return provinces.get(province_id, null)


func get_nation(nation_id: int):
	return nations.get(nation_id, null)
