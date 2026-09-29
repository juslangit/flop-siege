extends SceneTree
## Every castle must stand up on its own: load each level, wait 5 seconds with no
## throws, and check nothing broke, nothing drifted and the king is still up.
##   Godot --headless --path . -s tools/checks/stand_check.gd --fixed-fps 60

var game: Node
var level := 0
var t := 0.0
var start := {}
var failures := 0


func _initialize() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.saving = false
	root.add_child(game)


func _process(delta: float) -> bool:
	if t == 0.0:
		game._hide_title()
		game.start_level(level)
	t += delta
	if t > 0.2 and start.is_empty():
		for b in game.world.get_children():
			start[b] = b.global_position
			# "wake": shake every block awake instead of letting it rest asleep.
			if "wake" in OS.get_cmdline_user_args() and b is RigidBody2D:
				b.sleeping = false
	if t > 5.0:
		var moved := 0
		var lost := 0
		for b in start:
			if not is_instance_valid(b):
				lost += 1
			elif b.global_position.distance_to(start[b]) > 4.0:
				moved += 1
		var ok: bool = moved == 0 and lost == 0 and not game.king.flopped
		if not ok:
			failures += 1
		print("%s  level %d %-18s blocks %2d  moved %d  broken %d  king %s" % ["OK  " if ok else "FAIL", level + 1,
			game.level.name, start.size() - 1, moved, lost, "flopped" if game.king.flopped else "up"])
		if "verbose" in OS.get_cmdline_user_args():
			for b in start:
				if is_instance_valid(b) and b.global_position.distance_to(start[b]) > 4.0:
					print("    moved: ", b.get("kind"), " from ", start[b], " to ", b.global_position)
		level += 1
		t = 0.0
		start.clear()
		if level >= Levels.count():
			print("ALL CASTLES STAND" if failures == 0 else "%d CASTLE(S) FELL" % failures)
			return true
	return false
