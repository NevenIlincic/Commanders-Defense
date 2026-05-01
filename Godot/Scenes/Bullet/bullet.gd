@abstract 
class_name PlayerBullet extends Node2D

var bullet_scene: PackedScene
var bullet_node: Node2D
var bullet_angle: float
var bullet_spawn_position: Vector2
var SERVER_SPEED: float
const SERVER_DELTA = 0.016
const METER_TO_PIXEL = 32

var target_position: Vector2
var visual_offset: Vector2 = Vector2.ZERO

var is_initialized: bool = false
var is_enemy_bullet: bool = false

func _ready() -> void:
	pass # Replace with function body.

func _init() -> void:
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	self.global_position += global_transform.x * SERVER_SPEED * METER_TO_PIXEL * delta
	####
	
	# 2. Ispravljanje putanje prema serveru
	#if is_initialized and is_enemy_bullet:
		#var distance = global_position.distance_to(target_position)
		#if distance < 100:
			#global_position = global_position.lerp(target_position, 40.0 * delta)
		#else:
			## Ako je lag preveliki (teleport)
			#global_position = target_position

func instantiate_bullet(server_spawn_position = Vector2.ZERO, is_enemy_bullet = false):
	var current_level = LevelManager.get_current_level_node()
	current_level.add_child(self)
	visual_offset = self.bullet_spawn_position - server_spawn_position
	self.global_position = bullet_spawn_position
	self.rotation_degrees = bullet_angle
	
	bullet_node = bullet_scene.instantiate()
	var area2d: Area2D = bullet_node.find_child("Bullet_Hitbox")
	area2d.area_entered.connect(check_collision_with_walls)
	self.add_child(bullet_node)
	is_initialized = true

func remove_bullet_from_scene():
	self.queue_free()

func check_collision_with_walls(hit_area: Area2D):
	if hit_area.is_in_group("solids"):
		self.remove_bullet_from_scene()
	if hit_area.is_in_group("Other_Player_Hitbox"):
		self.remove_bullet_from_scene()
	if hit_area.is_in_group("tower_hit_box"):
		self.remove_bullet_from_scene()

func handle_server_response(bullet_snapshot: Dictionary):
	target_position = Vector2(bullet_snapshot["position"][0], bullet_snapshot["position"][1]) * METER_TO_PIXEL
	#else:
		#global_position = lerp(global_position, target_position, 40*SERVER_DELTA)
