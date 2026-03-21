extends Node

var PIXELS_TO_METER: float = 32.0

func export_level_to_json(map_name: String):
	var level_data = {
		"colliders": [],
		"spawn_positions": [],
		"tower_positions": []
	}
	
	for body in get_tree().get_nodes_in_group("solids"):
		if body is StaticBody2D:
			var shape = body.get_child(0).get_child(0).shape # Uzimamo CollisionShape2D
			if shape is RectangleShape2D:
				var data = {
					"x": body.global_position.x / PIXELS_TO_METER,
					"y": body.global_position.y / PIXELS_TO_METER,
					"width": shape.size.x / PIXELS_TO_METER,
					"height": shape.size.y / PIXELS_TO_METER
				}
				level_data["colliders"].append(data)
	
	for spawn_position in get_tree().get_nodes_in_group("spawn_position"):
		var data = {
			"x": spawn_position.global_position.x / PIXELS_TO_METER,
			"y": spawn_position.global_position.y / PIXELS_TO_METER
		}
		level_data["spawn_positions"].append(data)
	
	for tower_position in get_tree().get_nodes_in_group("tower_position"):
		var data = {
			"x": tower_position.global_position.x / PIXELS_TO_METER,
			"y": tower_position.global_position.y / PIXELS_TO_METER
		}
		level_data["tower_positions"].append(data)
		
	var file_path = str("D:/Fakultet/7.semestar/Napredne Tehnike Programiranja/Commanders-Defense/server/maps/", map_name, ".json")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(level_data, "\t"))
		file.close()
