extends RefCounted

const _HexUtils = preload("res://scripts/map/HexUtils.gd")
const R = preload("res://scripts/economy/ResourceData.gd")

# Terrain-based deposit rules: {ResourceType: [probability, min_amount, max_amount]}
const DEPOSIT_RULES: Dictionary = {
	Constants.PLAINS: {
		R.Type.AGRICULTURE: [0.60, 10, 80],
		R.Type.COAL: [0.05, 5, 30],
		R.Type.PETROLEUM: [0.03, 5, 20]
	},
	Constants.FOREST: {
		R.Type.TIMBER: [0.70, 20, 100],
		R.Type.AGRICULTURE: [0.25, 5, 40],
		R.Type.RUBBER: [0.15, 10, 50],
		R.Type.COAL: [0.08, 5, 25]
	},
	Constants.WOODS: {
		R.Type.TIMBER: [0.50, 15, 80],
		R.Type.AGRICULTURE: [0.30, 5, 35],
		R.Type.RUBBER: [0.10, 5, 30]
	},
	Constants.HILLS: {
		R.Type.COAL: [0.40, 20, 80],
		R.Type.METAL_ORE: [0.30, 15, 70],
		R.Type.PETROLEUM: [0.05, 5, 15]
	},
	Constants.MOUNTAINS: {
		R.Type.METAL_ORE: [0.50, 30, 100],
		R.Type.COAL: [0.30, 15, 60],
		R.Type.URANIUM: [0.15, 5, 40]
	},
	Constants.DESERT: {
		R.Type.PETROLEUM: [0.30, 15, 80],
		R.Type.COAL: [0.10, 5, 30],
		R.Type.URANIUM: [0.05, 5, 20]
	},
	Constants.JUNGLE: {
		R.Type.TIMBER: [0.65, 20, 90],
		R.Type.RUBBER: [0.40, 15, 60],
		R.Type.AGRICULTURE: [0.20, 5, 30]
	},
	Constants.MARSH: {
		R.Type.PETROLEUM: [0.10, 5, 25],
		R.Type.AGRICULTURE: [0.15, 5, 20]
	},
	Constants.URBAN: {
		R.Type.AGRICULTURE: [0.30, 5, 20]
	},
	Constants.ARCTIC: {
		R.Type.PETROLEUM: [0.20, 10, 60],
		R.Type.URANIUM: [0.05, 5, 20]
	},
	Constants.TUNDRA: {
		R.Type.TIMBER: [0.15, 5, 30],
		R.Type.PETROLEUM: [0.15, 10, 60],
		R.Type.COAL: [0.10, 5, 20]
	},
	Constants.SHALLOW_WATER: {
		R.Type.PETROLEUM: [0.08, 5, 30]
	}
}

# Equatorial bonus for rubber (lat < 0.25)
const RUBBER_LAT_BONUS: float = 0.25


static func generate(cells: Dictionary) -> void:
	for cube in cells:
		var cell = cells[cube]
		if cell.is_water() and cell.terrain != Constants.SHALLOW_WATER:
			continue
		cell.resource_type = -1
		cell.resource_amount = 0

	var rng = RandomNumberGenerator.new()
	rng.seed = 123  # deterministic

	for cube in cells:
		var cell = cells[cube]
		if cell.is_water() and cell.terrain != Constants.SHALLOW_WATER:
			continue

		var rules = DEPOSIT_RULES.get(cell.terrain, {})
		if rules.is_empty():
			continue

		# Latitude adjustment for rubber (equatorial only)
		var ny = float(cell.offset_coords.y) / 200.0
		var lat_factor = abs(ny - 0.5) * 2.0

		var roll = rng.randf()
		var cumulative = 0.0
		for rt in rules:
			var rule = rules[rt]
			var prob = rule[0]

			# Rubber only in tropical latitudes
			if rt == R.Type.RUBBER and lat_factor > RUBBER_LAT_BONUS:
				prob *= 0.1

			cumulative += prob
			if roll <= cumulative:
				var amount = rng.randi_range(rule[1], rule[2])
				cell.resource_type = rt
				cell.resource_amount = amount
				break

	# Remove duplicates: if adjacent cells have the same resource,
	# merge into the one with higher amount (cluster cleanup)
	var resource_count = 0
	for cube in cells:
		var cell = cells[cube]
		if cell.resource_type >= 0:
			resource_count += 1
	print("Resources: ", resource_count, " deposits placed")