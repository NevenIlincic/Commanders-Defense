extends PanelContainer
class_name LobbyPlayerInfo

@onready var left_button: TextureButton = $HBoxContainer/Player_Ready_Frame/Left_Button
@onready var right_button: TextureButton = $HBoxContainer/Player_Ready_Frame/Right_Button

@onready var player_nickname_label: Label = $HBoxContainer/Player_Nickname_Label
@onready var player_ready_frame: TextureRect = $HBoxContainer/Player_Ready_Frame
@onready var crown_texture: TextureRect = $HBoxContainer/Player_Ready_Frame/Crown_Texture
@onready var ready_button: Button = $HBoxContainer/Ready_Button


var player_id: int = 0

var skins: Dictionary = {
	0: preload("res://Sprites/player/green_player_lobby.png"),
	1: preload("res://Sprites/player/blue_player_lobby.png")
}

var ready_frames: Dictionary = {
	"not_ready": preload("res://Sprites/lobby/player_not_ready_frame.png"),
	"ready": preload("res://Sprites/lobby/player_ready_frame.png")
}
var skin_index: int = 0

func _ready() -> void:
	if Network.my_id != player_id:
		left_button.visible = false
		right_button.visible = false
		ready_button.visible = false


func _process(delta: float) -> void:
	pass

func handle_server_response(player_info_snapshot: Dictionary):
	player_id = player_info_snapshot["player_id"]
	player_nickname_label.text = player_info_snapshot["nickname"]
	if player_info_snapshot["is_ready"]:
		player_ready_frame.texture = ready_frames["ready"]
	else:
		player_ready_frame.texture = ready_frames["not_ready"]
	
	crown_texture.visible = player_info_snapshot["is_host"]


func _on_ready_button_pressed() -> void:
	MyHttpHandler.change_is_player_ready()


func _on_left_button_pressed() -> void:
	print("Kliknuo levo!")


func _on_right_button_pressed() -> void:
	print("Kliknuo desno!")
