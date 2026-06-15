extends CanvasLayer
class_name MainHUD

@onready var _top_bar: Panel = $TopBar
@onready var _nation_label: Label = $TopBar/NationLabel
@onready var _treasury_label: Label = $TopBar/TreasuryLabel
@onready var _date_label: Label = $TopBar/DateLabel
@onready var _info_panel: Panel = $InfoPanel
@onready var _info_title: Label = $InfoPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _info_subtitle: Label = $InfoPanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var _info_body: Label = $InfoPanel/MarginContainer/VBoxContainer/InfoLabel


func _ready() -> void:
	EventBus.hex_clicked.connect(_on_hex_clicked)
	EventBus.hex_hovered.connect(_on_hex_hovered)
	_info_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _info_panel.visible:
			_info_panel.hide()
			get_viewport().set_input_as_handled()


func _on_hex_clicked(data: Dictionary) -> void:
	_info_title.text = data.get("terrain_name", "--")
	_info_subtitle.text = ""
	_info_body.text = ""
	_info_panel.show()

	var lines: Array[String] = []
	lines.append("Coords: (%d, %d)" % [data.get("offset", Vector2i.ZERO).x, data.get("offset", Vector2i.ZERO).y])
	lines.append("Elevation: %.2f" % data.get("elevation", 0.0))

	var pname = data.get("province_name", "")
	if pname != "":
		lines.append("Province: %s" % pname)
		lines.append("Province hexes: %d" % data.get("province_hexes", 0))
		if data.get("province_is_coastal", false):
			lines.append("Coastal")

	var nname = data.get("nation_name", "")
	if nname != "":
		lines.append("Nation: %s" % nname)

	_info_body.text = "\n".join(lines)


func _on_hex_hovered(data: Dictionary) -> void:
	if _info_panel.visible:
		_info_title.text = data.get("terrain_name", "--")
		var lines: Array[String] = []
		lines.append("(%d, %d)" % [data.get("offset", Vector2i.ZERO).x, data.get("offset", Vector2i.ZERO).y])

		var pname = data.get("province_name", "")
		if pname != "":
			lines.append(pname)

		var nname = data.get("nation_name", "")
		if nname != "":
			lines.append(nname)

		_info_subtitle.text = " | ".join(lines)
