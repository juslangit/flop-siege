extends SceneTree
## Visual check: loads a level and throws knights on a schedule, so it can be recorded:
##   Godot --path . -s tools/checks/throw_demo.gd --write-movie out/f.png --fixed-fps 30 -- <level> <vx,vy> [<vx,vy> ...]
## Without arguments: level 1, one throw.

var game: Node
var t := 0.0
var throws: Array = []
var level := 0
var next_throw := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		level = int(args[0])
	for a in args.slice(1):
		var p: PackedStringArray = a.split(",")
		throws.append(Vector2(float(p[0]), float(p[1])))
	if throws.is_empty():
		throws.append(Vector2(700, -1150))
	game = load("res://scenes/game.tscn").instantiate()
	game.saving = false
	root.add_child(game)


func _process(delta: float) -> bool:
	t += delta
	if t < 0.05:
		return false
	if game.state == 0:
		game._hide_title()
		game.start_level(level)
	if next_throw < throws.size() and t > 1.5 + next_throw * 2.2 and game.can_throw():
		game.throw_knight(throws[next_throw])
		next_throw += 1
	return t > 1.5 + throws.size() * 2.2 + 3.5
