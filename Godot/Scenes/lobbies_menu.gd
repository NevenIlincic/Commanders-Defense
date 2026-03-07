extends Node2D

@onready var create_lobby_button: Button = $Create_Lobby_Button
@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer
const LOBBY_ENTRY_SCENE = preload("res://Scenes/Lobby/Lobby_Row.tscn")

func _ready() -> void:
	Signals.UPDATE_LOBBY_UI.connect(update_lobbies_ui)
	MyHttpHandler.get_all_lobies()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_create_lobby_button_pressed() -> void:
	MyHttpHandler.create_lobby_binary()
	
func update_lobbies_ui(lobbies_info: Array): #Array[Dictionary]
	for single_row in v_box_container.get_children():
		single_row.queue_free()
	
	for lobby_info in lobbies_info:
		var entry = LOBBY_ENTRY_SCENE.instantiate()
		
		entry.get_node("Background/Host_Label").text = lobby_info["host_nickname"]
		if lobby_info["is_started"]:
			entry.get_node("Background/Started_Label").text = "STARTED"
		else:
			entry.get_node("Background/Started_Label").text = "AVAILABLE"
		
		entry.get_node("Background/Players_Count_Label").text = str(lobby_info["current_players"],"/",lobby_info["max_players"])
		# 3. Dodaj ga u VBoxContainer
		v_box_container.add_child(entry)
