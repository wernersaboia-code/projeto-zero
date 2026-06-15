extends RefCounted

const R = preload("res://scripts/economy/ResourceData.gd")

const BASE_PRICES: Dictionary = {
	R.Type.AGRICULTURE: 10.0,
	R.Type.RUBBER: 15.0,
	R.Type.TIMBER: 8.0,
	R.Type.PETROLEUM: 25.0,
	R.Type.COAL: 12.0,
	R.Type.METAL_ORE: 18.0,
	R.Type.URANIUM: 100.0,
	R.Type.ELECTRIC_POWER: 50.0,
	R.Type.CONSUMER_GOODS: 60.0,
	R.Type.INDUSTRY_GOODS: 45.0,
	R.Type.MILITARY_GOODS: 80.0,
}

const TRADE_FRACTION: float = 0.5


static func process_trade(nations: Dictionary) -> void:
	for nid in nations:
		nations[nid].trade_balance = 0.0

	for res_type in range(R.Type.MILITARY_GOODS + 1):
		_trade_resource(nations, res_type)


static func _trade_resource(nations: Dictionary, res_type: int) -> void:
	var sellers: Array[Dictionary] = []
	var buyers: Array[Dictionary] = []

	for nid in nations:
		var nation = nations[nid]
		var bal = nation.get_resource_balance(res_type)

		if bal > 0.001:
			var offer = bal * TRADE_FRACTION
			sellers.append({"nation": nation, "amount": offer})
		elif bal < -0.001:
			buyers.append({"nation": nation, "amount": -bal})

	if sellers.is_empty() or buyers.is_empty():
		return

	var total_supply = 0.0
	for s in sellers:
		total_supply += s.amount
	var total_demand = 0.0
	for b in buyers:
		total_demand += b.amount

	var base_price = BASE_PRICES.get(res_type, 10.0)
	var price_mult = 1.0
	if total_demand > 0 and total_supply > 0:
		var ratio = total_supply / total_demand
		price_mult = clamp(2.0 / (1.0 + ratio), 0.5, 2.0)
	var price = base_price * price_mult

	var si = 0
	var bi = 0

	while si < sellers.size() and bi < buyers.size():
		var seller = sellers[si]
		var buyer = buyers[bi]
		var amount = min(seller.amount, buyer.amount)

		if amount <= 0.001:
			si += 1
			bi += 1
			continue

		var cost = amount * price

		# Seller: sold to market → production decreases
		seller.nation.resource_production[res_type] = seller.nation.resource_production.get(res_type, 0.0) - amount
		seller.nation.treasury += cost
		seller.nation.trade_balance += cost

		# Buyer: bought from market → consumption decreases
		buyer.nation.resource_consumption[res_type] = buyer.nation.resource_consumption.get(res_type, 0.0) - amount
		buyer.nation.treasury -= cost
		buyer.nation.trade_balance -= cost

		seller.amount -= amount
		buyer.amount -= amount

		if seller.amount <= 0.001:
			si += 1
		if buyer.amount <= 0.001:
			bi += 1