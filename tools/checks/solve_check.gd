extends SceneTree
## How hard is each castle? Tries a grid of single throws (pull strength x angle)
## on one level and counts how many knock the king off with ONE knight.
##   tools/checks/run.sh solve_check <level>

const TRIAL_TIME := 4.5
var game: Node
var level := 0
var trials: Array = []
var idx := -1
var t := 0.0
var wins: Array = []
var broke := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		level = int(a[0])
	for pull in range(130, 251, 15):
		for deg in range(25, 81, 5):
			trials.append(Vector2.from_angle(deg_to_rad(-deg)) * pull)
	game = load("res://scenes/game.tscn").instantiate()
	game.saving = false
	root.add_child(game)


func _physics_process(delta: float) -> bool:
	if idx == -1 or t > TRIAL_TIME or (idx >= 0 and game.king.flopped and t > 1.2):
		if idx >= 0:
			if game.king.flopped:
				wins.append(trials[idx])
			broke += game.level.blocks.size() - game.get_tree().get_nodes_in_group("blocks").size()
		idx += 1
		if idx >= trials.size():
			var names := []
			for w in wins:
				names.append("%d°/%d" % [round(-rad_to_deg(w.angle())), round(w.length())])
			print("level %d %-18s one-knight wins %3d / %d   avg blocks broken %.1f   e.g. %s" % [level + 1,
				game.level.name, wins.size(), trials.size(), float(broke) / trials.size(), ", ".join(names.slice(0, 6))])
			return true
		game._hide_title()
		game.start_level(level)
		t = 0.0
		return false
	t += delta
	if t > 0.9 and t - delta <= 0.9:
		game.throw_knight(game.throw_velocity(trials[idx]))
	return false
