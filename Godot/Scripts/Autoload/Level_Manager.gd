extends Node

var CURRENT_LEVEL_NODE: Node2D

#FFA GAME MODE
var CURRENT_LEVEL_GAME_MODE: String = ""
var FFA_KILLS_TO_WIN: int = -1

var players_idle_sprites_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_idle_sprites.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_idle_sprites.png")
}
var players_walking_sprites_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_sprites.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_walking_sprites.png")
}
var players_dying_spirtes_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_dying_sprites.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_player_dying_sprites.png")
}
var players_kill_image_skin: Dictionary = {
	0: preload("res://Sprites/effects/my_player_kill_image.png"),
	1: preload("res://Sprites/effects/enemy_player_kill_image.png")
}

var players_win_image_skin: Dictionary = {
	0: preload("res://Sprites/effects/my_player_kill_image.png"),
	1: preload("res://Sprites/effects/enemy_player_kill_image.png")
}

#PISTOL HAND
var players_pistol_hand_sprite_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_pistol_hand.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_player_pistol_hand.png")
}
var players_pistol_hand_reload_sprites_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_pistol_reload_sprites.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_player_pistol_reload_sprites.png")
}
#M4A1 RIFLE HAND
var players_m4a1_hand_sprite_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_m4a1_hand.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_player_m4a1_hand.png")
}
var players_m4a1_hand_reload_sprites_skin: Dictionary = {
	0: preload("res://Sprites/player/my_player/my_player_m4a1_reload_sprite.png"),
	1: preload("res://Sprites/player/enemy_player/enemy_player_m4a1_reload_sprites.png")
}

func set_current_level_node(level: Node2D):
	CURRENT_LEVEL_NODE = level
func get_current_level_node():
	return CURRENT_LEVEL_NODE
