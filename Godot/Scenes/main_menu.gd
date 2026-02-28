extends Node2D

@onready var start_button: TextureButton = $Start_Button
@onready var quit_button: TextureButton = $Quit_Button
@onready var nickname_input: LineEdit = $Nickname_Input
@onready var ip_address_input: LineEdit = $IP_Address_Input

@onready var hover_click_sound: AudioStreamPlayer2D = $"Hover-Click_Sound"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#SoundHandler.play_background_music(SoundHandler.TI_SE_SAMO_USUDI)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	if nickname_input.text != "" and ip_address_input.text != "":
		hover_click_sound.play()
		Network.my_nickname = nickname_input.text
		Network.server_address = ip_address_input.text.split(":")[0]
		Network.server_port = int(ip_address_input.text.split(":")[1])
		get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
		


func _on_start_button_mouse_entered() -> void:
	hover_click_sound.play()


func _on_quit_button_mouse_entered() -> void:
	hover_click_sound.play()


func _on_quit_button_pressed() -> void:
	hover_click_sound.play()
	get_tree().quit()
