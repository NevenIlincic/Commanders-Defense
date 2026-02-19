class_name OtherPlayerPistolVisualizer extends OtherPlayerGunVisualizer

func _init(gun_scene: PackedScene, gun_anchor: Marker2D, 
gun_hand_sprite_texture_path: String, gun_reload_hand_sprite_texture_path: String) -> void:
	super._init(gun_scene, gun_anchor, gun_hand_sprite_texture_path, gun_reload_hand_sprite_texture_path)
	self.animation_reload_name = "pistol_reload_animation"
