extends Node2D
class_name HexGrid

const _HexCell = preload("res://scripts/map/HexCell.gd")
const _HexUtils = preload("res://scripts/map/HexUtils.gd")
const _ProvinceData = preload("res://scripts/map/ProvinceData.gd")
const _ProvinceGenerator = preload("res://scripts/map/ProvinceGenerator.gd")
const _NationData = preload("res://scripts/map/NationData.gd")
const _NationGenerator = preload("res://scripts/map/NationGenerator.gd")
const _RiverGenerator = preload("res://scripts/map/RiverGenerator.gd")
const _SR2030Loader = preload("res://scripts/map/SR2030Loader.gd")
const _ResourceGenerator = preload("res://scripts/economy/ResourceGenerator.gd")
const _EconomySystem = preload("res://scripts/economy/EconomySystem.gd")
const _MarketSystem = preload("res://scripts/economy/MarketSystem.gd")
const _DiplomacySystem = preload("res://scripts/diplomacy/DiplomacySystem.gd")

signal grid_generated()

var cells: Dictionary = {}
var provinces: Dictionary = {}
var nations: Dictionary = {}

var grid_width: int = Constants.GRID_WIDTH
var grid_height: int = Constants.GRID_HEIGHT
var hex_size: float = 14.0

var show_political_mode: bool = true:
	set(v):
		show_political_mode = v
		_refresh_map_base()

var terrain_colors: Dictionary = {}
var _noise_moisture: FastNoiseLite
var _heightmap: Array = []
var _terrain_map: Array = []  # terrain type per cell (from terrain.bmp)
var _province_map: Array = []  # province color index per cell (from provinces.bmp), -1 if unavailable
var _hovered_cell: Vector3 = Vector3(99999, 99999, 99999)
var _nation_border_cache: Dictionary = {}  # nid -> PackedVector2Array of segment pairs
var _province_border_cache: PackedVector2Array = PackedVector2Array()  # flat segment pairs
var _river_edge_cache: Dictionary = {}  # width -> PackedVector2Array of segment pairs
var _heightmap_color: Array = []  # Color per cell (from PNG), empty = use procedural colors

var _map_base: Node2D  # child that draws expensive hex fills (redrawn only on data change)



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
	_generate_diplomacy()
	_print_population_stats()
	_generate_rivers()
	_generate_resources()
	_build_border_cache()
	EventBus.game_tick.connect(_on_game_tick)

	_setup_map_base()
	grid_generated.emit()
	EventBus.grid_status.emit(cells.size(), provinces.size(), nations.size())

	# Show nation selection screen
	_show_nation_select()


func _show_nation_select() -> void:
	if nations.is_empty():
		return
	var gm = get_tree().root.get_node("GameManager")
	if gm:
		gm.is_paused = true
	var select_scene = preload("res://scenes/ui/NationSelectScreen.tscn")
	var select = select_scene.instantiate()
	select.set_nations(nations)
	select.tree_exited.connect(_on_select_closed)
	add_child(select)


func _on_select_closed() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if tree == null:
		return
	var gm = tree.root.get_node("GameManager")
	if gm and gm.player_nation_id >= 0:
		gm.is_paused = false
		var nation = nations.get(gm.player_nation_id)
		if not nation:
			return
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_player_nation"):
			hud.set_player_nation(gm.player_nation_id)
		var ledger = get_tree().get_first_node_in_group("resource_ledger")
		if ledger and ledger.has_method("set_player_nation"):
			ledger.set_player_nation(nation)
	elif gm:
		# Fallback: auto-select first nation if selection was skipped
		if nations.is_empty():
			return
		var sorted = nations.values()
		sorted.sort_custom(func(a, b): return a.name < b.name)
		gm.player_nation_id = sorted[0].id
		gm.is_paused = false
		var nation = nations.get(gm.player_nation_id)
		if not nation:
			return
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_player_nation"):
			hud.set_player_nation(gm.player_nation_id)
		var ledger = get_tree().get_first_node_in_group("resource_ledger")
		if ledger and ledger.has_method("set_player_nation"):
			ledger.set_player_nation(nation)


