extends RigidBody2D
class_name King
## The pompous little king on top of the castle. Knock him off his tower to win.

signal hit_ground

const OUTLINE := Color("2a2420")
const RADIUS := 24.0

var start_y := 0.0
var flopped := false
var alarmed := false
var armed := false


func setup() -> void:
	mass = 2.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.2
	physics_material_override = pm
	var col := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	col.shape = c
	add_child(col)
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	angular_damp = 1.5
	sleeping = true
	body_entered.connect(_on_body_entered)
	start_y = position.y
	z_index = 2


func _on_body_entered(body: Node) -> void:
	if not armed:
		return
	if body.is_in_group("ground"):
		hit_ground.emit()


func _physics_process(_delta: float) -> void:
	# Once he starts wobbling, he looks worried.
	var worried: bool = linear_velocity.length() > 60.0 or abs(angular_velocity) > 1.5
	if armed and worried and not alarmed:
		alarmed = true
		queue_redraw()


func set_flopped() -> void:
	flopped = true
	queue_redraw()


func _draw() -> void:
	var r := RADIUS
	# Robe: a red ball with a white fur band.
	draw_circle(Vector2.ZERO, r + 3.5, OUTLINE)
	draw_circle(Vector2.ZERO, r, Color("c8323c"))
	draw_circle(Vector2(r * 0.35, r * 0.35), r * 0.55, Color("9e2530"))
	draw_circle(Vector2(-r * 0.05, -r * 0.05), r * 0.8, Color("c8323c"))
	draw_rect(Rect2(-r * 0.95, r * 0.05, r * 1.9, 8), Color("f5f0e6"))
	for x in [-12.0, 0.0, 12.0]:
		draw_circle(Vector2(x, r * 0.05 + 4), 1.8, OUTLINE)
	# Face.
	var face := Vector2(0, -r * 0.45)
	draw_circle(face, 15.5, OUTLINE)
	draw_circle(face, 12.5, Color("f2c29b"))
	if flopped:
		# Squeezed-shut eyes and a pout.
		draw_line(face + Vector2(-8, -3), face + Vector2(-3, -1), OUTLINE, 2.5)
		draw_line(face + Vector2(8, -3), face + Vector2(3, -1), OUTLINE, 2.5)
		draw_arc(face + Vector2(0, 8), 4.0, PI * 1.15, PI * 1.85, 8, OUTLINE, 2.5)
	elif alarmed:
		# Wide eyes and an "O" mouth.
		for x in [-5.0, 5.0]:
			draw_circle(face + Vector2(x, -2), 3.8, Color.WHITE)
			draw_circle(face + Vector2(x, -2), 1.8, OUTLINE)
		draw_circle(face + Vector2(0, 6), 3.2, OUTLINE)
	else:
		# Smug: half-closed eyes and a big moustache.
		for x in [-5.0, 5.0]:
			draw_line(face + Vector2(x - 3, -2), face + Vector2(x + 3, -2), OUTLINE, 2.5)
	draw_colored_polygon(PackedVector2Array([face + Vector2(-9, 4), face + Vector2(0, 2), face + Vector2(9, 4), face + Vector2(0, 6)]), Color("7a4a2a"))
	# Crown.
	var cb := face + Vector2(0, -10)
	var crown := PackedVector2Array([cb + Vector2(-13, 0), cb + Vector2(-15, -16), cb + Vector2(-7, -8),
		cb + Vector2(0, -19), cb + Vector2(7, -8), cb + Vector2(15, -16), cb + Vector2(13, 0)])
	var outline := PackedVector2Array(crown)
	outline.append(crown[0])
	draw_colored_polygon(crown, Color("f5c542"))
	draw_polyline(outline, OUTLINE, 3.0)
	draw_circle(cb + Vector2(0, -6), 2.5, Color("c8323c"))
