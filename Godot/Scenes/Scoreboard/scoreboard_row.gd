extends PanelContainer
class_name ScoreboardRow

@onready var player_skin: TextureRect = $HBoxContainer/Player_Skin
@onready var player_name_label: Label = $HBoxContainer/Player_Name_Label
@onready var player_kills_label: Label = $HBoxContainer/Player_Kills_Label

var player_id: int
var player_kill_amount: int

func setup(player_id: int, player_name: String, player_skin_index: int):
	player_id = player_id
	player_skin.texture = LevelManager.players_kill_image_skin[player_skin_index]
	player_name_label.text = player_name
	player_kill_amount = 0
	player_kills_label.text = str(player_kill_amount)

func update_kill_amount(player_new_kill_amount: int):
	player_kill_amount = player_new_kill_amount
	player_kills_label.text = str(player_kill_amount)
