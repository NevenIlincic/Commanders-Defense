extends ScrollContainer

var swiping = false
var swipe_start
var swipe_mouse_start

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			swiping = true
			swipe_mouse_start = event.position
			swipe_start = scroll_vertical
		else:
			swiping = false
			
	if event is InputEventMouseMotion and swiping:
		scroll_vertical = swipe_start + (swipe_mouse_start.y - event.position.y)
