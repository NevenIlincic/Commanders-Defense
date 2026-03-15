extends Node2D
class_name PauseMenu

func _on_disconnect_button_pressed() -> void:
	MyHttpHandler.leave_lobby()

func show_hide_pause_menu():
	self.visible = !self.visible
