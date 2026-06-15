extends Node
class_name State

signal finished(next_state_name: StringName)

func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_input(_input_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func _on_animation_finished(_anim_name: String) -> void:
	pass
