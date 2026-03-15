extends Node2D

@onready var password_input: LineEdit = $Lobby_Password/Password_Input

func _on_close_button_pressed() -> void:
	Signals.SET_LOBBIES_MENU_VISIBLE.emit()

func _on_create_button_pressed() -> void:
	MyHttpHandler.create_lobby_binary(password_input.text)

func _on_create_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_create_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_close_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_close_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_game_modes_option_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_game_modes_option_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_max_players_option_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_max_players_option_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()
