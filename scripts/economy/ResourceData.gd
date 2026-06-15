extends RefCounted

enum Type {
	AGRICULTURE = 0,
	RUBBER = 1,
	TIMBER = 2,
	PETROLEUM = 3,
	COAL = 4,
	METAL_ORE = 5,
	URANIUM = 6,
	ELECTRIC_POWER = 7,
	CONSUMER_GOODS = 8,
	INDUSTRY_GOODS = 9,
	MILITARY_GOODS = 10
}

const NAMES: Dictionary = {
	Type.AGRICULTURE: "Agriculture",
	Type.RUBBER: "Rubber",
	Type.TIMBER: "Timber",
	Type.PETROLEUM: "Petroleum",
	Type.COAL: "Coal",
	Type.METAL_ORE: "Metal Ore",
	Type.URANIUM: "Uranium",
	Type.ELECTRIC_POWER: "Electric Power",
	Type.CONSUMER_GOODS: "Consumer Goods",
	Type.INDUSTRY_GOODS: "Industry Goods",
	Type.MILITARY_GOODS: "Military Goods"
}

const CATEGORIES: Dictionary = {
	Type.AGRICULTURE: "raw",
	Type.RUBBER: "raw",
	Type.TIMBER: "raw",
	Type.PETROLEUM: "raw",
	Type.COAL: "raw",
	Type.METAL_ORE: "raw",
	Type.URANIUM: "raw",
	Type.ELECTRIC_POWER: "processed",
	Type.CONSUMER_GOODS: "processed",
	Type.INDUSTRY_GOODS: "processed",
	Type.MILITARY_GOODS: "processed"
}

const COLORS: Dictionary = {
	Type.AGRICULTURE: Color("#8bc34a"),
	Type.RUBBER: Color("#4a4a4a"),
	Type.TIMBER: Color("#5d4037"),
	Type.PETROLEUM: Color("#212121"),
	Type.COAL: Color("#37474f"),
	Type.METAL_ORE: Color("#9e9e9e"),
	Type.URANIUM: Color("#76ff03"),
	Type.ELECTRIC_POWER: Color("#ffeb3b"),
	Type.CONSUMER_GOODS: Color("#ff9800"),
	Type.INDUSTRY_GOODS: Color("#2196f3"),
	Type.MILITARY_GOODS: Color("#f44336")
}

const ICONS: Dictionary = {
	Type.AGRICULTURE: "A",
	Type.RUBBER: "R",
	Type.TIMBER: "W",
	Type.PETROLEUM: "P",
	Type.COAL: "C",
	Type.METAL_ORE: "M",
	Type.URANIUM: "U",
	Type.ELECTRIC_POWER: "E",
	Type.CONSUMER_GOODS: "G",
	Type.INDUSTRY_GOODS: "I",
	Type.MILITARY_GOODS: "S"
}

# Production chain inputs: resource -> {input_resource: amount_per_unit}
const RECIPES: Dictionary = {
	Type.AGRICULTURE: { Type.ELECTRIC_POWER: 2.0 },
	Type.RUBBER: { Type.PETROLEUM: 14.0, Type.ELECTRIC_POWER: 5.0 },
	Type.TIMBER: {},
	Type.PETROLEUM: { Type.AGRICULTURE: 0.2, Type.COAL: 1.7, Type.ELECTRIC_POWER: 0.9 },
	Type.COAL: {},
	Type.METAL_ORE: { Type.PETROLEUM: 2.0, Type.ELECTRIC_POWER: 1.0 },
	Type.URANIUM: {},
	Type.ELECTRIC_POWER: { Type.PETROLEUM: 1.786, Type.COAL: 6.6, Type.URANIUM: 0.026 },
	Type.CONSUMER_GOODS: { Type.RUBBER: 0.1, Type.PETROLEUM: 10.0, Type.METAL_ORE: 3.5, Type.ELECTRIC_POWER: 10.0, Type.INDUSTRY_GOODS: 0.25 },
	Type.INDUSTRY_GOODS: { Type.RUBBER: 0.05, Type.PETROLEUM: 30.0, Type.COAL: 5.0, Type.METAL_ORE: 14.8, Type.ELECTRIC_POWER: 38.0 },
	Type.MILITARY_GOODS: { Type.RUBBER: 0.1, Type.PETROLEUM: 75.0, Type.METAL_ORE: 39.5, Type.ELECTRIC_POWER: 100.0, Type.INDUSTRY_GOODS: 0.5 }
}

static func is_raw(resource_type: int) -> bool:
	return CATEGORIES.get(resource_type, "raw") == "raw"

static func res_name(resource_type: int) -> String:
	return NAMES.get(resource_type, "Unknown")

static func get_color(resource_type: int) -> Color:
	return COLORS.get(resource_type, Color.WHITE)

static func get_icon(resource_type: int) -> String:
	return ICONS.get(resource_type, "?")

static func get_recipe(resource_type: int) -> Dictionary:
	return RECIPES.get(resource_type, {})