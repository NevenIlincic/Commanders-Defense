@abstract class_name PlayerGun 
extends Node2D

var bullet_spawn_position: Marker2D

var gun_scene: PackedScene
var gun_node: Node2D
var max_ammo: int
var current_ammo: int
var fire_rate: float
var gun_anchor: Marker2D
var shoot_cooldown: float
var reload_time: float
var reload_time_till_end: float
var reloaded: bool

#SOUND
var shoot_sound: AudioStreamPlayer2D
var reload_sound: AudioStreamPlayer2D

var is_reloading_locally: bool = false

var gun_hand_sprite: Sprite2D
var reload_gun_hand_sprite: Sprite2D
var gun_animation_player: AnimationPlayer
var reload_animation_name: String

var gun_blast_animation_player: AnimationPlayer
var gun_blast_sprites: Sprite2D

var is_player_dead: bool

var gun_hand_texture: CompressedTexture2D
var gun_hand_reload_texture: CompressedTexture2D

var is_chat_visible: bool
var is_pause_menu_visible: bool

func _physics_process(delta: float) -> void:
	if self.gun_node != null:
	#print(bullet_spawn_position.position)
		manage_arm_rotation()
		check_for_shoot()
		handle_shoot_cooldown(delta)
		if Input.is_action_just_pressed("chat"):
			self.is_chat_visible = !self.is_chat_visible
		if Input.is_action_just_pressed("escape"):
			self.is_pause_menu_visible = !self.is_pause_menu_visible
	

func manage_arm_rotation():
	if not self.is_chat_visible and not self.is_pause_menu_visible:
		self.look_at(get_global_mouse_position())
		self.rotation_degrees = wrap(self.rotation_degrees, 0, 360)
		if self.rotation_degrees > 90 and self.rotation_degrees < 270:
			self.scale.y = -1
		else:
			self.scale.y = 1

func _init(gun_hand_texture: CompressedTexture2D, gun_hand_reload_texture: CompressedTexture2D) -> void:
	self.gun_hand_texture = gun_hand_texture
	self.gun_hand_reload_texture = gun_hand_reload_texture

@abstract
func check_for_shoot();

func instantiate_gun():
	gun_anchor.add_child(self)
	gun_node = gun_scene.instantiate()
	self.bullet_spawn_position = gun_node.get_node("Bullet_Spawn_Position")
	self.shoot_sound = gun_node.get_node("Shoot_Sound")
	self.reload_sound = gun_node.get_node("Reload_Sound")
	self.add_child(gun_node)
	
	gun_hand_sprite = gun_node.find_child("gun_hand")
	gun_hand_sprite.texture = self.gun_hand_texture
	reload_gun_hand_sprite = gun_node.find_child("reload_hand")
	reload_gun_hand_sprite.texture = self.gun_hand_reload_texture
	gun_animation_player = gun_node.find_child("AnimationPlayer")
	self.gun_blast_animation_player = gun_node.find_child("Gun_Blast_Animation_Player")
	self.gun_blast_sprites = gun_node.find_child("Gun_Blast_Sprites")
	#self.gun_blast_sprites.modulate.a = 0
	self.gun_blast_sprites.visible = false
	is_reloading_locally = false
	is_player_dead = false
	is_chat_visible = false
	is_pause_menu_visible = false
	self.shoot_cooldown = 0.1
		
func remove_gun_from_scene():
	if self.gun_node != null:
		if self.reload_sound.playing:
			self.reload_sound.stop()
			self.reload_sound.stream = null
			
		if is_instance_valid(gun_node):
			gun_node.queue_free() # Briše samo vizuelni deo
		
		if get_parent():
			get_parent().remove_child(self)

func handle_shoot_cooldown(delta: float):
	if self.gun_node != null:
		self.shoot_cooldown -= delta
		if self.shoot_cooldown < 0:
			self.shoot_cooldown = -1.0



func reset_shoot_cooldown():
	self.shoot_cooldown = self.fire_rate

func play_reload_animation():
	if self.current_ammo != self.max_ammo:
		self.gun_hand_sprite.visible = false
		self.reload_gun_hand_sprite.visible = true
		self.gun_animation_player.play(self.reload_animation_name)
		CustomCursor.set_reload_cursor(self.reload_time)
		if not self.reload_sound.playing:
			self.reload_sound.play()
	
func update_from_server(player_snapshot: Dictionary):
	if self.gun_node != null:
		self.current_ammo = player_snapshot["current_ammo"]
		self.reloaded = !player_snapshot["is_reloading"]
		
		self.is_player_dead = player_snapshot["respawn_timer"] > 0.0
		
		#Ako je igrac mrtav
		if is_player_dead:
			self.gun_hand_sprite.visible = false
			self.reload_gun_hand_sprite.visible = false
			CustomCursor.set_sight_cursor_visible()

			return
		
		#Ako server kaze da treba repetiranje
		if player_snapshot["is_reloading"] and not is_reloading_locally:
			is_reloading_locally = true
			play_reload_animation()
		
		#Ako server kaze da je repetiranje zavrseno
		if not player_snapshot["is_reloading"] and is_reloading_locally:
			is_reloading_locally = false
			self.gun_hand_sprite.visible = true
			self.reload_gun_hand_sprite.visible = false
			self.gun_animation_player.stop()
			CustomCursor.set_sight_cursor_visible()
		
		#Ako je igrac ziv i ne repetira
		if not is_reloading_locally:
			self.gun_hand_sprite.visible = true
			self.reload_gun_hand_sprite.visible = false
