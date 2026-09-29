extends RigidBody2D
class_name Block
## One piece of the castle: a plank, a stone, an ice slab or a roof cone.
## It draws itself, takes damage from hard knocks, and breaks when worn out.

signal broken(block: Block)

const OUTLINE := Color("2a2420")
## What each material is like. hp = how much knocking it takes before it breaks.
const MATERIALS := {
	"wood":  {"fill": Color("d9a066"), "shade": Color("b07a45"), "line": Color("8a5a30"),
			  "density": 1.0, "hp": 55.0, "friction": 0.8, "bounce": 0.05, "sound": "wood"},
	"stone": {"fill": Color("9fb0c0"), "shade": Color("7a8a9c"), "line": Color("5d6b7c"),
			  "density": 2.4, "hp": 140.0, "friction": 0.9, "bounce": 0.0, "sound": "stone"},
	"ice":   {"fill": Color("bfeaf5"), "shade": Color("8fd0e6"), "line": Color("ffffff"),
			  "density": 0.8, "hp": 22.0, "friction": 0.06, "bounce": 0.1, "sound": "ice"},
	"roof":  {"fill": Color("d8574a"), "shade": Color("a83c34"), "line": Color("7c2a25"),
			  "density": 0.7, "hp": 45.0, "friction": 0.8, "bounce": 0.05, "sound": "wood"},
}
## A knock softer than this does no damage (it is just things resting on each other).
const IMPACT_THRESHOLD := 90.0
const DAMAGE_PER_IMPULSE := 0.2

var kind := "wood"
var size := Vector2(20, 100)
var hp := 55.0
var max_hp := 55.0
## Damage is off for the first moment, while the castle settles on the cliff.
var armed := false
var _last_sound := 0.0
## The steady push this block normally feels (the weight of whatever sits on it).
## Only a sudden spike above this counts as a knock — holding up a tower is not damage.
var _steady := 0.0


func setup(p_kind: String, p_size: Vector2) -> void:
	kind = p_kind
	size = p_size
	var m: Dictionary = MATERIALS[kind]
	max_hp = m.hp * clamp(size.x * size.y / 2400.0, 0.6, 2.0)
	hp = max_hp
	mass = max(0.3, size.x * size.y * m.density / 800.0)
	var pm := PhysicsMaterial.new()
	pm.friction = m.friction
	pm.bounce = m.bounce
	physics_material_override = pm
	var col := CollisionShape2D.new()
	if kind == "roof":
		var poly := CollisionPolygon2D.new()
		poly.polygon = _roof_points()
		add_child(poly)
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		col.shape = rect
		add_child(col)
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	can_sleep = true
	sleeping = true
	add_to_group("blocks")


func arm() -> void:
	armed = true


func _roof_points() -> PackedVector2Array:
	var h := size.y
	var w := size.x
	return PackedVector2Array([Vector2(-w / 2, h / 2), Vector2(w / 2, h / 2), Vector2(0, -h / 2)])


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var total := 0.0
	for i in state.get_contact_count():
		total += state.get_contact_impulse(i).length()
	var spike := total - _steady
	# Follow slow changes in load, but not the sudden ones.
	_steady = lerp(_steady, total, 0.08 if spike > 0.0 else 0.3)
	# A block carrying a lot of weight jiggles more, so it needs a bigger jolt to count.
	var threshold := IMPACT_THRESHOLD + _steady * 0.6
	if armed and spike > threshold:
		_hit.call_deferred(spike - threshold + IMPACT_THRESHOLD)


func _hit(impulse: float) -> void:
	if hp <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_sound > 0.12 and impulse > IMPACT_THRESHOLD * 2.0:
		_last_sound = now
		Sfx.play(MATERIALS[kind].sound, linear_to_db(clamp(impulse / 900.0, 0.15, 1.0)))
	hp -= (impulse - IMPACT_THRESHOLD) * DAMAGE_PER_IMPULSE
	queue_redraw()
	if hp <= 0.0:
		broken.emit(self)
		Sfx.play("break", -4.0)
		queue_free()


func _physics_process(_delta: float) -> void:
	# Blocks knocked off the cliff are forgotten once they fall out of sight.
	if global_position.y > 1700.0 or global_position.x > 900.0 or global_position.x < -200.0:
		queue_free()


