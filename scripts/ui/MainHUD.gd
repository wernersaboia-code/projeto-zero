extends CanvasLayer
class_name MainHUD

const R = preload("res://scripts/economy/ResourceData.gd")

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
@onready var _pause_btn: Button = $TopBar/SpeedContainer/PauseBtn
@onready var _speed_1x: Button = $TopBar/SpeedContainer/Speed1xBtn
@onready var _speed_2x: Button = $TopBar/SpeedContainer/Speed2xBtn
@onready var _speed_5x: Button = $TopBar/SpeedContainer/Speed5xBtn

var _player_nation = null


func _ready() -> void:
	add_to_group("hud")
	EventBus.hex_clicked.connect(_on_hex_clicked)
	EventBus.hex_hovered.connect(_on_hex_hovered)
	EventBus.game_tick.connect(_on_game_tick)
	_resources_btn.pressed.connect(_toggle_resource_ledger)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_speed_1x.pressed.connect(_on_speed_pressed.bind(1.0))
	_speed_2x.pressed.connect(_on_speed_pressed.bind(2.0))
	_speed_5x.pressed.connect(_on_speed_pressed.bind(5.0))
	_info_panel.hide()


func _on_pause_pressed() -> void:
	var gm = get_tree().root.get_node("GameManager")
	if gm:
		gm.toggle_pause()
		_pause_btn.text = ">" if gm.is_paused else "||"


func _on_speed_pressed(speed: float) -> void:
	var gm = get_tree().root.get_node("GameManager")
	if gm:
		gm.set_speed(speed)
		if gm.is_paused:
			gm.is_paused = false
			_pause_btn.text = "||"


static func _fmt_treasury(val: float) -> String:
	if val >= 1_000_000_000_000:
		return "%.2fT" % (val / 1_000_000_000_000)
	elif val >= 1_000_000_000:
		return "%.2fB" % (val / 1_000_000_000)
	elif val >= 1_000_000:
		return "%.2fM" % (val / 1_000_000)
	elif val >= 1_000:
		return "%.2fK" % (val / 1_000)
	else:
		return "%.0f" % val


func _toggle_resource_ledger() -> void:
	_resource_ledger.visible = not _resource_ledger.visible


func set_player_nation(nation_id: int) -> void:
	var hex_grid = get_tree().get_first_node_in_group("hex_grid")
	if hex_grid and hex_grid.nations.has(nation_id):
		_player_nation = hex_grid.nations[nation_id]
		_nation_label.text = _player_nation.name
		_update_display()


func _on_game_tick(_tick: int) -> void:
	_update_display()


func _update_display() -> void:
	var gm = get_tree().root.get_node("GameManager")
	if gm:
		_date_label.text = "%04d.%02d.%02d" % [gm.game_year, gm.game_month, gm.game_day]

	if not _player_nation:
		return
	_treasury_label.text = "$ " + _fmt_treasury(_player_nation.treasury)

	var parts: Array[String] = []
	for res_type in range(R.Type.MILITARY_GOODS + 1):
		var bal = _player_nation.get_resource_balance(res_type)
		if bal != 0.0:
			var icon = R.get_icon(res_type)
			parts.append("%s%+.1f" % [icon, bal])
	if not parts.is_empty():
		_treasury_label.text += "  |  " + " ".join(parts)

	var trade = _player_nation.trade_balance
	if abs(trade) > 0.1:
		var sign = "+" if trade >= 0 else ""
		_treasury_label.text += "  |  Trade: " + sign + _fmt_treasury(trade)


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
		var rname = R.res_name(rtype)
		var rcolor = R.get_color(rtype)
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
			lines.append(R.get_icon(rtype) + " " + R.res_name(rtype))

		_info_subtitle.text = " | ".join(lines)
