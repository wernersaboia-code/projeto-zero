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

func get_province_count() -> int:
	return province_ids.size()
