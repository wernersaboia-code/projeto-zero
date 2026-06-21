extends RefCounted

static var _data: Dictionary = {}
static var _geo: Dictionary = {}
static var _loaded: bool = false
static var _geo_loaded: bool = false

static var _lookup: PackedInt32Array = PackedInt32Array()
static var _lookup_w: int = 0
static var _lookup_h: int = 0
static var _lookup_built: bool = false


static func load_data() -> Dictionary:
	if _loaded:
		return _data

	var file = FileAccess.open("res://assets/data/sr2030_regions.json", FileAccess.READ)
	if not file:
		push_warning("SR2030 data file not found")
		return {}

	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or not json.has("countries"):
		push_warning("Invalid SR2030 data")
		return {}

	_data = json
	_loaded = true
	print("SR2030Loader: loaded ", _data.countries.size(), " countries")
	return _data


static func load_geo_match() -> Dictionary:
	if _geo_loaded:
		return _geo

	var file = FileAccess.open("res://assets/data/sr2030_geo_match.json", FileAccess.READ)
	if not file:
		return {}

	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not json or not json.has("countries"):
		return {}

	for c in json.countries:
		_geo[int(c.id)] = c.boxes

	_geo_loaded = true
	print("SR2030Loader: loaded geo match for ", _geo.size(), " countries")
	return _geo


static func get_countries() -> Array:
	load_data()
	return _data.get("countries", [])


static func get_geo_match() -> Dictionary:
	load_geo_match()
	return _geo


# Build a 2D lookup grid rasterized from country bounding boxes.
# Countries are filled in ascending area order, first-write-wins, so the
# smallest-area country containing a cell takes precedence (matches the
# original find_country_for_cell tie-break rule).
static func _build_lookup() -> void:
	if _lookup_built:
		return
	var geo = get_geo_match()
	var countries = get_countries()
	if geo.is_empty() or countries.is_empty():
		_lookup_built = true
		return

	var max_c: int = 0
	var max_r: int = 0
	var entries: Array = []
	for c in countries:
		var cid: int = c.id
		if not geo.has(cid):
			continue
		var boxes = geo[cid]
		if boxes.size() < 4:
			continue
		var c_min: int = boxes[0]
		var c_max: int = boxes[1]
		var r_min: int = boxes[2]
		var r_max: int = boxes[3]
		if c_max > max_c:
			max_c = c_max
		if r_max > max_r:
			max_r = r_max
		var area: int = (c_max - c_min) * (r_max - r_min)
		entries.append({"cid": cid, "c_min": c_min, "c_max": c_max, "r_min": r_min, "r_max": r_max, "area": area})

	# Sort ascending by area so smallest areas are written first (first-write-wins).
	entries.sort_custom(func(a, b): return a.area < b.area)

	_lookup_w = max_c + 1
	_lookup_h = max_r + 1
	_lookup = PackedInt32Array()
	_lookup.resize(_lookup_w * _lookup_h)
	_lookup.fill(-1)

	for e in entries:
		var cid: int = e.cid
		for row in range(e.r_min, e.r_max + 1):
			var row_base = row * _lookup_w
			for col in range(e.c_min, e.c_max + 1):
				var idx = row_base + col
				if _lookup[idx] == -1:
					_lookup[idx] = cid
	_lookup_built = true


static func find_country_for_cell(col: int, row: int) -> int:
	if not _lookup_built:
		_build_lookup()
	if _lookup_w == 0:
		return -1
	if col < 0 or col >= _lookup_w or row < 0 or row >= _lookup_h:
		return -1
	return _lookup[col + row * _lookup_w]


static func get_country_by_id(id: int) -> Dictionary:
	for c in get_countries():
		if c.id == id:
			return c
	return {}


static func get_country_by_tag(tag: String) -> Dictionary:
	for c in get_countries():
		if c.tag == tag:
			return c
	return {}
