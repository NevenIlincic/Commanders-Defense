class_name OtherPlayerM4A1RifleVisualizer extends OtherPlayerGunVisualizer

func _init(gun_scene: PackedScene, gun_anchor: Marker2D, 
gun_hand_texture: CompressedTexture2D, gun_hand_reload_texture: CompressedTexture2D) -> void:
	super._init(gun_scene, gun_anchor, gun_hand_texture, gun_hand_reload_texture)
	self.animation_reload_name = "m4a1_rifle_reload_animation"
