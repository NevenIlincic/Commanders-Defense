extends Node2D

@onready var password_input: LineEdit = $Lobby_Password/Password_Input
@onready var max_players_option_button: MaxPlayersOptionButton = $Max_Players/Max_Players_Option_Button
@onready var game_modes_label: Label = $Game_Modes/Game_Modes_Label
@onready var game_modes_option_button: OptionButton = $Game_Modes/Game_Modes_Option_Button


func _on_close_button_pressed() -> void:
	Signals.SET_LOBBIES_MENU_VISIBLE.emit()

func _on_create_button_pressed() -> void:
	#MAX PLAYERS
	var selected_max_players_item_index: int = max_players_option_button.get_selected()
	var selected_max_players: int = int(max_players_option_button.get_item_text(selected_max_players_item_index))
	#GAME MODE
	var selected_game_mode_index: int = game_modes_option_button.get_selected()
	
	if selected_game_mode_index == 0:
		LevelManager.CURRENT_LEVEL_GAME_MODE = "TOWERS"
	elif selected_game_mode_index == 1:
		LevelManager.CURRENT_LEVEL_GAME_MODE = "FFA"
		
	MyHttpHandler.create_lobby_binary(selected_max_players, password_input.text, selected_game_mode_index)

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

func _on_password_input_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
	
func _on_password_input_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_create_touch_screen_pressed() -> void:
	_on_create_button_pressed()


func _on_close_touch_screen_pressed() -> void:
	_on_close_button_pressed()


func _on_password_input_touch_screen_pressed() -> void:
	password_input.grab_focus()


func _on_lose_focus_touch_screen_pressed() -> void:
	password_input.release_focus()
	game_modes_option_button.get_popup().hide()


func _on_game_modes_option_touch_screen_pressed() -> void:
	game_modes_option_button.show_popup()


func _on_max_players_option_touch_screen_pressed() -> void:
	max_players_option_button.show_popup()
