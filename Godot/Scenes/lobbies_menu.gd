extends Node2D

#LOBBIES MENU ELEMENTS
@onready var lobbies_menu_elements: Node2D = $Lobbies_Menu_Elements
@onready var create_lobby_button: Button = $Lobbies_Menu_Elements/Create_Lobby_Button
@onready var v_box_container: VBoxContainer = $Lobbies_Menu_Elements/ScrollContainer/VBoxContainer
@onready var welcome_label: Label = $Lobbies_Menu_Elements/Welcome_Label
@onready var num_logged_in_players_label: Label = $Lobbies_Menu_Elements/Num_Logged_In_Players_Label

#CREATE MENU ELEMENTS
@onready var create_lobby_node: Node2D = $Create_Lobby_Node

const LOBBY_ENTRY_SCENE = preload("res://Scenes/Lobby/Lobby_Row.tscn")

func _ready() -> void:
	Signals.UPDATE_LOBBIES_MENU_UI.connect(update_lobbies_ui)
	Signals.SET_LOBBIES_MENU_VISIBLE.connect(set_lobbies_menu_visible)
	MyHttpHandler.get_all_lobies()
	welcome_label.text = str("Welcome ", Network.my_nickname)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	CustomCursor.hide_cursor()
	

func set_lobbies_menu_visible():
	lobbies_menu_elements.visible = true
	create_lobby_node.visible = false

func _on_create_lobby_button_pressed() -> void:
	lobbies_menu_elements.visible = false
	create_lobby_node.visible = true
	#MyHttpHandler.create_lobby_binary()
	
func update_lobbies_ui(lobbies_menu_info_data: Dictionary): #{lobbies_info, num_logged_in_players}
	for single_row in v_box_container.get_children():
		single_row.queue_free()
	
	for lobby_info in lobbies_menu_info_data["lobbies_info"]:
		var entry: LobbyEntry = LOBBY_ENTRY_SCENE.instantiate()
		v_box_container.add_child(entry)
		entry.setup(lobby_info)
	
	num_logged_in_players_label.text = str("Current players: ", lobbies_menu_info_data["num_logged_in_players"])

func _on_refresh_lobbies_button_pressed() -> void:
	MyHttpHandler.get_all_lobies()

func _on_refresh_lobbies_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_refresh_lobbies_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_create_lobby_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_create_lobby_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_back_to_main_menu_button_pressed() -> void:
	MyHttpHandler.logout()

func _on_back_to_main_menu_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_back_to_main_menu_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_back_to_main_menu_touch_screen_pressed() -> void:
	_on_back_to_main_menu_button_pressed()


func _on_refresh_lobbies_touch_screen_pressed() -> void:
	_on_refresh_lobbies_button_pressed()


func _on_create_lobby_touch_screen_pressed() -> void:
	_on_create_lobby_button_pressed()
