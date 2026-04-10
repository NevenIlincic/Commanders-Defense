
extends CharacterBody2D
class_name Throwable

var GRAVITY = 15.0
const METER_TO_PIXEL = 32
var bounce_factor = 0.82
var power = 515

var launch_angle = 0.0 
var is_launched = false

var throwable_scene: PackedScene
var throwable_node: CharacterBody2D
var rotation_speed = 50.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var explosion_sprites: Sprite2D = $Explosion_Sprites
@onready var explosion_timer: Timer = $Explosion_Timer
@onready var grenade_sprite: Sprite2D = $Grenade_Sprite
@onready var explosion_area: Area2D = $Explosion_Area
@onready var explosion_sound: AudioStreamPlayer2D = $Explosion_Sound
@onready var platform_hit_sound: AudioStreamPlayer2D = $Platform_Hit_Sound
const PHYSICS_DELTA: float = 1.0/60.0
var target_position: Vector2 = Vector2.ZERO
func _physics_process(delta):
	self.handle_movement(PHYSICS_DELTA)
	#global_position = lerp(global_position, target_position, 0.5)

func handle_server_response(snapshot: Dictionary):
	target_position = Vector2(snapshot["position"][0] * 32, snapshot["position"][1] * 32)


func handle_movement(delta: float):
	if not is_launched:
		return
	
	velocity.y += GRAVITY * METER_TO_PIXEL * delta
	self.rotation += (velocity.x / power) * rotation_speed * delta
	var motion = velocity * delta
	
	# Za sticky bombu nam ne treba petlja, jer se lepi na prvi udar
	var collision = move_and_collide(motion)
	
	if collision:
		# 1. Zaustavi fiziku
		is_launched = false
		velocity = Vector2.ZERO
		
		# 2. "Zalepi" je za metu (opciono: pomeri je mrvicu unutar zida da izgleda zalepljeno)
		global_position = collision.get_position()
		
		explosion_sprites.visible = true
		grenade_sprite.visible = false
		is_launched = false
		velocity = Vector2.ZERO
		animation_player.play("Grenade_Explosion")
		apply_explosion_damage()
		
		# 3. Zvuk udara
		#if platform_hit_sound:
			#platform_hit_sound.play()
			

func throw(throw_position: Vector2, angle):
	if not self.is_launched:
		global_position = throw_position
		velocity = angle * self.power
		is_launched = true

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Grenade_Explosion":
		self.queue_free()

func apply_explosion_damage():
	var targets = explosion_area.get_overlapping_bodies()
	var space_state = get_world_2d().direct_space_state

	for target in targets:
		if target is MyPlayer:
			var direction_to_target = (target.global_position - global_position).normalized()
			var start_point = global_position + direction_to_target * 2.0
			
			var ray_query = PhysicsRayQueryParameters2D.create(start_point, target.global_position)
			
			ray_query.collision_mask = 1 | 2 
			ray_query.exclude = [self.get_rid()]
			ray_query.hit_from_inside = true
			
			var ray_result = space_state.intersect_ray(ray_query)
			
			if ray_result:
				if ray_result.collider == target:
					Signals.CAMERA_SHAKE.emit()
