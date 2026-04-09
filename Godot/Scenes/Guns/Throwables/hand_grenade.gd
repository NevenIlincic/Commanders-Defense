
extends CharacterBody2D
class_name Throwable

var GRAVITY = 15.0
const METER_TO_PIXEL = 32
var bounce_factor = 0.6  
var power = 500

var launch_angle = 0.0 
var is_launched = false

var throwable_scene: PackedScene
var throwable_node: CharacterBody2D
var rotation_speed = 10.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var explosion_sprites: Sprite2D = $Explosion_Sprites
@onready var explosion_timer: Timer = $Explosion_Timer
@onready var grenade_sprite: Sprite2D = $Grenade_Sprite
@onready var explosion_area: Area2D = $Explosion_Area

func _physics_process(delta):
	if self.is_launched:
		if velocity.length() > 10:
			rotation += rotation_speed * delta
			
		velocity.y += GRAVITY * METER_TO_PIXEL * delta 
		
		var collision = move_and_collide(velocity * delta)
		
		if collision:
			velocity = velocity.bounce(collision.get_normal()) * self.bounce_factor
			if velocity.length() < 25 and collision.get_normal().y < -0.8:
				velocity = Vector2.ZERO

		
func throw(throw_position: Vector2):
	if not self.is_launched:
		global_position = throw_position
		velocity = Vector2.from_angle(Network.INPUT_DATA["mouse_angle"]) * self.power
		is_launched = true
		explosion_timer.start()


func _on_explosion_timer_timeout() -> void:
	explosion_sprites.visible = true
	grenade_sprite.visible = false
	is_launched = false
	velocity = Vector2.ZERO
	
	set_physics_process(false)
	
	animation_player.play("Grenade_Explosion")
	apply_explosion_damage()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Grenade_Explosion":
		self.queue_free()

func apply_explosion_damage():
	var targets = explosion_area.get_overlapping_bodies()
	var space_state = get_world_2d().direct_space_state

	for target in targets:
		if target is MyPlayer:
			var ray_query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
		
			ray_query.collision_mask = 1|2
			ray_query.exclude = [self.get_rid()]
			
			var ray_result = space_state.intersect_ray(ray_query)
			
			if ray_result:
				if ray_result.collider == target:
					print("BUM! Direktno pogođen: ", target.name)
				else:
					print("Zaklonjen objektom: ", ray_result.collider.name)
