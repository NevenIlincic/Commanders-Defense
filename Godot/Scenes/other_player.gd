extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	if global_position.distance_to(target_position) < 2:
		global_position = global_position.lerp(target_position, 20.0 * delta)
	else:
		global_position = target_position
	#if global_position.distance_to(target_position) > 0.1:
		#global_position = target_position
	#else:
		#global_position = global_position.lerp(target_position, 20.0 * delta)

func handle_server_response(player_snapshot: Dictionary):
	target_position = Vector2(player_snapshot["position"][0] * 32, global_position.y)
