extends PanelContainer
class_name PlayerMessage

@onready var player_name_label: Label = $HBoxContainer/Player_Name_Label
@onready var player_message_label: Label = $HBoxContainer/Player_Message_Label

func setup(player_name: String, player_message: String):
	player_name_label.text = str(player_name, ":")
	player_message_label.text = player_message

func setup_connected_disconnected_message(player_name: String, is_connecting: bool):
	if is_connecting:
		player_name_label.text = player_name
		player_message_label.text = " has just joined the lobby!"
	else:
		player_name_label.text = player_name
		player_message_label.text = " has just left the lobby!"
	player_name_label.self_modulate.a = 0.5
	player_message_label.self_modulate.a = 0.5
