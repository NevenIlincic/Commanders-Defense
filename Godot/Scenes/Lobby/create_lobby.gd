extends Node2D


func _on_close_button_pressed() -> void:
	Signals.SET_LOBBIES_MENU_VISIBLE.emit()


func _on_create_button_pressed() -> void:
	MyHttpHandler.create_lobby_binary()
