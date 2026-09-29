extends RigidBody2D
## One piece of a floppy knight — body, head, arm or leg. Pieces are pinned
## together at the joints by knight.gd; this only draws the piece.

const OUTLINE := Color("2a2420")
const ARMOUR := Color("cfd8e0")
const ARMOUR_SHADE := Color("9aa8b5")

var kind := "torso"   # torso, head, arm, leg
var size := Vector2(26, 34)
var tabard := Color("3a7bd5")
var dazed := false


func _draw() -> void:
	match kind:
		"torso": _draw_torso()
		"head": _draw_head()
		"arm": _draw_limb(ARMOUR)
		"leg": _draw_limb(Color("5b4a3c"))


func _draw_torso() -> void:
	var r := Rect2(-size / 2, size)
	draw_rect(r.grow(3.5), OUTLINE)
	draw_rect(r, ARMOUR)
	# Tabard over the armour, with a cross on it.
	var t := Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, r.size.y - 6)
	draw_rect(t, tabard)
	draw_rect(Rect2(t.get_center().x - 2.5, t.position.y + 3, 5, t.size.y - 10), Color("f2e3c6"))
	draw_rect(Rect2(t.position.x + 3, t.position.y + 9, t.size.x - 6, 5), Color("f2e3c6"))
	# Belt.
	draw_rect(Rect2(r.position.x, r.end.y - 9, r.size.x, 5), OUTLINE)


func _draw_head() -> void:
	var rad := size.x
	# Plume.
	draw_circle(Vector2(0, -rad - 3), 8.5, OUTLINE)
	draw_circle(Vector2(0, -rad - 3), 6.0, tabard)
	# Bucket helmet.
	draw_circle(Vector2.ZERO, rad + 3.5, OUTLINE)
	draw_circle(Vector2.ZERO, rad, ARMOUR)
	draw_circle(Vector2(rad * 0.3, rad * 0.3), rad * 0.55, ARMOUR_SHADE)
	draw_circle(Vector2(-rad * 0.1, -rad * 0.1), rad * 0.8, ARMOUR)
	# Visor slit — or dizzy eyes once the knight has landed.
	if dazed:
		for x in [-5.0, 5.0]:
			draw_line(Vector2(x - 3, -3), Vector2(x + 3, 3), OUTLINE, 2.5)
			draw_line(Vector2(x - 3, 3), Vector2(x + 3, -3), OUTLINE, 2.5)
	else:
		draw_rect(Rect2(-rad * 0.75, -3, rad * 1.5, 6), OUTLINE)


func _draw_limb(c: Color) -> void:
	var w := size.x / 2
	var h := size.y / 2 - w
	draw_circle(Vector2(0, -h), w + 3, OUTLINE)
	draw_circle(Vector2(0, h), w + 3, OUTLINE)
	draw_rect(Rect2(-w - 3, -h, (w + 3) * 2, h * 2), OUTLINE)
	draw_circle(Vector2(0, -h), w, c)
	draw_circle(Vector2(0, h), w, c)
	draw_rect(Rect2(-w, -h, w * 2, h * 2), c)
