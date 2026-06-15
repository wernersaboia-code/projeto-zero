extends CanvasLayer
class_name MainHUD

const ResourceData = preload("res://scripts/economy/ResourceData.gd")

@onready var _top_bar: Panel = $TopBar
@onready var _nation_label: Label = $TopBar/NationLabel
@onready var _treasury_label: Label = $TopBar/TreasuryLabel
@onready var _date_label: Label = $TopBar/DateLabel
@onready var _info_panel: Panel = $InfoPanel
@onready var _info_title: Label = $InfoPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var _info_subtitle: Label = $InfoPanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var _info_body: Label = $InfoPanel/MarginContainer/VBoxContainer/InfoLabel
@onready var _resources_btn: Button = $TopBar/ResourcesBtn
@onready var _resource_ledger: Panel = $ResourceLedger


func _ready() -> void:
	EventBus.hex_clicked.connect(_on_hex_clicked)
	EventBus.hex_hovered.connect(_on_hex_hovered)
	EventBus.game_tick.connect(_on_game_tick)
	_resources_btn.pressed.connect(_toggle_resource_ledger)
	_info_panel.hide()


func _toggle_resource_ledger() -> void:
	_resource_ledger.visible = not _resource_ledger.visible


func _on_game_tick(_tick: int) -> void:
	var hex_grid = get_tree().get_first_node_in_group("hex_grid") as HexGrid
	if not hex_grid or hex_grid.nations.is_empty():
		return
	# Update treasury display for player nation (first nation for now)
	var nation = hex_grid.nations.values()[0]
	_treasury_label.text = "$ %,.0f" % nation.treasury

	var parts: Array[String] = []
	for res_type in range(ResourceData.Type.MILITARY_GOODS + 1):
		var bal = nation.get_resource_balance(res_type)
		if bal != 0.0:
			var icon = ResourceData.get_icon(res_type)
			parts.append("%s%+.1f" % [icon, bal])
	if not parts.is_empty():
		_treasury_label.text += "  |  " + " ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _info_panel.visible:
			_info_panel.hide()
			get_viewport().set_input_as_handled()
		if _resource_ledger.visible:
			_resource_ledger.hide()
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

	var rtype = data.get("resource_type", -1)
	if rtype >= 0:
		var ramount = data.get("resource_amount", 0)
		var rname = ResourceData.get_name(rtype)
		var rcolor = ResourceData.get_color(rtype)
		lines.append("Resource: [color=#" + rcolor.to_html(false) + "]" + rname + "[/color] (%d)" % ramount)

	_info_body.text = "\n".join(lines)

	_resource_ledger.hide()


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

		var rtype = data.get("resource_type", -1)
		if rtype >= 0:
			var ramount = data.get("resource_amount", 0)
			lines.append(ResourceData.get_icon(rtype) + " " + ResourceData.get_name(rtype))

		_info_subtitle.text = " | ".join(lines)
