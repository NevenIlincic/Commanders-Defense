extends Node2D
class_name PlayerThrowable

var throwable_scene: PackedScene
var throwable_anchor: Marker2D
var throwable_hand_texture: CompressedTexture2D
var throwable_texture: CompressedTexture2D
var throwable_sprite: Sprite2D
var throwable_hand_sprite: Sprite2D
var throwable_node: Node2D
var is_player_dead: bool

var is_chat_visible: bool
var is_pause_menu_visible: bool

func _physics_process(delta: float) -> void:
	if self.throwable_node != null:
		manage_arm_rotation()
		if Input.is_action_just_pressed("chat"):
			self.is_chat_visible = !self.is_chat_visible
		if Input.is_action_just_pressed("escape"):
			self.is_pause_menu_visible = !self.is_pause_menu_visible

func manage_arm_rotation():
	if self.is_player_dead: 
		return
	if not self.is_chat_visible and not self.is_pause_menu_visible:
		self.rotation_degrees = JoystickInputs.get_look_position()
		self.rotation_degrees = wrap(self.rotation_degrees, 0, 360)
		if self.rotation_degrees > 90 and self.rotation_degrees < 270:
			self.scale.y = -1
		else:
			self.scale.y = 1

func _init(throwable_scene: PackedScene, throwable_anchor: Marker2D, hand_sprite_texture: CompressedTexture2D, throwable_texture: CompressedTexture2D) -> void:
	self.throwable_scene = throwable_scene
	self.throwable_anchor = throwable_anchor
	self.throwable_hand_texture = hand_sprite_texture
	self.throwable_texture = throwable_texture

func instantiate_throwable():
	throwable_anchor.add_child(self)
	self.throwable_node = self.throwable_scene.instantiate()
	self.add_child(throwable_node)
	
	self.throwable_hand_sprite = throwable_node.find_child("Throwable_Hand")
	self.throwable_hand_sprite.texture = throwable_hand_texture
	self.throwable_sprite = throwable_node.find_child("Throwable_Sprite")
	self.throwable_sprite.texture = self.throwable_texture
	

func remove_throwable_from_scene():
	if is_instance_valid(self.throwable_node):
		self.throwable_node.queue_free() # Briše samo vizuelni deo
	
	if get_parent():
		get_parent().remove_child(self)

func set_snapshot(snapshot: Dictionary):
	if self.throwable_node != null:
		self.is_player_dead = snapshot["respawn_timer"] > 0.0
		
		if self.is_player_dead:
			self.throwable_hand_sprite.visible = false
			self.throwable_sprite.visible = false
		else:
			self.throwable_hand_sprite.visible = true
			self.throwable_sprite.visible = true
