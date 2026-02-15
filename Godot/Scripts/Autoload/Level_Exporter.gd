extends Node

func export_level_to_json():
	var level_data = {"colliders": []}
	# Pretpostavimo da su ti svi podovi u grupi "solids"
	for body in get_tree().get_nodes_in_group("solids"):
		if body is StaticBody2D:
			var shape = body.get_child(0).get_child(0).shape # Uzimamo CollisionShape2D
			if shape is RectangleShape2D:
				var data = {
					"x": body.global_position.x / 32.0,
					"y": body.global_position.y / 32.0,
					"width": shape.size.x / 32.0,
					"height": shape.size.y / 32.0
				}
				level_data["colliders"].append(data)
	
	var file = FileAccess.open("D:/Fakultet/7.semestar/Napredne Tehnike Programiranja/Commanders-Defense/server/level_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(level_data, "\t")) # "\t" dodaje tabove za čitljivost
		file.close()
