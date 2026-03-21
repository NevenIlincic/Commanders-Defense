extends Node2D
class_name PauseMenu

@onready var music_button: TextureButton = $Music_Button
@onready var music_button_muted: TextureButton = $Music_Button_Muted

@onready var hover_click_sound: AudioStreamPlayer2D = $"Hover-Click_Sound"

func _on_disconnect_button_pressed() -> void:
	MyHttpHandler.leave_lobby()

func show_hide_pause_menu():
	self.visible = !self.visible
	if self.visible:
		CustomCursor.set_regular_cursor_visible()
	else:
		CustomCursor.set_sight_cursor_visible()


func _on_music_button_muted_pressed() -> void:
	music_button.visible = true
	music_button_muted.visible = false
	var bus_index = AudioServer.get_bus_index("Background Music")	
	AudioServer.set_bus_mute(bus_index, false)


func _on_music_button_muted_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
	hover_click_sound.play()
func _on_music_button_muted_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


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


func _on_disconnect_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_disconnect_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()
