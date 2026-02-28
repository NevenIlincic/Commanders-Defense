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
	

func setup(player_won: Node2D, winner_id) -> void:
	winner_sprite = player_won.find_child("kill_image")
	if Network.my_id == winner_id:
		winner_label.text = str(Network.my_nickname, " WON!")
	else:
		winner_label.text = str(player_won.NICKNAME, " WON!")
	#time_to_respawn = timer_till_respawn

func remove_from_parent_scene():
	self.queue_free()
