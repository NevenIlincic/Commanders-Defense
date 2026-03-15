extends PanelContainer
class_name LobbyEntry

@onready var host_label: Label = $VBoxContainer/Background/Host_Label
@onready var started_label: Label = $VBoxContainer/Background/Started_Label
@onready var players_count_label: Label = $VBoxContainer/Background/Players_Count_Label
@onready var texture_rect: TextureRect = $VBoxContainer/Background/TextureRect
@onready var password_input: LineEdit = $VBoxContainer/Password_Input

var LOBBY_ID: int = 0
var hover_color: Color = Color("304546")
var normal_color: Color = Color("464d46")
var lobby_info: Dictionary = {}
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	password_input.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(lobby_row_info: Dictionary):
	LOBBY_ID = lobby_row_info["lobby_id"]	
	host_label.text = lobby_row_info["host_nickname"]
	if lobby_row_info["is_started"]:
		started_label.text = "STARTED"
	else:
		started_label.text = "AVAILABLE"
	players_count_label.text = str(lobby_row_info["current_players"],"/",lobby_row_info["max_players"])
	
	if lobby_row_info["has_password"]:
		texture_rect.texture = load("res://Sprites/lobby/lock_locked.png")
	else:
		texture_rect.texture = load("res://Sprites/lobby/lock_unlocked.png")

	lobby_info = lobby_row_info
	
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not lobby_info["has_password"]:
				Network.current_lobby_id = LOBBY_ID
				MyHttpHandler.join_lobby_binary("")
			else:
				password_input.visible = !password_input.visible
				if password_input.visible:
					await get_tree().process_frame
					password_input.grab_focus()
					password_input.edit()


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


func _on_password_input_text_submitted(new_text: String) -> void:
	if new_text != "":
		Network.current_lobby_id = LOBBY_ID
		MyHttpHandler.join_lobby_binary(new_text)
		password_input.clear()
