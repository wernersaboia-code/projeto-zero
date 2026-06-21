extends RefCounted

var cube_coords: Vector3
var offset_coords: Vector2i
var terrain: int = 2  # PLAINS default
var elevation: float = 0.0
var province_id: int = -1
var population: int = 0
var infrastructure: int = 0
var owner_nation_id: int = -1
var is_river: bool = false
var flow_accumulation: int = 0
var resource_type: int = -1
var resource_amount: int = 0


func get_terrain_name() -> String:
	match terrain:
		Constants.OCEAN: return "Ocean"
		Constants.SHALLOW_WATER: return "Shallow Water"
		Constants.PLAINS: return "Plains"
		Constants.FOREST: return "Forest"
		Constants.WOODS: return "Woods"
		Constants.HILLS: return "Hills"
		Constants.MOUNTAINS: return "Mountains"
		Constants.DESERT: return "Desert"
		Constants.JUNGLE: return "Jungle"
		Constants.MARSH: return "Marsh"
		Constants.URBAN: return "Urban"
		Constants.ARCTIC: return "Arctic"
		Constants.TUNDRA: return "Tundra"
	return "Unknown"


func is_passable() -> bool:
	return terrain != Constants.OCEAN and terrain != Constants.MOUNTAINS


func is_water() -> bool:
	return terrain == Constants.OCEAN or terrain == Constants.SHALLOW_WATER
