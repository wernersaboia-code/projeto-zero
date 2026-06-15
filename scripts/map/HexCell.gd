extends Resource

const DEEP_WATER = 0
const SHALLOW_WATER = 1
const PLAINS = 2
const FOREST = 3
const HILLS = 4
const MOUNTAINS = 5
const DESERT = 6
const TUNDRA = 7

var cube_coords: Vector3
var offset_coords: Vector2i
var terrain: int = PLAINS
var elevation: float = 0.0
var province_id: int = -1
var population: int = 0
var infrastructure: int = 0
var owner_nation_id: int = -1
var is_river: bool = false
var flow_accumulation: int = 0


func get_terrain_name() -> String:
	match terrain:
		DEEP_WATER: return "Deep Water"
		SHALLOW_WATER: return "Shallow Water"
		PLAINS: return "Plains"
		FOREST: return "Forest"
		HILLS: return "Hills"
		MOUNTAINS: return "Mountains"
		DESERT: return "Desert"
		TUNDRA: return "Tundra"
	return "Unknown"


func is_passable() -> bool:
	return terrain != DEEP_WATER and terrain != MOUNTAINS


func is_water() -> bool:
	return terrain == DEEP_WATER or terrain == SHALLOW_WATER
