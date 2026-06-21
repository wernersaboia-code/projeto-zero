extends Resource

var id: int
var name: String
var nation_id: int = -1
var hexes: Array = []
var capital_hex: Vector3
var population: int = 0
var infrastructure: int = 0
var terrain_primary: int = -1
var is_coastal: bool = false
var area_sq_km: float = 0.0

func get_hex_count() -> int:
	return hexes.size()


func is_water() -> bool:
	return terrain_primary == Constants.OCEAN or terrain_primary == Constants.SHALLOW_WATER