func _setup_heightmap() -> void:
	_heightmap.resize(grid_width * grid_height)
	_terrain_map.resize(grid_width * grid_height)
	_terrain_map.fill(Constants.OCEAN)

	# Primary source: terrain.bmp (5616x2160, 8bpp indexed, palette from terrain.txt)
	# Provides exact terrain type per pixel. Downscaled to grid_width x grid_height.
	var terrain_bmp_path = "res://assets/data/maps/terrain.bmp"
	var has_terrain_bmp = FileAccess.file_exists(terrain_bmp_path)

	# Secondary source: earth_heightmap.png (320x200) for elevation
	var elev_img: Image = null
	var elev_path = "res://assets/data/maps/earth_heightmap.png"
	if FileAccess.file_exists(elev_path):
		var e_img = Image.new()
		var e_file = FileAccess.open(elev_path, FileAccess.READ)
		if e_file:
			var e_buf = e_file.get_buffer(e_file.get_length())
			e_file.close()
			var e_err = e_img.load_png_from_buffer(e_buf)
			if e_err == OK:
				if e_img.get_width() != grid_width or e_img.get_height() != grid_height:
					e_img.resize(grid_width, grid_height, Image.INTERPOLATE_LANCZOS)
				elev_img = e_img

	if has_terrain_bmp:
		_setup_from_terrain_bmp(terrain_bmp_path, elev_img)
	else:
		_fallback_terrain_from_heightmap(elev_img)

	# Build land mask from terrain types for distance-based elevation
	_build_land_mask_and_elevation(elev_img)

	# Load province boundaries from provinces.bmp
	_load_province_map()


func _setup_from_terrain_bmp(path: String, elev_img: Image) -> void:
	# Load the 8bpp indexed BMP and read raw palette indices.
	# Godot's Image.load() may not preserve palette indices for 8bpp BMP,
	# so we rely on the fact that terrain.bmp uses a grayscale palette where
	# R=G=B=index. We read the R channel as the index.
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_warning("Failed to load terrain.bmp, error: ", err, " — falling back")
		_fallback_terrain_from_heightmap(elev_img)
		return

	var src_w = img.get_width()
	var src_h = img.get_height()
	print("terrain.bmp loaded: ", src_w, "x", src_h)

	# Sample terrain type at each grid cell by nearest-neighbour downsampling.
	var palette = Constants.PALETTE_MAP
	var land_count = 0
	for row in grid_height:
		var sy = int(float(row) / float(grid_height) * float(src_h))
		if sy >= src_h:
			sy = src_h - 1
		var row_base = row * grid_width
		for col in grid_width:
			var sx = int(float(col) / float(grid_width) * float(src_w))
			if sx >= src_w:
				sx = src_w - 1
			var p = img.get_pixel(sx, sy)
			# In 8bpp grayscale BMP, R=G=B=palette index.
			var idx = int(p.r * 255.0)
			var t = palette.get(idx, Constants.OCEAN)
			_terrain_map[col + row_base] = t
			if t != Constants.OCEAN:
				land_count += 1

	print("Terrain from BMP: land=", land_count, "/", grid_width * grid_height)

	# Also store heightmap colors for the MapBaseDrawer to render the source image.
	if elev_img:
		_heightmap_color.resize(grid_width * grid_height)
		for c in grid_width:
			for r in grid_height:
				_heightmap_color[c + r * grid_width] = elev_img.get_pixel(c, r)


