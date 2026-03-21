extends VBoxContainer
class_name KillFeedContainer
#
func add_kill_feed(kill_feed: KillFeed):
	if get_child_count() >= 3:
		var first_kill: KillFeed = get_child(0)	
		first_kill.animation_player.play("slide_out_animation")

	self.add_child(kill_feed)
