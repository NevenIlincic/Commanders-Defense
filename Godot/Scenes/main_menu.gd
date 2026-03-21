extends Node2D

@onready var start_button: TextureButton = $Main_Menu_Elements/Start_Button
@onready var quit_button: TextureButton = $Main_Menu_Elements/Quit_Button
@onready var nickname_input: LineEdit = $Main_Menu_Elements/Nickname_Input
@onready var main_menu_password_input: LineEdit = $Main_Menu_Elements/Main_Menu_Password_Input

#MAIN MENU ELEMENTS
@onready var main_menu_elements: Node2D = $Main_Menu_Elements

#REGISTER MENU ELEMENTS
@onready var register_menu_elements: Node2D = $Register_Menu_Elements
@onready var register_nickname_input: LineEdit = $Register_Menu_Elements/Register_Nickname_Input
@onready var register_password_input: LineEdit = $Register_Menu_Elements/Register_Password_Input
@onready var register_confirm_password_input: LineEdit = $Register_Menu_Elements/Register_Confirm_Password_Input

#MUSIC BUTTON
@onready var music_button: TextureButton = $Music_Button
@onready var music_button_muted: TextureButton = $Music_Button_Muted


@onready var hover_click_sound: AudioStreamPlayer2D = $"Hover-Click_Sound"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Signals.CHANGE_TO_SCENE_SIGNAL.connect(change_scene)
	SoundHandler.play_background_music(SoundHandler.TI_SE_SAMO_USUDI)
	show_main_menu_elements()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	var entered_nickname: String = nickname_input.text
	var entered_password: String = main_menu_password_input.text
	if entered_nickname != "" and entered_password!= "":
		hover_click_sound.play()
		MyHttpHandler.login(entered_nickname, entered_password)
				

func show_main_menu_elements():
	main_menu_elements.visible = true
	register_menu_elements.visible = false
func show_register_menu_elements():
	register_menu_elements.visible = true
	main_menu_elements.visible = false

func _on_start_button_mouse_entered() -> void:
	hover_click_sound.play()
	CustomCursor.set_pointer_cursor_visible()


func _on_quit_button_mouse_entered() -> void:
	hover_click_sound.play()
	CustomCursor.set_pointer_cursor_visible()

func _on_quit_button_pressed() -> void:
	hover_click_sound.play()
	get_tree().quit()
	
func change_scene(scene_path: String):
	get_tree().change_scene_to_file(scene_path)

func _on_start_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_quit_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_nickname_input_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_nickname_input_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_main_menu_register_button_pressed() -> void:
	show_register_menu_elements()

func _on_register_menu_close_button_pressed() -> void:
	register_nickname_input.clear()
	register_password_input.clear()
	register_confirm_password_input.clear()
	show_main_menu_elements()
	
func _on_register_menu_register_button_pressed() -> void:
	var entered_nickname: String = register_nickname_input.text
	var entered_password: String = register_password_input.text
	var entered_confirm_password: String = register_confirm_password_input.text
	if (entered_nickname == "" or entered_password == ""
	 or entered_confirm_password == ""):
		return
	if entered_password != entered_confirm_password:
		return
	
	MyHttpHandler.register(register_nickname_input.text, register_password_input.text)


func _on_music_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
	hover_click_sound.play()

func _on_music_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_music_button_pressed() -> void:
	music_button.visible = false
	music_button_muted.visible = true
	var bus_index = AudioServer.get_bus_index("Background Music")	
	AudioServer.set_bus_mute(bus_index, true)
	hover_click_sound.play()

func _on_music_button_muted_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
	hover_click_sound.play()

func _on_music_button_muted_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()
	
func _on_music_button_muted_pressed() -> void:
	music_button.visible = true
	music_button_muted.visible = false
	var bus_index = AudioServer.get_bus_index("Background Music")	
	AudioServer.set_bus_mute(bus_index, false)
	hover_click_sound.play()

func _on_main_menu_register_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_main_menu_register_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_register_nickname_input_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_register_nickname_input_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_register_password_input_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_register_password_input_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_register_confirm_password_input_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_register_confirm_password_input_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_register_menu_register_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_register_menu_register_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_register_menu_close_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_register_menu_close_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()