func _load_province_map() -> void:
	var prov_path = "res://assets/data/maps/provinces.bmp"
	if not FileAccess.file_exists(prov_path):
		return

	_province_map.resize(grid_width * grid_height)
	_province_map.fill(-1)

	var img = Image.new()
	var err = img.load(prov_path)
	if err != OK:
		push_warning("Failed to load provinces.bmp")
		return

	var src_w = img.get_width()
	var src_h = img.get_height()
	var data = img.get_data()
	var fmt = img.get_format()
	var bpp = 4 if fmt == Image.FORMAT_RGBA8 else 3
	var src_pitch = src_w * bpp

	var color_to_id: Dictionary = {}
	var next_id = 0
	var matched = 0

	var h_factor = float(src_h) / float(grid_height)
	var w_factor = float(src_w) / float(grid_width)

	for row in grid_height:
		var sy = int(float(row) * h_factor)
		if sy >= src_h:
			sy = src_h - 1
		var src_row_start = sy * src_pitch
		var row_base = row * grid_width
		for col in grid_width:
			var sx = int(float(col) * w_factor)
			if sx >= src_w:
				sx = src_w - 1
			var src_idx = src_row_start + sx * bpp
			var key = int(data[src_idx]) << 16 | int(data[src_idx + 1]) << 8 | int(data[src_idx + 2])
			var cid = color_to_id.get(key)
			if cid == null:
				cid = next_id
				color_to_id[key] = next_id
				next_id += 1
			_province_map[col + row_base] = cid
			if _terrain_map[col + row_base] != Constants.OCEAN:
				matched += 1

	print("Provinces: ", next_id, " unique colors, ", matched, " land cells covered")


func _fallback_terrain_from_heightmap(elev_img: Image) -> void:
	# Legacy path: derive terrain from earth_heightmap.png using elevation + latitude.
	# Only used if terrain.bmp is missing.
	if elev_img:
		_heightmap_color.resize(grid_width * grid_height)
		for c in grid_width:
			for r in grid_height:
				_heightmap_color[c + r * grid_width] = elev_img.get_pixel(c, r)
		for col in grid_width:
			for row in grid_height:
				_terrain_map[col + row * grid_width] = _calculate_terrain_fallback(Vector2i(col, row), elev_img)
	else:
		_generate_procedural_heightmap()


