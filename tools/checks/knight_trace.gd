extends SceneTree
## Debug: throw one knight and print where its body is every 0.1 s.
##   tools/checks/run.sh knight_trace <level> <vx,vy>
var game: Node
var t := 0.0
var k: Node
var v := Vector2(540, -915)
var lvl := 0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: lvl = int(a[0])
	if a.size() > 1: v = Vector2(float(a[1].split(",")[0]), float(a[1].split(",")[1]))
	game = load("res://scenes/game.tscn").instantiate()
	game.saving = false
	root.add_child(game)

func _physics_process(delta: float) -> bool:
	if t == 0.0:
		game._hide_title(); game.start_level(lvl)
	t += delta
	if k == null and t > 1.0:
		game.throw_knight(v)
		for c in game.world.get_children():
			if c.has_method("launch"): k = c
	if k != null and int(t * 60) % 6 == 0:
		if is_instance_valid(k) and is_instance_valid(k.torso):
			print("%.1f  torso %s  v %.0f  done %s  king %s flopped %s" % [t, k.torso.global_position.round(), k.speed(), k.done, game.king.global_position.round(), game.king.flopped])
		else:
			print("%.1f knight gone" % t)
	return t > 5.0
