extends RefCounted

const R = preload("res://scripts/economy/ResourceData.gd")


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

	# Step 2: process production chains (Electric Power → Consumer/Industry/Military Goods)
	var processing_order = [R.Type.ELECTRIC_POWER, R.Type.INDUSTRY_GOODS, R.Type.CONSUMER_GOODS, R.Type.MILITARY_GOODS]
	for res_type in processing_order:
		var recipe = R.get_recipe(res_type)
		if recipe.is_empty():
			continue

		var max_production = INF
		for input_res in recipe:
			var needed_per_unit = recipe[input_res]
			var available = nation.resources.get(input_res, 0.0) + nation.resource_production.get(input_res, 0.0)
			var possible = available / needed_per_unit if needed_per_unit > 0 else INF
			if possible < max_production:
				max_production = possible

		max_production = floor(max_production)
		if max_production <= 0:
			continue

		for input_res in recipe:
			var total_needed = recipe[input_res] * max_production
			var from_stockpile = min(total_needed, nation.resources.get(input_res, 0.0))
			var from_current_prod = total_needed - from_stockpile
			if from_current_prod > 0:
				var avail_prod = nation.resource_production.get(input_res, 0.0)
				var actual_from_prod = min(from_current_prod, avail_prod)
				nation.resource_production[input_res] = avail_prod - actual_from_prod
				from_stockpile = total_needed - actual_from_prod
			nation.resources[input_res] = nation.resources.get(input_res, 0.0) - from_stockpile
			nation.resource_consumption[input_res] = nation.resource_consumption.get(input_res, 0.0) + total_needed

		nation.resource_production[res_type] = nation.resource_production.get(res_type, 0.0) + max_production

	# Step 3: population consumption
	var pop = max(1, nation.population)
	var food_need = pop * 0.001
	var power_need = pop * 0.0005
	var goods_need = pop * 0.0001

	_consume(nation, R.Type.AGRICULTURE, food_need)
	_consume(nation, R.Type.ELECTRIC_POWER, power_need)
	_consume(nation, R.Type.CONSUMER_GOODS, goods_need)

	# Step 4: update stockpiles
	for res_type in range(R.Type.MILITARY_GOODS + 1):
		var prod = nation.resource_production.get(res_type, 0.0)
		var cons = nation.resource_consumption.get(res_type, 0.0)
		var current = nation.resources.get(res_type, 0.0)
		nation.resources[res_type] = max(0, current + prod - cons)

	# Step 5: treasury (GDP based on total raw + processed production)
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


static func _consume(nation, res_type: int, amount: float) -> void:
	if amount <= 0:
		return
	var stock = nation.resources.get(res_type, 0.0)
	var prod = nation.resource_production.get(res_type, 0.0)
	var total_available = stock + prod
	var consumed = min(amount, total_available)

	var from_prod = min(consumed, prod)
	var from_stock = consumed - from_prod

	nation.resources[res_type] = stock - from_stock
	nation.resource_production[res_type] = prod - from_prod
	nation.resource_consumption[res_type] = nation.resource_consumption.get(res_type, 0.0) + consumed