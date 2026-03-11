extends CanvasLayer

@onready var container: Node2D = $Container
@onready var left_part: Sprite2D = $Container/Left_Part
@onready var right_part: Sprite2D = $Container/Right_Part
@onready var top_part: Sprite2D = $Container/Top_Part
@onready var bottom_part: Sprite2D = $Container/Bottom_Part

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

func _process(delta: float) -> void:
	container.global_position = get_viewport().get_mouse_position()
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
