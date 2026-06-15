extends RefCounted

static var _data: Dictionary = {}
static var _geo: Dictionary = {}
static var _loaded: bool = false
static var _geo_loaded: bool = false


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


static func find_country_for_cell(col: int, row: int) -> int:
	var geo = get_geo_match()
	var best_cid = -1
	var best_area = 0
	for c in get_countries():
		var cid: int = c.id
		if not geo.has(cid):
			continue
		var boxes = geo[cid]
		if boxes.size() < 4:
			continue
		var c_min = boxes[0]
		var c_max = boxes[1]
		var r_min = boxes[2]
		var r_max = boxes[3]
		if col >= c_min and col <= c_max and row >= r_min and row <= r_max:
			var area = (c_max - c_min) * (r_max - r_min)
			if best_cid < 0 or area < best_area:
				best_cid = cid
				best_area = area
	return best_cid


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
