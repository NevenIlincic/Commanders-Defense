extends Node2D

@onready var create_lobby_button: Button = $Lobbies_Menu_Elements/Create_Lobby_Button
@onready var v_box_container: VBoxContainer = $Lobbies_Menu_Elements/ScrollContainer/VBoxContainer
@onready var lobbies_menu_elements: Node2D = $Lobbies_Menu_Elements
@onready var create_lobby_node: Node2D = $Create_Lobby_Node

const LOBBY_ENTRY_SCENE = preload("res://Scenes/Lobby/Lobby_Row.tscn")

func _ready() -> void:
	Signals.UPDATE_LOBBIES_MENU_UI.connect(update_lobbies_ui)
	Signals.SET_LOBBIES_MENU_VISIBLE.connect(set_lobbies_menu_visible)
	MyHttpHandler.get_all_lobies()
	

func set_lobbies_menu_visible():
	lobbies_menu_elements.visible = true
	create_lobby_node.visible = false

func _on_create_lobby_button_pressed() -> void:
	lobbies_menu_elements.visible = false
	create_lobby_node.visible = true
	#MyHttpHandler.create_lobby_binary()
	
func update_lobbies_ui(lobbies_info: Array): #Array[Dictionary]
	for single_row in v_box_container.get_children():
		single_row.queue_free()
	
	for lobby_info in lobbies_info:
		var entry: LobbyEntry = LOBBY_ENTRY_SCENE.instantiate()
		entry.LOBBY_ID = lobby_info["lobby_id"]
		
		entry.get_node("Background/Host_Label").text = lobby_info["host_nickname"]
		if lobby_info["is_started"]:
			entry.get_node("Background/Started_Label").text = "STARTED"
		else:
			entry.get_node("Background/Started_Label").text = "AVAILABLE"
		
		entry.get_node("Background/Players_Count_Label").text = str(lobby_info["current_players"],"/",lobby_info["max_players"])
		
		v_box_container.add_child(entry)


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
