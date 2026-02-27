extends Node2D

@onready var start_button: TextureButton = $Start_Button
@onready var quit_button: TextureButton = $Quit_Button
@onready var nickname_input: LineEdit = $Nickname_Input

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	if nickname_input.text != "":
		Network.my_nickname = nickname_input.text
		get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
		
