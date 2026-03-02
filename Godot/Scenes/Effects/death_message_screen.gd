extends Node2D
class_name DeathMessageScreen

@onready var killer_sprite: Sprite2D = $Killer_Sprite
@onready var death_message_label: Label = $Death_Message_Label
@onready var respawn_time_label: Label = $Respawn_Time_Label

var time_to_respawn: float 
func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	time_to_respawn -= delta
	var formatted_time_to_respawn = "%.1f" % time_to_respawn
	respawn_time_label.text = str("Respawning in: ", formatted_time_to_respawn, " seconds")
	

func setup(killer: Sprite2D, killer_name: String, timer_till_respawn: float) -> void: # Staviti String
	killer_sprite.texture = killer.texture
	death_message_label.text = str("Killed By: ", killer_name)
	time_to_respawn = timer_till_respawn

func remove_from_parent_scene():
	self.queue_free()
