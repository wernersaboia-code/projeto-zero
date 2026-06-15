extends Panel
class_name ResourceLedger

const R = preload("res://scripts/economy/ResourceData.gd")

var _nation = null
var _header_labels: Array = []
var _rows: Dictionary = {}  # res_type -> Array[Label]


func _ready() -> void:
	add_to_group("resource_ledger")
	EventBus.game_tick.connect(_on_game_tick)
	_build_ui()


func set_player_nation(nation) -> void:
	_nation = nation
	_update_display()


func _build_ui() -> void:
	var mc = MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_top", 8)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_bottom", 8)
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(mc)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(vb)

	var title = Label.new()
	title.text = "RESOURCE LEDGER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	vb.add_child(title)

	var sep = HSeparator.new()
	vb.add_child(sep)

	# Header row
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(header)

	var header_names = ["", "Resource", "Stock", "Production", "Consumption", "Balance"]
	var header_widths = [20, 130, 60, 70, 70, 70]
	for i in range(header_names.size()):
		var lbl = Label.new()
		lbl.text = header_names[i]
		lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(header_widths[i], 20)
		header.add_child(lbl)

	# Resource rows
	for res_type in range(R.Type.MILITARY_GOODS + 1):
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(row)

		var icon_lbl = Label.new()
		icon_lbl.text = R.get_icon(res_type)
		icon_lbl.add_theme_color_override("font_color", R.get_color(res_type))
		icon_lbl.custom_minimum_size = Vector2(20, 20)
		row.add_child(icon_lbl)

		var name_lbl = Label.new()
		name_lbl.text = R.res_name(res_type)
		name_lbl.custom_minimum_size = Vector2(130, 20)
		row.add_child(name_lbl)

		var row_labels: Array[Label] = []
		for v in 4:
			var lbl = Label.new()
			lbl.text = "0"
			lbl.custom_minimum_size = Vector2(60, 20)
			row.add_child(lbl)
			row_labels.append(lbl)

		_rows[res_type] = row_labels

	_update_display()


func _on_game_tick(_tick: int) -> void:
	if not _nation:
		return
	_update_display()


func _update_display() -> void:
	if not _nation:
		return
	for res_type in range(R.Type.MILITARY_GOODS + 1):
		if not _rows.has(res_type):
			continue
		var labels = _rows[res_type]
		var stock = _nation.get_resource_stock(res_type)
		var prod = _nation.resource_production.get(res_type, 0.0)
		var cons = _nation.resource_consumption.get(res_type, 0.0)
		var bal = prod - cons

		labels[0].text = _fmt(stock, true)
		labels[1].text = _fmt(prod)
		labels[2].text = _fmt(cons)
		labels[3].text = _fmt(bal)

		var bal_color = Color(0.6, 1.0, 0.4) if bal >= 0 else Color(1.0, 0.4, 0.4)
		labels[3].add_theme_color_override("font_color", bal_color)


static func _fmt(val: float, is_stock: bool = false) -> String:
	if is_stock:
		if val >= 1000:
			return "%d" % floor(val)
		return "%.1f" % val
	if abs(val) >= 1000:
		return "%+d" % floor(val)
	return "%+.1f" % val