func _draw() -> void:
	var m: Dictionary = MATERIALS[kind]
	if kind == "roof":
		_draw_roof(m)
		return
	var r := Rect2(-size / 2, size)
	draw_rect(r.grow(3.5), OUTLINE)
	draw_rect(r, m.fill)
	# One soft shadow tone along the bottom and right edge.
	var shade_w: float = min(size.x, size.y) * 0.22
	draw_rect(Rect2(r.position.x, r.end.y - shade_w, r.size.x, shade_w), m.shade)
	draw_rect(Rect2(r.end.x - shade_w * 0.6, r.position.y, shade_w * 0.6, r.size.y), m.shade)
	match kind:
		"wood": _draw_grain(r, m.line)
		"stone": _draw_bricks(r, m.line)
		"ice": _draw_shine(r)
	if hp < max_hp * 0.55:
		_draw_crack(r, m.line if kind != "ice" else Color("5aa9c4"))


func _draw_grain(r: Rect2, c: Color) -> void:
	# Plank lines along the long side.
	var long_x := r.size.x >= r.size.y
	var lines := 2 if min(r.size.x, r.size.y) > 30 else 1
	for i in lines:
		var f := (i + 1.0) / (lines + 1.0)
		if long_x:
			var y := r.position.y + r.size.y * f
			draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), c, 2.0)
		else:
			var x := r.position.x + r.size.x * f
			draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4), c, 2.0)
	# A knot.
	draw_circle(r.get_center() + Vector2(r.size.x * 0.2, r.size.y * 0.2), 2.5, c)


func _draw_bricks(r: Rect2, c: Color) -> void:
	var brick := 24.0
	var rows: int = max(1, int(round(r.size.y / brick)))
	var rh := r.size.y / rows
	for row in range(1, rows):
		var y := r.position.y + row * rh
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c, 2.0)
	for row in rows:
		var y0 := r.position.y + row * rh
		var off := (brick * 0.5) if row % 2 == 1 else 0.0
		var x := r.position.x + brick + off
		while x < r.end.x - 4:
			draw_line(Vector2(x, y0), Vector2(x, y0 + rh), c, 2.0)
			x += brick * 1.5


func _draw_shine(r: Rect2) -> void:
	var a := r.position + Vector2(5, r.size.y * 0.7)
	var b := r.position + Vector2(r.size.x * 0.7, 5)
	draw_line(a, b, Color(1, 1, 1, 0.8), 3.0)


func _draw_crack(r: Rect2, c: Color) -> void:
	var p := r.get_center() + Vector2(-r.size.x * 0.3, -r.size.y * 0.3)
	var pts := PackedVector2Array([p])
	for i in 4:
		p += Vector2(r.size.x * 0.15, r.size.y * 0.15) + Vector2(6 if i % 2 == 0 else -6, 0).rotated(0.4)
		pts.append(p)
	draw_polyline(pts, OUTLINE, 3.0)


func _draw_roof(m: Dictionary) -> void:
	var pts := _roof_points()
	var grown := PackedVector2Array()
	for p in pts:
		grown.append(p * 1.0 + (p - Vector2(0, size.y / 6)).normalized() * 4.5)
	draw_colored_polygon(grown, OUTLINE)
	draw_colored_polygon(pts, m.fill)
	# Shadow half.
	draw_colored_polygon(PackedVector2Array([pts[2], pts[1], Vector2(0, size.y / 2)]), m.shade)
	# Tile stripes.
	for i in range(1, 3):
		var f := i / 3.0
		var y := -size.y / 2 + size.y * f
		var half := size.x / 2 * f
		draw_line(Vector2(-half, y), Vector2(half, y), m.line, 2.0)
	# A little flag on top.
	var top := pts[2]
	draw_line(top, top + Vector2(0, -26), OUTLINE, 3.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(1, -26), top + Vector2(20, -20), top + Vector2(1, -14)]), Color("f2e3c6"))
	draw_polyline(PackedVector2Array([top + Vector2(1, -26), top + Vector2(20, -20), top + Vector2(1, -14)]), OUTLINE, 2.0)
