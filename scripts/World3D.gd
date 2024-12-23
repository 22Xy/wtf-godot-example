extends Node3D

var mouse_captured = true

func _ready():
	# Hide cursor when scene starts
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		# Show mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	elif event.is_action_pressed("attack") and not mouse_captured:  # Left click when cursor is visible
		# Hide mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true

func _on_InteractiveElement_interacted():
	# Handle interaction, maybe show a UI or change scene
	pass

func _exit_to_main_menu():
	# Transition to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	# No need for queue_free() if World3D is not the root
