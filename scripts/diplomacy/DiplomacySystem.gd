extends RefCounted

const _HexUtils = preload("res://scripts/map/HexUtils.gd")


static func generate_initial_relations(nations: Dictionary, cells: Dictionary) -> void:
	var borders = _compute_borders(nations, cells)
	var rng = RandomNumberGenerator.new()
	rng.seed = 789

	var nid_list = []
	for nid in nations:
		nid_list.append(nid)
	nid_list.sort()

	for i in range(nid_list.size()):
		var nid_a = nid_list[i]
		var nation_a = nations[nid_a]

		for j in range(i + 1, nid_list.size()):
			var nid_b = nid_list[j]

			var is_border = borders.has(nid_a) and borders[nid_a].has(nid_b)
			var base = 0.5
			if is_border:
				base = 0.0
			else:
				base = 0.5

			var pair_seed = nid_a * 1000 + nid_b
			rng.seed = 789 + pair_seed
			var variation = rng.randf_range(-0.2, 0.2)
			var rel = clamp(base + variation, -1.0, 1.0)

			nation_a.diplomacy[nid_b] = rel
			nations[nid_b].diplomacy[nid_a] = rel


static func _compute_borders(nations: Dictionary, cells: Dictionary) -> Dictionary:
	var borders: Dictionary = {}

	for cube in cells:
		var cell = cells[cube]
		var nid = cell.owner_nation_id
		if nid < 0:
			continue
		if not borders.has(nid):
			borders[nid] = {}

		for d in range(6):
			var neighbor = _HexUtils.cube_neighbor(cube, d)
			if not cells.has(neighbor):
				continue
			var n_nid = cells[neighbor].owner_nation_id
			if n_nid >= 0 and n_nid != nid:
				borders[nid][n_nid] = true

	return borders
