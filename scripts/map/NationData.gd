extends Resource

var id: int
var name: String
var color: Color
var province_ids: Array[int] = []
var capital_province_id: int = -1
var government_type: String = "democracy"
var is_player: bool = false

# Economic stats
var treasury: float = 10000.0
var gdp: float = 0.0
var population: int = 0
var trade_balance: float = 0.0  # positive = net exporter, negative = net importer

# Resource stockpile (current stored amount of each resource)
var resources: Dictionary = {}  # ResourceType -> float
# Resource production per turn (from deposits + buildings)
var resource_production: Dictionary = {}  # ResourceType -> float
# Resource consumption per turn (from production chains + population)
var resource_consumption: Dictionary = {}  # ResourceType -> float

func get_resource_balance(res_type: int) -> float:
	return resource_production.get(res_type, 0.0) - resource_consumption.get(res_type, 0.0)

func get_resource_stock(res_type: int) -> float:
	return resources.get(res_type, 0.0)

func get_province_count() -> int:
	return province_ids.size()
