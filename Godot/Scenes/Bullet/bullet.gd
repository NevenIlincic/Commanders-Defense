@abstract 
class_name PlayerBullet extends Node2D

var bullet_scene: PackedScene
var bullet_node: Node2D
var bullet_angle: float
var bullet_spawn_position: Marker2D
var SERVER_SPEED: float

const METER_TO_PIXEL = 32

func _ready() -> void:
	pass # Replace with function body.

func _init() -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	self.global_position += global_transform.x * SERVER_SPEED * METER_TO_PIXEL * delta

func instantiate_bullet():
	var current_level = LevelManager.get_current_level_node()
	current_level.add_child(self)
	self.global_position = bullet_spawn_position.global_position
	self.rotation = bullet_angle
	
	bullet_node = bullet_scene.instantiate()
	self.add_child(bullet_node)

func remove_bullet_from_scene():
	self.queue_free()
