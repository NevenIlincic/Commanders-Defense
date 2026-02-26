extends Node2D
class_name Tower

@onready var tower_hangar_sprite: Sprite2D = $"Tower-Hangar_Sprite"
@onready var hit_effect_timer: Timer = $hit_effect_timer
#HP 
@onready var health_bar: TextureProgressBar = $Health_Bar
@onready var health_amount_label: Label = $Health_Bar/Health_Amount_Label

var tower_id: int = -1
var owner_id: int = 0
var tower_HP: int = 5000

var tower_sprites: Dictionary = {
	0: load("res://Sprites/tower/tower-hangar.png"),
	1: load("res://Sprites/tower/tower-hangar-hit.png")
}


func setup(tower_snapshot: Dictionary):
	self.tower_id = tower_snapshot["id"]
	self.owner_id =  tower_snapshot["owner_id"]
	if tower_snapshot["is_left_tower"]:
		self.global_position = Vector2(0, 328) #0
	else:
		self.global_position = Vector2(1088, 328) #1088
		tower_hangar_sprite.flip_h = true
		health_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		
func _on_hit_effect_timer_timeout() -> void:
	tower_hangar_sprite.texture = tower_sprites[0];

func handle_server_response(tower_snapshot: Dictionary):
	if tower_HP != tower_snapshot["hp"]:
		tower_HP = tower_snapshot["hp"]
		
		health_amount_label.text = str(tower_HP)
		var tween = create_tween()
		tween.tween_property(health_bar, "value", float(tower_HP), 0.2).set_trans(Tween.TRANS_SINE)
				
		hit_effect_timer.start(0.1)
		tower_hangar_sprite.texture = tower_sprites[1];
