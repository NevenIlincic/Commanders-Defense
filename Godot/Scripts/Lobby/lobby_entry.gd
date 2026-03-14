extends PanelContainer
class_name LobbyEntry


var LOBBY_ID: int = 0
var hover_color: Color = Color("304546")
var normal_color: Color = Color("464d46")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Network.current_lobby_id = LOBBY_ID
			MyHttpHandler.join_lobby_binary(LOBBY_ID, Network.my_nickname)


func _on_mouse_entered() -> void:
	var style_box = get_theme_stylebox("panel").duplicate()
	style_box.bg_color = hover_color
	add_theme_stylebox_override("panel", style_box)
	CustomCursor.set_pointer_cursor_visible()


func _on_mouse_exited() -> void:
	var style_box = get_theme_stylebox("panel").duplicate()
	style_box.bg_color = normal_color
	add_theme_stylebox_override("panel", style_box)
	CustomCursor.set_regular_cursor_visible()