func _build_land_mask_and_elevation(elev_img: Image) -> void:
	# Build land mask from terrain types
	var land_mask = []
	land_mask.resize(grid_width * grid_height)
	for i in grid_width * grid_height:
		land_mask[i] = _terrain_map[i] != Constants.OCEAN

	# Distance from coast (land inward) for elevation shaping
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
					if dc == 0 and dr == 0:
						continue
					var nc = col + dc
					var nr = row + dr
					if nc < 0 or nc >= grid_width or nr < 0 or nr >= grid_height:
						continue
					if not land_mask[nc + nr * grid_width]:
						coastal = true
						break
				if coastal:
					break
			dist_land[idx] = 1 if coastal else 999

	# Two-pass sweep for land distance
	for row in grid_height:
		var row_base = row * grid_width
		for col in grid_width:
			var idx = col + row_base
			if dist_land[idx] == -1:
				continue
			var best = dist_land[idx]
			if row > 0:
				var up_base = (row - 1) * grid_width
				if col > 0:
					var nv = dist_land[up_base + col - 1]
					if nv >= 0 and nv + 1 < best:
						best = nv + 1
				var nv_u = dist_land[up_base + col]
				if nv_u >= 0 and nv_u + 1 < best:
					best = nv_u + 1
				if col + 1 < grid_width:
					var nv_ur = dist_land[up_base + col + 1]
					if nv_ur >= 0 and nv_ur + 1 < best:
						best = nv_ur + 1
			if col > 0:
				var nv_l = dist_land[row_base + col - 1]
				if nv_l >= 0 and nv_l + 1 < best:
					best = nv_l + 1
			dist_land[idx] = best
	for row in range(grid_height - 1, -1, -1):
		var row_base = row * grid_width
		for col in range(grid_width - 1, -1, -1):
			var idx = col + row_base
			if dist_land[idx] == -1:
				continue
			var best = dist_land[idx]
			if row + 1 < grid_height:
				var dn_base = (row + 1) * grid_width
				if col + 1 < grid_width:
					var nv = dist_land[dn_base + col + 1]
					if nv >= 0 and nv + 1 < best:
						best = nv + 1
				var nv_d = dist_land[dn_base + col]
				if nv_d >= 0 and nv_d + 1 < best:
					best = nv_d + 1
				if col > 0:
					var nv_dl = dist_land[dn_base + col - 1]
					if nv_dl >= 0 and nv_dl + 1 < best:
						best = nv_dl + 1
			if col + 1 < grid_width:
				var nv_r = dist_land[row_base + col + 1]
				if nv_r >= 0 and nv_r + 1 < best:
					best = nv_r + 1
			dist_land[idx] = best

	# Distance from coast (water outward) for shallow water
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
					if dc == 0 and dr == 0:
						continue
					var nc = col + dc
					var nr = row + dr
					if nc < 0 or nc >= grid_width or nr < 0 or nr >= grid_height:
						continue
					if land_mask[nc + nr * grid_width]:
						coastal = true
						break
				if coastal:
					break
			dist_water[idx] = 1 if coastal else 999

	for row in grid_height:
		var row_base = row * grid_width
		for col in grid_width:
			var idx = col + row_base
			if dist_water[idx] == -1:
				continue
			var best = dist_water[idx]
			if row > 0:
				var up_base = (row - 1) * grid_width
				if col > 0:
					var nv = dist_water[up_base + col - 1]
					if nv >= 0 and nv + 1 < best:
						best = nv + 1
				var nv_u = dist_water[up_base + col]
				if nv_u >= 0 and nv_u + 1 < best:
					best = nv_u + 1
				if col + 1 < grid_width:
					var nv_ur = dist_water[up_base + col + 1]
					if nv_ur >= 0 and nv_ur + 1 < best:
						best = nv_ur + 1
			if col > 0:
				var nv_l = dist_water[row_base + col - 1]
				if nv_l >= 0 and nv_l + 1 < best:
					best = nv_l + 1
			dist_water[idx] = best
	for row in range(grid_height - 1, -1, -1):
		var row_base = row * grid_width
		for col in range(grid_width - 1, -1, -1):
			var idx = col + row_base
			if dist_water[idx] == -1:
				continue
			var best = dist_water[idx]
			if row + 1 < grid_height:
				var dn_base = (row + 1) * grid_width
				if col + 1 < grid_width:
					var nv = dist_water[dn_base + col + 1]
					if nv >= 0 and nv + 1 < best:
						best = nv + 1
				var nv_d = dist_water[dn_base + col]
				if nv_d >= 0 and nv_d + 1 < best:
					best = nv_d + 1
				if col > 0:
					var nv_dl = dist_water[dn_base + col - 1]
					if nv_dl >= 0 and nv_dl + 1 < best:
						best = nv_dl + 1
			if col + 1 < grid_width:
				var nv_r = dist_water[row_base + col + 1]
				if nv_r >= 0 and nv_r + 1 < best:
					best = nv_r + 1
			dist_water[idx] = best

	# Assign elevation based on distance from coast + terrain type
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
			var t = _terrain_map[idx]
			if t == Constants.OCEAN:
				var d = dist_water[idx]
				if d <= 0 or d >= 999:
					_heightmap[idx] = 0.06
				elif d <= 2:
					_heightmap[idx] = 0.16
					_terrain_map[idx] = Constants.SHALLOW_WATER
				else:
					_heightmap[idx] = 0.06 + (0.06 * min(d, 6)) / 8.0
			else:
				var d = dist_land[idx]
				if d > max_dist:
					max_dist = d
				var base = 0.20 + min(d, 60.0) / 30.0
				# Terrain-based elevation modifiers
				match t:
					Constants.MOUNTAINS:
						base += 0.30
					Constants.HILLS:
						base += 0.12
					Constants.URBAN:
						base += 0.02
				var n = noise.get_noise_2d(float(col) * 0.15, float(row) * 0.15) * 0.10
				_heightmap[idx] = clamp(base + n, 0.12, 0.95)
				land_count += 1

	print("Elevation built: land=", land_count, " max_dist=", max_dist)


