extends PanelContainer
class_name ScoreboardRow

@onready var player_skin: TextureRect = $HBoxContainer/Player_Skin
@onready var player_name_label: Label = $HBoxContainer/Player_Name_Label
@onready var player_kills_label: Label = $HBoxContainer/Player_Kills_Label

var player_id: int
var player_kill_amount: int

func setup(player_id: int, player_name: String, player_skin_index: int, player_score: int):
	player_id = player_id
	player_skin.texture = LevelManager.players_kill_image_skin[player_skin_index]
	player_name_label.text = player_name
	player_kill_amount = player_score
	player_kills_label.text = str(player_kill_amount)
	
	if player_id == Network.my_id:
		var new_style = get_theme_stylebox("panel").duplicate()
		new_style.border_color = Color.GREEN
		new_style.set_border_width_all(1) 
		add_theme_stylebox_override("panel", new_style)

func update_kill_amount(player_new_kill_amount: int):
	player_kill_amount = player_new_kill_amount
	player_kills_label.text = str(player_kill_amount)
