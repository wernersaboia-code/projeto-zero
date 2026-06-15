extends Control
class_name DebugOverlay

@onready var _label: Label = $Label


func _ready() -> void:
	EventBus.hex_hovered.connect(_on_hex_hovered)
	EventBus.hex_clicked.connect(_on_hex_clicked)
	EventBus.grid_status.connect(_on_grid_status)
	_set_text("Aguardando geracao...")


func _on_grid_status(cells: int, provinces: int, nations: int) -> void:
	_set_text("Grid: %d hexes | %d provinces | %d nations" % [cells, provinces, nations])


func _on_hex_hovered(data: Dictionary) -> void:
	var msg = "HOVER: %s | %s | Prov:%s | (%d,%d)" % [
		data.get("terrain_name", "?"),
		data.get("nation_name", "wild"),
		data.get("province_name", "none"),
		data.get("offset", Vector2i.ZERO).x,
		data.get("offset", Vector2i.ZERO).y
	]
	_set_text(msg)


func _on_hex_clicked(data: Dictionary) -> void:
	var msg = "CLICK: %s | Nation: %s | Province: %s" % [
		data.get("terrain_name", "?"),
		data.get("nation_name", "none"),
		data.get("province_name", "none")
	]
	_set_text(msg)


func _set_text(msg: String) -> void:
	_label.text = msg
