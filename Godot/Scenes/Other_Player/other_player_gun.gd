extends Node2D
class_name OtherPlayerGunVisualizer

var gun_scene: PackedScene
var gun_node: Node2D
var gun_anchor: Marker2D

var bullet_spawn_position_marker: Marker2D

var current_snapshot: Dictionary

var is_reloading: bool

var gun_hand_sprite: Sprite2D
var reload_gun_hand_sprite: Sprite2D
var gun_hand_sprite_texture_path: String
var gun_reload_hand_texture_path: String
var gun_animation_player: AnimationPlayer
var animation_reload_name: String
var horizontal_frames: int

var gun_blast_animation_player: AnimationPlayer
var gun_blast_sprites: Sprite2D


var is_player_dead: bool

var gun_hand_texture: CompressedTexture2D
var gun_hand_reload_texture: CompressedTexture2D

func _physics_process(delta: float) -> void:
	manage_arm_rotation()

func manage_arm_rotation():
	if self.is_player_dead: 
		return
	if self.current_snapshot:
		self.rotation = current_snapshot["mouse_angle"]
		self.rotation_degrees = wrap(self.rotation_degrees, 0, 360)
		if self.rotation_degrees > 90 and self.rotation_degrees < 270:
			self.scale.y = -1
		else:
			self.scale.y = 1

func _init(gun_scene: PackedScene, gun_anchor: Marker2D, gun_hand_texture: CompressedTexture2D, gun_hand_reload_texture: CompressedTexture2D) -> void:
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	self.gun_hand_texture = gun_hand_texture
	self.gun_hand_reload_texture = gun_hand_reload_texture
	#self.gun_hand_sprite_texture_path = gun_hand_sprite_texture_path
	#self.gun_reload_hand_texture_path = gun_reload_hand_sprite_texture_path
	
func set_snapshot(snapshot: Dictionary):
	self.is_player_dead = snapshot["respawn_timer"] > 0.0
	self.current_snapshot = snapshot

	if self.is_player_dead:
		self.gun_hand_sprite.visible = false
		self.reload_gun_hand_sprite.visible = false
		self.is_reloading = false
		self.gun_animation_player.stop()
		return
	
	var server_is_reloading = snapshot["is_reloading"]
	
	if server_is_reloading:
		if not is_reloading:
			is_reloading = true
			self.gun_hand_sprite.visible = false
			self.reload_gun_hand_sprite.visible = true
			self.gun_animation_player.play(self.animation_reload_name)
	else:
		if is_reloading:
			is_reloading = false
			self.gun_hand_sprite.visible = true
			self.reload_gun_hand_sprite.visible = false
			self.gun_animation_player.stop()
			
	if not is_reloading:
		self.gun_hand_sprite.visible = true
		self.reload_gun_hand_sprite.visible = false

func instantiate_gun():
	gun_anchor.add_child(self)
	gun_node = gun_scene.instantiate()
	bullet_spawn_position_marker = gun_node.find_child("Bullet_Spawn_Position")
	self.add_child(gun_node)
	
	self.gun_hand_sprite = gun_node.find_child("gun_hand")
	self.gun_hand_sprite.texture = self.gun_hand_texture
	self.reload_gun_hand_sprite = gun_node.find_child("reload_hand")
	self.reload_gun_hand_sprite.texture = self.gun_hand_reload_texture
	self.gun_animation_player = gun_node.find_child("AnimationPlayer")
	gun_blast_animation_player = gun_node.find_child("Gun_Blast_Animation_Player")
	self.gun_blast_sprites = gun_node.find_child("Gun_Blast_Sprites")
	self.gun_blast_sprites.visible = false
	
	self.reload_gun_hand_sprite.visible = false
	
	is_reloading = false
	is_player_dead = false
	
func remove_gun_from_scene():
	if is_instance_valid(gun_node):
		gun_node.queue_free() # Briše samo vizuelni deo
	
	if get_parent():
		get_parent().remove_child(self)

func get_bullet_spawn_position_marker():
	return self.bullet_spawn_position_marker

func play_gun_blast_animation():
	self.gun_blast_animation_player.seek(0)
	self.gun_blast_animation_player.play("Gun_Blast_Animation")
