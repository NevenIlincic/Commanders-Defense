extends Node2D

const SCOREBOARD_ROW_SCENE = preload("res://Scenes/Scoreboard/Scoreboard_Row.tscn")

@onready var scores_container: VBoxContainer = $ScrollContainer/Scores_Container
@onready var kills_to_win_label: Label = $Kills_To_Win_Label

var players_row: Dictionary = {}

func _ready() -> void:
	Signals.UPDATE_SCOREBOARD.connect(update_scoreboard)
	Signals.UPDATE_SCOREBOARD_CONNECTED.connect(add_player_to_scoreboard)
	Signals.UPDATE_SCOREBOARD_DISCONNECTED.connect(remove_from_scoreboard)
	setup()
	
func setup():
	if LevelManager.CURRENT_LEVEL_GAME_MODE == "FFA":
		kills_to_win_label.text = str("Kills To Win: ", LevelManager.FFA_KILLS_TO_WIN)
	elif LevelManager.CURRENT_LEVEL_GAME_MODE == "TOWERS":
		kills_to_win_label.text = "TOWERS GAME MODE"
func update_scoreboard(scoreboard_info):
	for player_id in scoreboard_info.keys():
		var player_row: ScoreboardRow = players_row[player_id]
		player_row.update_kill_amount(scoreboard_info[player_id])
	
	#var rows = scores_container.get_children()
	#rows.sort_custom(func(a, b):
		#return a.player_kill_amount > b.player_kill_amount
	#)
	#
	#for i in range(rows.size()):
		#scores_container.move_child(rows[i], i)
		
		# 2. Zapamti gde se koji red trenutno nalazi na ekranu pre sortiranja
	var old_positions = {}
	var rows = scores_container.get_children()
	for row in rows:
		old_positions[row] = row.global_position

	# 3. Izvrši sortiranje u stablu (ovo bi ih inače teleportovalo)
	rows.sort_custom(func(a, b):
		return a.player_kill_amount > b.player_kill_amount
	)
	
	for i in range(rows.size()):
		scores_container.move_child(rows[i], i)

	await get_tree().process_frame

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var has_animations = false
	
	for row in rows:
		var new_pos = row.global_position
		var old_pos = old_positions[row]
		if old_pos != new_pos:
			var delta_pos = old_pos - new_pos
			row.position += delta_pos
			tween.tween_property(row, "position", row.position - delta_pos, 0.6)
			has_animations = true
			
	if not has_animations:
		tween.kill()
		
func remove_from_scoreboard(player_id: int):
	await get_tree().process_frame
	var player_row: ScoreboardRow = players_row[player_id]
	player_row.queue_free()
	players_row.erase(player_id)

func add_player_to_scoreboard(player_id: int, player_nickname: String,  player_skin_index: int,):
	if not players_row.has(player_id):
		var player_row: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate()
		scores_container.add_child(player_row)
		player_row.setup(player_id, player_nickname, player_skin_index)
		players_row[player_id] = player_row
