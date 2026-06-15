extends Panel
class_name HexInfoPanel

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _info_label: Label = $MarginContainer/VBoxContainer/InfoLabel


func _ready() -> void:
	EventBus.hex_clicked.connect(_on_hex_clicked)
	hide()


func _on_hex_clicked(data: Dictionary) -> void:
	_title_label.text = data.get("terrain_name", "Unknown")

	var nation_name = data.get("nation_name", "")
	var province_name = data.get("province_name", "")

	if nation_name != "":
		_subtitle_label.text = nation_name
	elif province_name != "":
		_subtitle_label.text = province_name
	else:
		_subtitle_label.text = "Wilderness"

	var lines: Array[String] = []

	if province_name != "":
		var prov_hexes = data.get("province_hexes", 0)
		lines.append("Province: %s (%d hexes)" % [province_name, prov_hexes])
		if data.get("province_is_coastal", false):
			lines.append("  Coastal")

	if nation_name != "":
		lines.append("Nation: %s (ID: %d)" % [nation_name, data.get("owner_nation_id", -1)])
		if data.get("is_player", false):
			lines.append("  PLAYER NATION")

	var offset: Vector2i = data.get("offset", Vector2i.ZERO)
	var cube: Vector3 = data.get("cube", Vector3.ZERO)
	lines.append("Pos: (%d, %d)" % [offset.x, offset.y])
	lines.append("Elevation: %.2f" % data.get("elevation", 0.0))
	lines.append("Population: %d" % data.get("population", 0))

	_info_label.text = "\n".join(lines)
	show()


func _on_hex_unhovered() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		hide()
