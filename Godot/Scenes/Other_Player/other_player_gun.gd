class_name OtherPlayerGunVisualizer
extends Node2D

var gun_scene: PackedScene
var gun_node: Node2D
var gun_anchor: Marker2D

var current_snapshot: Dictionary

func _physics_process(delta: float) -> void:
	manage_arm_rotation()

func manage_arm_rotation():
	if self.current_snapshot:
		self.rotation = current_snapshot["mouse_angle"]
		self.rotation_degrees = wrap(self.rotation_degrees, 0, 360)
		if self.rotation_degrees > 90 and self.rotation_degrees < 270:
			self.scale.y = -1
		else:
			self.scale.y = 1

func _init(gun_scene: PackedScene, gun_anchor: Marker2D) -> void:
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	

func set_snapshot(snapshot: Dictionary):
	self.current_snapshot = snapshot

func instantiate_gun():
	gun_anchor.add_child(self)
	gun_node = gun_scene.instantiate()
	self.add_child(gun_node)

func remove_gun_from_scene():
	if is_instance_valid(gun_node):
		gun_node.queue_free() # Briše samo vizuelni deo
	
	if get_parent():
		get_parent().remove_child(self)