func _calculate_terrain_fallback(offset: Vector2i, elev_img: Image) -> int:
	# Legacy heuristic terrain classifier (only used when terrain.bmp is missing).
	var col = offset.x
	var row = offset.y
	var elevation = _heightmap[col + row * grid_width]

	if elevation < 0.12:
		return Constants.OCEAN
	elif elevation < 0.20:
		return Constants.SHALLOW_WATER

	var ny = float(row) / float(grid_height)
	var lat = abs(ny - 0.5) * 2.0
	var nx = float(col) / float(grid_width)
	var moisture = _noise_moisture.get_noise_2d(nx * 500.0, ny * 500.0)

	if elevation > 0.42:
		if lat > 0.65:
			return Constants.MOUNTAINS
		elif moisture < -0.2:
			return Constants.HILLS
		else:
			return Constants.MOUNTAINS
	elif elevation > 0.28:
		if lat > 0.80:
			return Constants.ARCTIC
		elif lat > 0.50 and moisture < -0.3:
			return Constants.DESERT
		elif moisture < -0.2:
			return Constants.DESERT
		elif moisture < 0.2:
			return Constants.HILLS
		else:
			return Constants.FOREST

	if lat > 0.85:
		return Constants.ARCTIC
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
		else:
			return Constants.FOREST
	elif lat > 0.15:
		if moisture < -0.1:
			return Constants.DESERT
		elif moisture < 0.2:
			return Constants.PLAINS
		else:
			return Constants.FOREST
	else:
		if moisture < -0.3:
			return Constants.DESERT
		elif moisture < 0.1:
			return Constants.PLAINS
		else:
			return Constants.JUNGLE



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
		Constants.OCEAN: Color("#0e2a4a"),
		Constants.SHALLOW_WATER: Color("#1a4a7a"),
		Constants.PLAINS: Color("#f1ddb8"),
		Constants.FOREST: Color("#274f0c"),
		Constants.WOODS: Color("#5b7b2d"),
		Constants.HILLS: Color("#874600"),
		Constants.MOUNTAINS: Color("#756c77"),
		Constants.DESERT: Color("#dac300"),
		Constants.JUNGLE: Color("#209700"),
		Constants.MARSH: Color("#4c7069"),
		Constants.URBAN: Color("#8968a5"),
		Constants.ARCTIC: Color("#ebebeb"),
		Constants.TUNDRA: Color("#b8c8b8")
	}


func _generate_terrain() -> void:
	var pop_rng = RandomNumberGenerator.new()
	pop_rng.seed = 456

	for col in range(grid_width):
		for row in range(grid_height):
			var offset = Vector2i(col, row)
			var cube = _HexUtils.offset_to_cube(offset)

			var cell = _HexCell.new()
			cell.cube_coords = cube
			cell.offset_coords = offset
			cell.terrain = _terrain_map[col + row * grid_width]
			cell.elevation = _heightmap[col + row * grid_width]

			var density = Constants.POPULATION_DENSITY.get(cell.terrain, [0, 0])
			if density is Array and density.size() == 2:
				cell.population = pop_rng.randi_range(density[0], density[1])
			else:
				cell.population = 0

			cells[cube] = cell

	queue_redraw()


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
	var type_names = {
		Constants.OCEAN:"OCEAN", Constants.SHALLOW_WATER:"SHALLOW_WATER",
		Constants.PLAINS:"PLAINS", Constants.FOREST:"FOREST", Constants.WOODS:"WOODS",
		Constants.HILLS:"HILLS", Constants.MOUNTAINS:"MOUNTAINS", Constants.DESERT:"DESERT",
		Constants.JUNGLE:"JUNGLE", Constants.MARSH:"MARSH", Constants.URBAN:"URBAN",
		Constants.ARCTIC:"ARCTIC", Constants.TUNDRA:"TUNDRA"
	}
	var parts = []
	for k in counts:
		parts.push_back(type_names.get(k, str(k)) + ":" + str(counts[k]))
	print("Terrain: ", ", ".join(parts))
	print("Elevation low(<0.20):", elev_ranges.low, " mid(0.20-0.42):", elev_ranges.mid, " high(>0.42):", elev_ranges.high)


