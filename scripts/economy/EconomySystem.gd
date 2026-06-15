extends RefCounted

const R = preload("res://scripts/economy/ResourceData.gd")

const MAX_ITERATIONS: int = 10
const PROCESSING_ORDER: Array[int] = [
	R.Type.ELECTRIC_POWER,
	R.Type.INDUSTRY_GOODS,
	R.Type.CONSUMER_GOODS,
	R.Type.MILITARY_GOODS,
]


static func process_turn(nations: Dictionary, cells: Dictionary) -> void:
	for nid in nations:
		var nation = nations[nid]
		_process_nation_turn(nation, cells)


static func _process_nation_turn(nation, cells: Dictionary) -> void:
	nation.resource_production.clear()
	nation.resource_consumption.clear()

	# Step 1: extract raw resources from hex deposits
	for cube in cells:
		var cell = cells[cube]
		if cell.owner_nation_id != nation.id:
			continue
		if cell.resource_type >= 0 and R.is_raw(cell.resource_type):
			var prod = float(cell.resource_amount) * 0.1
			nation.resource_production[cell.resource_type] = nation.resource_production.get(cell.resource_type, 0.0) + prod

	# Step 2: multi-pass processed goods production
	# available pool = stockpile + raw extraction + processed production (updated each pass)
	var available: Dictionary = nation.resources.duplicate()
	for res_type in nation.resource_production:
		available[res_type] = available.get(res_type, 0.0) + nation.resource_production[res_type]

	var consumed_processing: Dictionary = {}
	var produced_processed: Dictionary = {}

	for iter in range(MAX_ITERATIONS):
		var any_produced = false

		for res_type in PROCESSING_ORDER:
			var recipe = R.get_recipe(res_type)
			if recipe.is_empty():
				continue

			var max_units = INF
			for input_res in recipe:
				var needed_per_unit = recipe[input_res]
				var pool = available.get(input_res, 0.0) - consumed_processing.get(input_res, 0.0)
				var possible = pool / needed_per_unit if needed_per_unit > 0 else INF
				if possible < max_units:
					max_units = possible

			max_units = floor(max_units)
			if max_units <= 0:
				continue

			any_produced = true
			for input_res in recipe:
				var total_needed = recipe[input_res] * max_units
				consumed_processing[input_res] = consumed_processing.get(input_res, 0.0) + total_needed
			produced_processed[res_type] = produced_processed.get(res_type, 0.0) + max_units
			available[res_type] = available.get(res_type, 0.0) + max_units

		if not any_produced:
			break

	# Step 3: population consumption from remaining available pool
	var pop = max(1, nation.population)
	var pop_consumed: Dictionary = {}

	pop_consumed[R.Type.AGRICULTURE] = min(
		pop * 0.001,
		max(0, available.get(R.Type.AGRICULTURE, 0.0) - consumed_processing.get(R.Type.AGRICULTURE, 0.0)))
	pop_consumed[R.Type.ELECTRIC_POWER] = min(
		pop * 0.0005,
		max(0, available.get(R.Type.ELECTRIC_POWER, 0.0) - consumed_processing.get(R.Type.ELECTRIC_POWER, 0.0)))
	pop_consumed[R.Type.CONSUMER_GOODS] = min(
		pop * 0.0001,
		max(0, available.get(R.Type.CONSUMER_GOODS, 0.0) - consumed_processing.get(R.Type.CONSUMER_GOODS, 0.0)))

	# Step 4: record final production and consumption
	for res_type in produced_processed:
		nation.resource_production[res_type] = nation.resource_production.get(res_type, 0.0) + produced_processed[res_type]

	var total_consumed: Dictionary = {}
	for res_type in consumed_processing:
		total_consumed[res_type] = total_consumed.get(res_type, 0.0) + consumed_processing[res_type]
	for res_type in pop_consumed:
		total_consumed[res_type] = total_consumed.get(res_type, 0.0) + pop_consumed[res_type]
	for res_type in total_consumed:
		nation.resource_consumption[res_type] = nation.resource_consumption.get(res_type, 0.0) + total_consumed[res_type]

	# Step 5: update stockpiles
	for res_type in range(R.Type.MILITARY_GOODS + 1):
		var prod = nation.resource_production.get(res_type, 0.0)
		var cons = nation.resource_consumption.get(res_type, 0.0)
		var current = nation.resources.get(res_type, 0.0)
		nation.resources[res_type] = max(0, current + prod - cons)

	# Step 6: treasury
	var total_prod_value = 0.0
	for res_type in nation.resource_production:
		var value_per_unit = 10.0
		if res_type >= R.Type.ELECTRIC_POWER:
			value_per_unit = 50.0
		elif R.is_raw(res_type) and res_type == R.Type.URANIUM:
			value_per_unit = 100.0
		total_prod_value += nation.resource_production[res_type] * value_per_unit

	nation.gdp = total_prod_value
	nation.treasury += total_prod_value * 0.3