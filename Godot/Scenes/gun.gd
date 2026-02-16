@abstract class_name PlayerGun 
extends Node2D

@onready var gun_hand: Sprite2D = $gun_hand

var gun_scene: PackedScene
var gun_node: Node2D
var max_ammo: int
var current_ammo: int
var shoot_scaling_rate: float
var gun_anchor: Marker2D

func _physics_process(delta: float) -> void:
	manage_arm_rotation()

func manage_arm_rotation():
	self.look_at(get_global_mouse_position())
	self.rotation_degrees = wrap(self.rotation_degrees, 0, 360)
	if self.rotation_degrees > 90 and self.rotation_degrees < 270:
		self.scale.y = -1
	else:
		self.scale.y = 1

func _init() -> void:
	pass
	
func instantiate_gun():
	gun_anchor.add_child(self)
	gun_node = gun_scene.instantiate()
	self.add_child(gun_node)

func remove_gun_from_scene():
	if is_instance_valid(gun_node):
		gun_node.queue_free() # Briše samo vizuelni deo
	
	if get_parent():
		get_parent().remove_child(self)