func _print_population_stats() -> void:
	var total_pop = 0
	var top = []
	for nid in nations:
		var pop = nations[nid].population
		total_pop += pop
		top.append({"name": nations[nid].name, "pop": pop})
	top.sort_custom(func(a, b): return a.pop > b.pop)
	var top_str = []
	for t in top.slice(0, 10):
		top_str.append("%s:%d" % [t.name, t.pop])
	print("Total population: ", total_pop, " (x1000)")
	print("Top nations: ", ", ".join(top_str))


func _print_diplomacy_stats() -> void:
	var hostile = 0
	var neutral = 0
	var friendly = 0
	var total_pairs = 0
	for nid in nations:
		for other in nations[nid].diplomacy:
			var rel = nations[nid].diplomacy[other]
			if rel < -0.3:
				hostile += 1
			elif rel < 0.3:
				neutral += 1
			else:
				friendly += 1
			total_pairs += 1
	total_pairs /= 2
	hostile /= 2
	neutral /= 2
	friendly /= 2
	print("Diplomacy: ", total_pairs, " pairs, hostile:", hostile, " neutral:", neutral, " friendly:", friendly)


func _generate_provinces() -> void:
	provinces = _ProvinceGenerator.generate(cells, grid_width, grid_height)


func _generate_nations() -> void:
	_SR2030Loader.set_target_grid(grid_width, grid_height)
	nations = _NationGenerator.generate(provinces, cells, 30)


func _generate_diplomacy() -> void:
	_DiplomacySystem.generate_initial_relations(nations, cells)
	_print_diplomacy_stats()


func _generate_rivers() -> void:
	_RiverGenerator.generate(cells)


func _generate_resources() -> void:
	_ResourceGenerator.generate(cells)


func _setup_map_base() -> void:
	_map_base = _MapBaseDrawer.new()
	_map_base.name = "MapBase"
	_map_base.hex_grid = self
	add_child(_map_base)
	_map_base.rebuild()


func _refresh_map_base() -> void:
	if _map_base:
		_map_base.rebuild()


