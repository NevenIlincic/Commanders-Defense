class_name OtherPlayerM4A1RifleVisualizer extends OtherPlayerGunVisualizer

func _init(gun_scene: PackedScene, gun_anchor: Marker2D, 
gun_hand_sprite_texture_path: String, gun_reload_hand_sprite_texture_path: String) -> void:
	super._init(gun_scene, gun_anchor, gun_reload_hand_sprite_texture_path, gun_reload_hand_sprite_texture_path)
	self.animation_reload_name = "m4a1_rifle_reload_animation"
