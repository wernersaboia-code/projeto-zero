extends Control
class_name DialogueInterface

var dialogue_node: Node = null


func _ready() -> void:
	visible = false


func show_dialogue(dialogue: Node) -> void:
	visible = true
	$Button.grab_focus()
	dialogue_node = dialogue

	if dialogue_node.dialogue_started.is_connected(_on_dialogue_started):
		dialogue_node.start_dialogue()
		_update_text()
		return

	dialogue_node.dialogue_started.connect(_on_dialogue_started)
	dialogue_node.dialogue_finished.connect(_on_dialogue_finished)
	dialogue_node.dialogue_finished.connect(_on_dialogue_complete)
	dialogue_node.start_dialogue()
	_update_text()


func _update_text() -> void:
	$Name.text = "[center]" + dialogue_node.dialogue_name + "[/center]"
	$Text.text = dialogue_node.dialogue_text


func _on_Button_button_up() -> void:
	dialogue_node.next_dialogue()
	_update_text()


func _on_dialogue_started() -> void:
	pass


func _on_dialogue_finished() -> void:
	visible = false
	dialogue_node.dialogue_started.disconnect(_on_dialogue_started)
	dialogue_node.dialogue_finished.disconnect(_on_dialogue_finished)
	dialogue_node.dialogue_finished.disconnect(_on_dialogue_complete)


func _on_dialogue_complete() -> void:
	pass
