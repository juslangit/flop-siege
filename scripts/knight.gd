extends Node2D
class_name Knight
## A floppy knight: six physics pieces pinned together like a rag doll.
## Launch it with launch(velocity); it reports `settled` once it lies still.

signal settled(knight: Knight)

const PART := preload("res://scripts/knight_part.gd")
const TABARDS := [Color("3a7bd5"), Color("e0a526"), Color("4caf6a"), Color("9b59b6"), Color("e86a3a")]

var parts := {}
var torso: RigidBody2D
var still_time := 0.0
var flight_time := 0.0
var done := false
var splashed := false
var _bounced := 0.0


## Pieces: name -> [kind, size, offset from the body's centre, mass]
const LAYOUT := {
	"leg_l":  ["leg",   Vector2(11, 26), Vector2(-7, 28),  0.35],
	"arm_l":  ["arm",   Vector2(9, 25),  Vector2(-18, -1), 0.25],
	"torso":  ["torso", Vector2(26, 34), Vector2(0, 0),    1.4],
	"head":   ["head",  Vector2(13, 13), Vector2(0, -30),  0.5],
	"leg_r":  ["leg",   Vector2(11, 26), Vector2(7, 28),   0.35],
	"arm_r":  ["arm",   Vector2(9, 25),  Vector2(18, -1),  0.25],
}
## Joints: [piece, piece, pin position relative to the body's centre, swing limit (radians)]
const JOINTS := [
	["torso", "head",  Vector2(0, -18), 0.6],
	["torso", "arm_l", Vector2(-15, -11), 0.0],
	["torso", "arm_r", Vector2(15, -11), 0.0],
	["torso", "leg_l", Vector2(-7, 16), 1.3],
	["torso", "leg_r", Vector2(7, 16), 1.3],
]


func build(at: Vector2, index: int) -> void:
	var tabard: Color = TABARDS[index % TABARDS.size()]
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.15
	for name in LAYOUT:
		var spec: Array = LAYOUT[name]
		var p: RigidBody2D = PART.new()
		p.kind = spec[0]
		p.size = spec[1]
		p.tabard = tabard
		p.mass = spec[3]
		p.position = at + spec[2]
		p.physics_material_override = pm
		p.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
		p.angular_damp = 2.0
		var col := CollisionShape2D.new()
		if p.kind == "head":
			var c := CircleShape2D.new()
			c.radius = spec[1].x
			col.shape = c
		elif p.kind == "torso":
			var r := RectangleShape2D.new()
			r.size = spec[1]
			col.shape = r
		else:
			var cap := CapsuleShape2D.new()
			cap.radius = spec[1].x / 2
			cap.height = spec[1].y
			col.shape = cap
		p.add_child(col)
		if p.kind == "arm" or p.kind == "leg":
			p.z_index = -1 if name.ends_with("_l") else 1
		add_child(p)
		parts[name] = p
	torso = parts["torso"]
	# Pieces of one knight never bump into each other, only into the world.
	var all := parts.values()
	for a in all:
		for b in all:
			if a != b:
				a.add_collision_exception_with(b)
	for j in JOINTS:
		var pin := PinJoint2D.new()
		pin.position = at + j[2]
		pin.softness = 0.0
		add_child(pin)
		pin.node_a = pin.get_path_to(parts[j[0]])
		pin.node_b = pin.get_path_to(parts[j[1]])
	torso.contact_monitor = true
	torso.max_contacts_reported = 2
	torso.body_entered.connect(_on_torso_hit)


func launch(velocity: Vector2) -> void:
	for p in parts.values():
		p.linear_velocity = velocity
	# A little spin so every throw flops differently.
	torso.angular_velocity = randf_range(-5.0, 5.0)
	parts["arm_l"].angular_velocity = randf_range(-12.0, 12.0)
	parts["arm_r"].angular_velocity = randf_range(-12.0, 12.0)


func centre() -> Vector2:
	return torso.global_position if is_instance_valid(torso) else global_position


func speed() -> float:
	return torso.linear_velocity.length() if is_instance_valid(torso) else 0.0


func _on_torso_hit(_body: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if torso.linear_velocity.length() > 250.0 and now - _bounced > 0.3:
		_bounced = now
		Sfx.play("boing", -6.0)
		parts["head"].dazed = true
		parts["head"].queue_redraw()


func _physics_process(delta: float) -> void:
	if done:
		return
	flight_time += delta
	var c := centre()
	if c.y > 1650.0 or c.x > 880.0 or c.x < -160.0:
		_finish()
		return
	if speed() < 18.0 and flight_time > 0.5:
		still_time += delta
		if still_time > 0.7:
			_finish()
	else:
		still_time = 0.0
	# Give up waiting on a knight that keeps twitching.
	if flight_time > 7.0:
		_finish()


func _finish() -> void:
	done = true
	settled.emit(self)


## Fade away politely when there are too many knights lying around.
func retire() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
