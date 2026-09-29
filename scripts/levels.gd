class_name Levels
## Every castle in the game, written as a short building recipe.
## The cliff top is at y = GROUND; x runs 0 (left) to 720 (right edge of the phone).
## A level is {name, knights, blocks: [[kind, centre, size], ...], king: Vector2}.

const GROUND := 717.0
const POST := 20.0
const BEAM := 20.0


static func count() -> int:
	return 8


static func get_level(i: int) -> Dictionary:
	match i:
		# Ordered easiest to hardest by tools/checks/solve_check.gd.
		0: return _wooden_fort()
		1: return _tall_tower()
		2: return _gatehouse()
		3: return _ice_palace()
		4: return _twin_towers()
		5: return _stone_keep()
		6: return _great_wall()
		_: return _royal_keep()


# --- building helpers -------------------------------------------------------

static func _block(b: Array, kind: String, centre: Vector2, size: Vector2) -> void:
	b.append([kind, centre, size])


## A single upright post standing on `bottom`.
static func _post(b: Array, kind: String, x: float, bottom: float, h: float, w := POST) -> void:
	_block(b, kind, Vector2(x, bottom - h / 2), Vector2(w, h))


## A flat beam lying on `bottom`.
static func _beam(b: Array, kind: String, x: float, bottom: float, w: float, h := BEAM) -> void:
	_block(b, kind, Vector2(x, bottom - h / 2), Vector2(w, h))


## Two posts with a beam across the top. Returns the height of the beam's top surface.
static func _frame(b: Array, post_kind: String, beam_kind: String, x: float, bottom: float,
		width: float, height: float, post_w := POST) -> float:
	_post(b, post_kind, x - width / 2 + post_w / 2, bottom, height, post_w)
	_post(b, post_kind, x + width / 2 - post_w / 2, bottom, height, post_w)
	_beam(b, beam_kind, x, bottom - height, width + 10)
	return bottom - height - BEAM


static func _roof(b: Array, x: float, bottom: float, w: float, h: float) -> void:
	# A cone's centre sits one third of the way up, where its weight is.
	_block(b, "roof", Vector2(x, bottom - h / 2), Vector2(w, h))


static func _king_on(bottom: float, x: float) -> Vector2:
	return Vector2(x, bottom - 25.0)


# --- the castles ------------------------------------------------------------

static func _wooden_fort() -> Dictionary:
	var b := []
	var top := _frame(b, "wood", "wood", 500, GROUND, 130, 150)
	return {"name": "The Wooden Fort", "knights": 3, "blocks": b, "king": _king_on(top, 500)}


static func _gatehouse() -> Dictionary:
	var b := []
	var top := _frame(b, "wood", "wood", 500, GROUND, 190, 120)
	top = _frame(b, "wood", "wood", 500, top, 120, 90)
	_post(b, "wood", 385, GROUND, 60, 40)
	_roof(b, 385, GROUND - 60, 50, 50)
	_post(b, "wood", 640, GROUND, 60, 40)
	_roof(b, 640, GROUND - 60, 50, 50)
	return {"name": "The Gatehouse", "knights": 3, "blocks": b, "king": _king_on(top, 500)}


static func _stone_keep() -> Dictionary:
	var b := []
	var lt := _frame(b, "stone", "wood", 375, GROUND, 80, 100, 24)
	_roof(b, 375, lt, 90, 70)
	var rt := _frame(b, "stone", "wood", 635, GROUND, 80, 100, 24)
	_roof(b, 635, rt, 90, 70)
	var top := _frame(b, "stone", "wood", 505, GROUND, 130, 140, 24)
	top = _frame(b, "wood", "wood", 505, top, 100, 80)
	return {"name": "The Stone Keep", "knights": 4, "blocks": b, "king": _king_on(top, 505)}


static func _tall_tower() -> Dictionary:
	var b := []
	var top := GROUND
	var kinds := ["stone", "wood", "stone", "wood"]
	for i in 4:
		top = _frame(b, kinds[i], "wood", 530, top, 96, 95, 22 if kinds[i] == "stone" else 20)
	_post(b, "stone", 420, GROUND, 50, 50)
	_post(b, "stone", 640, GROUND, 50, 50)
	return {"name": "The Tall Tower", "knights": 4, "blocks": b, "king": _king_on(top, 530)}


static func _ice_palace() -> Dictionary:
	var b := []
	var lt := _frame(b, "ice", "ice", 370, GROUND, 80, 130)
	_roof(b, 370, lt, 80, 60)
	var rt := _frame(b, "ice", "ice", 640, GROUND, 80, 130)
	_roof(b, 640, rt, 80, 60)
	var top := _frame(b, "ice", "stone", 505, GROUND, 120, 110)
	top = _frame(b, "ice", "ice", 505, top, 120, 90)
	return {"name": "The Ice Palace", "knights": 4, "blocks": b, "king": _king_on(top, 505)}


static func _great_wall() -> Dictionary:
	var b := []
	# A thick wall in front: you have to lob over it, or knock it down.
	_post(b, "stone", 330, GROUND, 110, 44)
	_post(b, "stone", 330, GROUND - 110, 70, 44)
	_roof(b, 330, GROUND - 180, 56, 44)
	var top := _frame(b, "stone", "wood", 560, GROUND, 150, 110, 24)
	top = _frame(b, "wood", "wood", 560, top, 110, 90)
	return {"name": "The Great Wall", "knights": 4, "blocks": b, "king": _king_on(top, 560)}


static func _twin_towers() -> Dictionary:
	var b := []
	var lt := _frame(b, "stone", "stone", 370, GROUND, 70, 120, 24)
	lt = _frame(b, "wood", "wood", 370, lt, 70, 90)
	var rt := _frame(b, "stone", "stone", 640, GROUND, 70, 120, 24)
	rt = _frame(b, "wood", "wood", 640, rt, 70, 90)
	# A long bridge between the two tops, with the king in the middle of it.
	_beam(b, "wood", 505, lt, 320)
	var bridge := lt - BEAM
	_post(b, "wood", 440, bridge, 40, 20)
	_post(b, "wood", 570, bridge, 40, 20)
	return {"name": "The Twin Towers", "knights": 5, "blocks": b, "king": _king_on(bridge, 505)}


static func _royal_keep() -> Dictionary:
	var b := []
	var lt := _frame(b, "stone", "stone", 350, GROUND, 70, 140, 24)
	_roof(b, 350, lt, 80, 70)
	var rt := _frame(b, "stone", "stone", 660, GROUND, 70, 140, 24)
	_roof(b, 660, rt, 80, 70)
	var top := _frame(b, "stone", "stone", 505, GROUND, 170, 120, 26)
	top = _frame(b, "stone", "wood", 505, top, 140, 100, 24)
	top = _frame(b, "ice", "wood", 505, top, 100, 80)
	return {"name": "The Royal Keep", "knights": 6, "blocks": b, "king": _king_on(top, 505)}