# Renders the expensive hex base. Hex fills use a MultiMesh (one GPU draw call
# for all cells); resource icons are drawn via _draw() from a cached list.
# The MultiMesh sits at z_index -1 so borders/rivers/hover (drawn by HexGrid)
# render on top of the fills.
class _MapBaseDrawer extends Node2D:
	var hex_grid: HexGrid
	const _Utils = preload("res://scripts/map/HexUtils.gd")
	const _R = preload("res://scripts/economy/ResourceData.gd")

	var _mm_instance: MultiMeshInstance2D
	var _hex_mesh: ArrayMesh
	var _icon_draws: Array = []  # each entry: [Vector2 pos, String icon, Color color]

	func rebuild() -> void:
		if not hex_grid:
			queue_redraw()
			return
		if _hex_mesh == null:
			_hex_mesh = _build_hex_mesh(hex_grid.hex_size)
		if _mm_instance == null:
			_mm_instance = MultiMeshInstance2D.new()
			_mm_instance.z_index = -1
			add_child(_mm_instance)

		var cells = hex_grid.cells
		var utils = _Utils
		var hsize = hex_grid.hex_size
		var hmap_color = hex_grid._heightmap_color
		var colors = hex_grid.terrain_colors
		var gwidth = hex_grid.grid_width
		var pol = hex_grid.show_political_mode
		var nations = hex_grid.nations

		var n: int = cells.size()
		var mm = MultiMesh.new()
		mm.mesh = _hex_mesh
		mm.use_colors = true
		mm.instance_count = n

		var icon_draws: Array = []
		var i: int = 0
		for cube in cells:
			var cell = cells[cube]
			var center = utils.cube_to_pixel(cube, hsize)

			var base_color: Color
			if hmap_color.size() > 0:
				var idx = cell.offset_coords.x + cell.offset_coords.y * gwidth
				base_color = hmap_color[idx] if idx < hmap_color.size() else Color.GRAY
			else:
				base_color = colors.get(cell.terrain, Color.GRAY)

			if pol and cell.owner_nation_id >= 0 and nations.has(cell.owner_nation_id):
				base_color = base_color.lerp(nations[cell.owner_nation_id].color, 0.15)

			mm.set_instance_transform_2d(i, Transform2D(0.0, center))
			mm.set_instance_color(i, base_color)
			i += 1

			if cell.resource_type >= 0:
				icon_draws.append([center + Vector2(-3, 4), _R.get_icon(cell.resource_type), _R.get_color(cell.resource_type)])

		_mm_instance.multimesh = mm
		_icon_draws = icon_draws
		queue_redraw()

	func _draw() -> void:
		var font = ThemeDB.fallback_font
		for d in _icon_draws:
			draw_string(font, d[0], d[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, d[2])

	func _build_hex_mesh(size: float) -> ArrayMesh:
		var mesh = ArrayMesh.new()
		var verts := PackedVector2Array()
		verts.append(Vector2.ZERO)
		for v in _Utils.VERTEX_FLAT_TOP:
			verts.append(v * size)
		var indices := PackedInt32Array()
		for i in 6:
			indices.append(0)
			indices.append(i + 1)
			indices.append(((i + 1) % 6) + 1)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


func _on_game_tick(_tick: int) -> void:
	_EconomySystem.calculate_all(nations, cells)
	_MarketSystem.process_trade(nations)
	_EconomySystem.apply_all(nations)


func _build_border_cache() -> void:
	_province_border_cache = PackedVector2Array()
	_nation_border_cache = {}
	_river_edge_cache = {}

	# Build into mutable Arrays first (reference semantics), then pack.
	var province_lines: Array = []
	var nation_lines: Dictionary = {}  # nid -> Array of Vector2 pairs
	var river_lines: Dictionary = {}   # width -> Array of Vector2 pairs

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

			# Each undirected edge is handled once (lower-key side).
			if cube_key >= neighbor_key:
				continue

			# River edges
			if cell.is_river and not cells[neighbor].is_river:
				var width = 1.0
				if cell.flow_accumulation >= 100:
					width = 3.5
				elif cell.flow_accumulation >= 30:
					width = 2.5
				elif cell.flow_accumulation >= 8:
					width = 1.5
				var r_arr = river_lines.get(width, null)
				if r_arr == null:
					r_arr = []
					river_lines[width] = r_arr
				r_arr.append(vert_a)
				r_arr.append(vert_b)

			# Nation / province borders
			if my_nid != n_nid:
				var n_arr = nation_lines.get(my_nid, null)
				if n_arr == null:
					n_arr = []
					nation_lines[my_nid] = n_arr
				n_arr.append(vert_a)
				n_arr.append(vert_b)
			elif my_pid != n_pid:
				province_lines.append(vert_a)
				province_lines.append(vert_b)

	_province_border_cache = PackedVector2Array(province_lines)
	for nid in nation_lines:
		_nation_border_cache[nid] = PackedVector2Array(nation_lines[nid])
	for w in river_lines:
		_river_edge_cache[w] = PackedVector2Array(river_lines[w])


static func _cube_to_key(c: Vector3) -> int:
	return int(c.x * 10000 + c.y * 100 + c.z)


func _draw() -> void:
	var hover_verts: PackedVector2Array
	var hover_cube: Vector3 = _hovered_cell

	if cells.has(hover_cube):
		var center = _HexUtils.cube_to_pixel(hover_cube, hex_size)
		hover_verts = _HexUtils.hex_vertices(center, hex_size)

	if _province_border_cache.size() > 0:
		draw_multiline(_province_border_cache, Color(0.4, 0.4, 0.4, 0.4), 0.8, true)

	for nid in _nation_border_cache:
		var col = Color(0.9, 0.9, 0.9, 0.85)
		if show_political_mode and nid >= 0 and nations.has(nid):
			col = nations[nid].color
		draw_multiline(_nation_border_cache[nid], col, 2.5, true)

	for w in _river_edge_cache:
		draw_multiline(_river_edge_cache[w], Color(0.2, 0.5, 0.9, 0.85), w, true)

	if not hover_verts.is_empty():
		draw_colored_polygon(hover_verts, Color(1, 1, 1, 0.15))
		draw_polyline(hover_verts, Color.WHITE, 2.0, true)


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
