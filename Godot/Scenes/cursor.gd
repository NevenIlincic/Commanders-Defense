extends CanvasLayer

@onready var cursor_container: Node2D = $Cursor_Container

@onready var sight_cursor: Node2D = $Cursor_Container/Sight_Cursor
@onready var left_part: Sprite2D = $Cursor_Container/Sight_Cursor/Left_Part
@onready var right_part: Sprite2D = $Cursor_Container/Sight_Cursor/Right_Part
@onready var top_part: Sprite2D = $Cursor_Container/Sight_Cursor/Top_Part
@onready var bottom_part: Sprite2D = $Cursor_Container/Sight_Cursor/Bottom_Part

@onready var regular_cursor: Node2D = $Cursor_Container/Regular_Cursor
@onready var pointer_cursor: Node2D = $Cursor_Container/Pointer_Cursor

var current_tween_scale: float = 1
var left_part_original_scene_position: Vector2
var right_part_original_scene_position: Vector2
var top_part_original_scene_position: Vector2
var bottom_part_original_scene_position: Vector2
var back_amount: float = 0.05
var alpha_scale: float = 0.01

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	left_part_original_scene_position = left_part.position
	right_part_original_scene_position = right_part.position
	top_part_original_scene_position = top_part.position
	bottom_part_original_scene_position = bottom_part.position
	set_regular_cursor_visible()

func _process(delta: float) -> void:
	cursor_container.global_position = get_viewport().get_mouse_position()
	if sight_cursor.visible:
		left_part.position = lerp(left_part.position, left_part_original_scene_position, back_amount)
		right_part.position = lerp(right_part.position, right_part_original_scene_position, back_amount)
		top_part.position = lerp(top_part.position, top_part_original_scene_position, back_amount)
		bottom_part.position = lerp(bottom_part.position, bottom_part_original_scene_position, back_amount)


func make_cursor_tween(amount: float):
	var lerp_amount = 20
	left_part.position = lerp(left_part.position, Vector2(left_part.position.x - lerp_amount, left_part.position.y), amount)
	right_part.position = lerp(right_part.position, Vector2(right_part.position.x + lerp_amount, right_part.position.y), amount)
	top_part.position = lerp(top_part.position, Vector2(top_part.position.x, top_part.position.y - lerp_amount), amount)
	bottom_part.position = lerp(bottom_part.position, Vector2(bottom_part.position.x, bottom_part.position.y + lerp_amount), amount)

func set_regular_cursor_visible():
	regular_cursor.visible = true
	pointer_cursor.visible = false
	sight_cursor.visible = false

func set_sight_cursor_visible():
	sight_cursor.visible = true
	regular_cursor.visible = false
	pointer_cursor.visible = false

func set_pointer_cursor_visible():
	pointer_cursor.visible = true
	regular_cursor.visible = false
	sight_cursor.visible = false
	
