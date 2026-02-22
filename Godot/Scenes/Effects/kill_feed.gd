extends Node2D
class_name KillFeed

@onready var killer_sprite: Sprite2D = $HBoxContainer/Killer_Sprite
@onready var victim_sprite: Sprite2D = $HBoxContainer/Victim_Sprite
@onready var gun_sprite: Sprite2D = $HBoxContainer/Gun_Sprite
@onready var background_killed: Sprite2D = $HBoxContainer/Background_Killed
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $Timer


var gun_sprites: Dictionary = {
	"pistol": load("res://Sprites/effects/pistol_kill.png"),
	"m4a1_rifle": load("res://Sprites/effects/m4a1_rifle_kill.png")
}

var background_sprites: Dictionary = {
	"death": load("res://Sprites/effects/background_killed.png"),
	"killed": load("res://Sprites/effects/background_my_player_killing.png"),
	"neutral": load("res://Sprites/effects/background_neutral_killed.png")
}

func _ready() -> void:
	pass	
func setup(killer: Sprite2D, victim: Sprite2D, killed_with: String, marker_position: Vector2, action: String) -> void:
	killer_sprite.texture = killer.texture
	victim_sprite.texture = victim.texture
	gun_sprite.texture = gun_sprites[killed_with]
	background_killed.texture = background_sprites[action]
	victim_sprite.flip_h = true
	global_position = marker_position
	animation_player.play("slide_in_animation")
	animation_player.seek(0, true) # 'true' forsira promenu vizuelno ODMAH
	
	# 4. Tek sada ga prikaži
	show()
	timer.start(3)

func _on_timer_timeout() -> void:
	animation_player.play("slide_out_animation")
	animation_player.seek(0, true)
	show()
