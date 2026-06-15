extends CanvasLayer
class_name NationSelectScreen

var _nations: Dictionary = {}
var _row_nodes: Dictionary = {}
var _list_container: VBoxContainer


func _ready() -> void:
	_build_ui()


func set_nations(nations: Dictionary) -> void:
	_nations = nations
	_populate_list()


func _build_ui() -> void:
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.04, 0.08, 0.97)))
	add_child(panel)

	var mc = MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 60)
	mc.add_theme_constant_override("margin_top", 40)
	mc.add_theme_constant_override("margin_right", 60)
	mc.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(mc)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_child(vb)

	var title = Label.new()
	title.text = "SELECT YOUR NATION"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Click a nation to begin"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(subtitle)

	vb.add_child(HSeparator.new())

	var filter_hb = HBoxContainer.new()
	vb.add_child(filter_hb)

	var filter_label = Label.new()
	filter_label.text = "Filter: "
	filter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	filter_hb.add_child(filter_label)

	var filter_input = LineEdit.new()
	filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_input.placeholder_text = "Type nation name..."
	filter_input.text_changed.connect(_on_filter_changed)
	filter_hb.add_child(filter_input)

	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list_container)


func _make_style(bg: Color):
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	return sb


func _populate_list(filter: String = "") -> void:
	var container = _list_container
	if not container:
		return

	for child in container.get_children():
		child.queue_free()
	_row_nodes.clear()

	var sorted = _nations.values()
	sorted.sort_custom(func(a, b): return a.name < b.name)

	var f = filter.to_lower().strip_edges()

	for nation in sorted:
		if f != "" and f not in nation.name.to_lower():
			continue

		var hb = HBoxContainer.new()
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(hb)

		var color_rect = ColorRect.new()
		color_rect.color = nation.color
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.size = Vector2(16, 16)
		hb.add_child(color_rect)

		hb.add_spacer(false)

		var lbl = Label.new()
		lbl.text = nation.name
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lbl)

		var btn = Button.new()
		btn.text = "Select"
		btn.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		btn.pressed.connect(_on_nation_selected.bind(nation.id))
		hb.add_child(btn)

		_row_nodes[nation.id] = btn


func _on_filter_changed(new_text: String) -> void:
	_populate_list(new_text)


func _on_nation_selected(nation_id: int) -> void:
	var gm = get_tree().root.get_node("GameManager") as GameManager
	if gm:
		gm.player_nation_id = nation_id
	queue_free()