extends OptionButton
class_name MaxPlayersOptionButton

func _ready() -> void:
	Signals.SET_MAXIMUM_PLAYERS_TOWER_GAME_MODE.connect(set_maximum_players_for_tower_game_mode)
	set_maximum_players_for_tower_game_mode(true)
	
func _on_pressed() -> void:
	var popup = get_popup()
	popup.min_size.y = 1
	popup.max_size.y = 200

func set_maximum_players_for_tower_game_mode(is_max_two_players: bool):
	if is_max_two_players:
		self.select(0)
		for i in range(1, self.item_count):
			self.set_item_disabled(i, true)
	else:
		for i in range(1, self.item_count):
			self.set_item_disabled(i, false)
