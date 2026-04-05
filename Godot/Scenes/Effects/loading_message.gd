extends Node2D
class_name LoadingMessage

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var message_label: Label = $HBoxContainer/Message_Label

var message_to_show: String
var should_show_animation: bool

func _ready() -> void:
	message_label.text = message_to_show
	if should_show_animation:
		animation_player.play("Dots_Animation")

func setup(message: String, show_animation: bool):
	message_to_show = message
	should_show_animation = show_animation
	
