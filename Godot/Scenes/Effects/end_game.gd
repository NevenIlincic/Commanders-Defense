extends Node2D
class_name GameEndMessageScreen

@onready var winner_sprite: Sprite2D = $Winner_Sprite
@onready var winner_label: Label = $Winner_Label
@onready var back_to_lobby_timer_label: Label = $Back_To_Lobby_Timer_Label

var time_to_respawn: float 
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	#time_to_respawn -= delta
	#var formatted_time_to_respawn = "%.1f" % time_to_respawn
	back_to_lobby_timer_label.text = str("Please wait...")
	

func setup(player_won: Node2D, winner_id, message) -> void:
	if message == null:
		if Network.my_id == winner_id:
			winner_sprite.texture = LevelManager.players_win_image_skin[Network.my_skin_id]
			winner_label.text = str(Network.my_nickname, " WON!")
		else:
			winner_sprite.texture = LevelManager.players_win_image_skin[player_won.SKIN_INDEX]
			winner_label.text = str(player_won.NICKNAME, " WON!")
	else:
		winner_sprite.visible = false
		winner_label.text = message
	#time_to_respawn = timer_till_respawn

func remove_from_parent_scene():
	self.queue_free()
