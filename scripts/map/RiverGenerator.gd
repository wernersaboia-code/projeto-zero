extends RefCounted

const _HexUtils = preload("res://scripts/map/HexUtils.gd")

const RIVER_THRESHOLD = 8
const STREAM_THRESHOLD = 30
const RIVER_THICK_THRESHOLD = 100


static func generate(cells: Dictionary) -> void:
	var land_cells: Array = []

	for cube in cells:
		var cell = cells[cube]
		if cell.elevation < 0.12:
			continue
		land_cells.append(cell)

	if land_cells.is_empty():
		return

	var smooth_elev: Dictionary = {}
	var max_elev = 0.0
	var min_elev = 999.0

	for cell in land_cells:
		var smooth = _compute_smooth_elevation(cell, cells)
		smooth_elev[cell.cube_coords] = smooth
		if smooth > max_elev: max_elev = smooth
		if smooth < min_elev: min_elev = smooth

	var elev_range = max_elev - min_elev
	if elev_range > 0:
		for cube in smooth_elev:
			smooth_elev[cube] = (smooth_elev[cube] - min_elev) / elev_range

	var flow_dir: Dictionary = {}

	for cell in land_cells:
		var best_dir = -1
		var best_elev = smooth_elev.get(cell.cube_coords, 0.5)
		for d in range(6):
			var neighbor = _HexUtils.cube_neighbor(cell.cube_coords, d)
			if not cells.has(neighbor):
				continue
			var n = cells[neighbor]
			if n.elevation < 0.12:
				if best_dir < 0 or 0.0 < best_elev:
					best_elev = 0.0
					best_dir = d
				continue
			var n_smooth = smooth_elev.get(neighbor, 0.5)
			if n_smooth < best_elev:
				best_elev = n_smooth
				best_dir = d
		flow_dir[cell.cube_coords] = best_dir

	land_cells.sort_custom(func(a, b):
		return smooth_elev.get(a.cube_coords, 0.0) > smooth_elev.get(b.cube_coords, 0.0))

	var accumulation: Dictionary = {}
	for cell in land_cells:
		accumulation[cell.cube_coords] = 1

	for cell in land_cells:
		var d = flow_dir.get(cell.cube_coords, -1)
		if d < 0:
			continue
		var downstream = _HexUtils.cube_neighbor(cell.cube_coords, d)
		if not accumulation.has(downstream):
			continue
		accumulation[downstream] += accumulation[cell.cube_coords]

	var stream_count = 0
	var river_count = 0
	var major_count = 0
	var max_acc = 0

	for cell in land_cells:
		var acc = accumulation.get(cell.cube_coords, 0)
		cell.flow_accumulation = acc
		cell.is_river = acc >= RIVER_THRESHOLD
		if cell.is_river:
			if acc >= RIVER_THICK_THRESHOLD:
				major_count += 1
			elif acc >= STREAM_THRESHOLD:
				river_count += 1
			else:
				stream_count += 1
		if acc > max_acc: max_acc = acc

	print("Rivers: streams=", stream_count, " rivers=", river_count, " major=", major_count, " max_acc=", max_acc)


static func _compute_smooth_elevation(cell, cells: Dictionary) -> float:
	var total = cell.elevation
	var count = 1
	for d in range(6):
		var neighbor = _HexUtils.cube_neighbor(cell.cube_coords, d)
		if cells.has(neighbor):
			total += cells[neighbor].elevation
			count += 1
	return total / count