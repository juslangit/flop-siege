extends Node2D
## Flop Siege — the whole game loop.
##
## The screen, top to bottom: sky; the castle on a cliff (upper right); the valley
## floor with your catapult (bottom left). Drag anywhere and let go to fling a
## floppy knight — pull back like a slingshot, the knight flies the opposite way.
## Knock the king off his tower before you run out of knights.

const OUTLINE := Color("2a2420")
const CREAM := Color("f2e3c6")
const GOLD := Color("f5c542")
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const KNIGHT := preload("res://scripts/knight.gd")
const BLOCK := preload("res://scripts/block.gd")
const KING := preload("res://scripts/king.gd")
const PAINTER := preload("res://scripts/painter.gd")

# Where things are on the 720 x 1280 screen.
const GROUND_Y := Levels.GROUND   # top of the cliff
const CLIFF_X := 300.0            # where the castle cliff's face starts
const VALLEY_Y := 1127.0          # the floor of the ravine between the two hills
const CAMP_Y := 1000.0            # top of your camp's hill (lower left)
const CAMP_EDGE := 190.0          # where the camp hill drops into the ravine
const PIVOT := Vector2(100, CAMP_Y - 57) # catapult arm pivot
const ARM_LEN := 86.0
const ARM_REST := -0.9            # radians: arm raised, bucket up and to the right
const ARM_THROWN := -1.75
# How a drag becomes a throw.
const MAX_PULL := 250.0
const POWER := 7.0
const MIN_PULL := 28.0
const RELOAD := 0.75
const MAX_KNIGHTS_LYING := 4

enum State { TITLE, PLAYING, WON, LOST }

var state := State.TITLE
var level_index := 0
var level := {}
var world: Node2D
var king: King
var knights_left := 0
var knights_lying: Array = []
var flying := 0
var reload := 0.0
var aiming := false
var aim_start := Vector2.ZERO
var aim_pull := Vector2.ZERO
var arm_angle := ARM_REST
var shake := 0.0
var level_time := 0.0
var king_low_time := 0.0
var end_timer := -1.0
var calm_time := 0.0
var best := {}
var unlocked := 1
## Checks in tools/checks/ switch this off so their test runs never touch the real save.
var saving := true
const MOAT_Y := 1072.0   # water surface in the ravine between the hills

var backdrop: Node2D
var catapult: Node2D
var aim_dots: Node2D
var moat: Node2D
var camera: Camera2D
var bg_texture: Texture2D

# HUD
var hud: CanvasLayer
var ui_theme: Theme
var top_bar: Control
var level_label: Label
var knights_row: Control
var banner: Label
var panel: PanelContainer
var panel_title: Label
var panel_text: Label
var panel_stars: Control
var panel_buttons: HBoxContainer
var title_screen: Control
var level_grid: GridContainer
var stars_shown := 0


func _ready() -> void:
	randomize()
	_load_progress()
	if ResourceLoader.exists("res://assets/art/bg-valley.png"):
		bg_texture = load("res://assets/art/bg-valley.png")
	camera = Camera2D.new()
	camera.position = Vector2(360, 640)
	add_child(camera)
	backdrop = _painter(_draw_backdrop, -10)
	_build_ground()
	world = Node2D.new()
	add_child(world)
	catapult = _painter(_draw_catapult, 3)
	aim_dots = _painter(_draw_aim, 5)
	moat = _painter(_draw_moat, 4)
	_build_hud()
	start_level(0)
	_show_title()


func _painter(fn: Callable, z: int) -> Node2D:
	var p: Node2D = PAINTER.new()
	p.paint = fn
	p.z_index = z
	add_child(p)
	return p


# --- levels -----------------------------------------------------------------

func start_level(i: int) -> void:
	level_index = i
	level = Levels.get_level(i)
	for c in world.get_children():
		c.queue_free()
	knights_lying.clear()
	flying = 0
	for spec in level.blocks:
		var b: Block = BLOCK.new()
		b.position = spec[1]
		b.setup(spec[0], spec[2])
		b.broken.connect(_on_block_broken)
		world.add_child(b)
	king = KING.new()
	king.position = level.king
	king.setup()
	king.hit_ground.connect(_on_king_flop)
	world.add_child(king)
	knights_left = level.knights
	level_time = 0.0
	king_low_time = 0.0
	end_timer = -1.0
	calm_time = 0.0
	reload = 0.0
	aiming = false
	arm_angle = ARM_REST
	state = State.PLAYING
	level_label.text = "%d. %s" % [i + 1, level.name]
	knights_row.queue_redraw()
	panel.hide()
	_show_banner("%s\n%d knights" % [level.name, level.knights])


func _on_block_broken(b: Block) -> void:
	shake = max(shake, 7.0)
	_puff(b.global_position, Block.MATERIALS[b.kind].fill, 16)


func _on_king_flop() -> void:
	if state != State.PLAYING or king.flopped:
		return
	king.set_flopped()
	Sfx.play("king")
	shake = max(shake, 10.0)
	_puff(king.global_position + Vector2(0, 20), Color("e8d9b0"), 20)
	state = State.WON
	end_timer = 1.6
	_show_banner("THE KING FLOPPED!")


func _physics_process(delta: float) -> void:
	level_time += delta
	if level_time > 0.8 and state != State.TITLE:
		for b in get_tree().get_nodes_in_group("blocks"):
			if not b.armed:
				b.arm()
		king.armed = true
	_check_splashes()
	if state == State.PLAYING and is_instance_valid(king):
		_check_king(delta)
		_check_out_of_knights(delta)
	if end_timer > 0.0:
		end_timer -= delta
		if end_timer <= 0.0:
			_end_level()


func _check_king(delta: float) -> void:
	var k := king.global_position
	if k.y > 1300.0 or k.x > 800.0 or k.x < -80.0:
		_on_king_flop()
		return
	# Knocked well down from where he started, and come to rest: that counts too.
	if k.y - king.start_y > 80.0 and king.linear_velocity.length() < 40.0:
		king_low_time += delta
		if king_low_time > 0.4:
			_on_king_flop()
	else:
		king_low_time = 0.0


func _check_out_of_knights(delta: float) -> void:
	if knights_left > 0 or flying > 0:
		calm_time = 0.0
		return
	if king.linear_velocity.length() < 15.0:
		calm_time += delta
	else:
		calm_time = 0.0
	if calm_time > 1.2:
		state = State.LOST
		Sfx.play("lose")
		end_timer = 0.6
		_show_banner("THE CASTLE HOLDS!")


func _end_level() -> void:
	if state == State.WON:
		var stars := clampi(1 + knights_left, 1, 3)
		best[level_index] = max(best.get(level_index, 0), stars)
		unlocked = max(unlocked, min(level_index + 2, Levels.count()))
		_save_progress()
		Sfx.play("win")
		var last := level_index == Levels.count() - 1
		_show_panel("THE KING FLOPPED!" if not last else "EVERY CASTLE TAKEN!",
			"%s is yours." % level.name if not last else "The king has run out of towers to sit on.",
			stars, ["NEXT" if not last else "MENU", "RETRY"])
	else:
		_show_panel("THE CASTLE HOLDS!", "The king is laughing at you.", 0, ["RETRY", "MENU"])


# --- throwing ---------------------------------------------------------------

func _bucket() -> Vector2:
	return PIVOT + Vector2.from_angle(arm_angle) * ARM_LEN


func launch_point() -> Vector2:
	return PIVOT + Vector2.from_angle(ARM_REST) * ARM_LEN + Vector2(0, -22)


func throw_velocity(pull: Vector2) -> Vector2:
	return pull.limit_length(MAX_PULL) * POWER


func can_throw() -> bool:
	return state == State.PLAYING and knights_left > 0 and reload <= 0.0


func throw_knight(velocity: Vector2) -> void:
	var k: Knight = KNIGHT.new()
	world.add_child(k)
	k.build(launch_point(), level.knights - knights_left)
	k.launch(velocity)
	k.settled.connect(_on_knight_settled)
	knights_left -= 1
	flying += 1
	reload = RELOAD
	knights_row.queue_redraw()
	Sfx.play("launch")
	Sfx.play("hup", -3.0, randf_range(0.9, 1.25))
	var tw := create_tween()
	tw.tween_method(_set_arm, arm_angle, ARM_THROWN, 0.09)
	tw.tween_method(_set_arm, ARM_THROWN, ARM_REST, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_arm(a: float) -> void:
	arm_angle = a
	catapult.queue_redraw()


func _on_knight_settled(k: Knight) -> void:
	flying = max(0, flying - 1)
	knights_lying.append(k)
	while knights_lying.size() > MAX_KNIGHTS_LYING:
		var old: Knight = knights_lying.pop_front()
		if is_instance_valid(old):
			old.retire()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			if can_throw():
				aiming = true
				aim_start = event.position
				aim_pull = Vector2.ZERO
				Sfx.play("creak", -8.0)
		elif aiming:
			aiming = false
			if aim_pull.length() >= MIN_PULL and can_throw():
				throw_knight(throw_velocity(aim_pull))
			else:
				_set_arm(ARM_REST)
			aim_dots.queue_redraw()
	elif event is InputEventScreenDrag and event.index == 0 and aiming:
		aim_pull = (aim_start - event.position).limit_length(MAX_PULL)
		# Pulling back tips the arm down, like loading a real catapult.
		_set_arm(ARM_REST + 0.8 * aim_pull.length() / MAX_PULL)
		aim_dots.queue_redraw()


func _process(delta: float) -> void:
	reload = max(0.0, reload - delta)
	shake = move_toward(shake, 0.0, delta * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	catapult.queue_redraw()
	moat.queue_redraw()


# --- effects ----------------------------------------------------------------

func _puff(at: Vector2, colour: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = 4
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 280.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 5.0
	p.scale_amount_max = 11.0
	p.color = colour
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# --- the world: cliff, valley, catapult ---------------------------------------

func _build_ground() -> void:
	var ground := StaticBody2D.new()
	ground.add_to_group("ground")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	ground.physics_material_override = pm
	var cliff := CollisionPolygon2D.new()
	cliff.polygon = PackedVector2Array([Vector2(CLIFF_X, GROUND_Y), Vector2(1000, GROUND_Y),
		Vector2(1000, VALLEY_Y), Vector2(CLIFF_X - 24, VALLEY_Y)])
	ground.add_child(cliff)
	var valley := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(1600, 400)
	valley.shape = r
	valley.position = Vector2(360, VALLEY_Y + 200)
	ground.add_child(valley)
	var camp := CollisionPolygon2D.new()
	camp.polygon = _camp_points()
	ground.add_child(camp)
	# An invisible wall off the left edge, so knights bounce back into view.
	var wall := CollisionShape2D.new()
	var wr := RectangleShape2D.new()
	wr.size = Vector2(100, 2400)
	wall.shape = wr
	wall.position = Vector2(-50, 0)
	ground.add_child(wall)
	add_child(ground)


func _camp_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-200, CAMP_Y), Vector2(CAMP_EDGE, CAMP_Y),
		Vector2(CAMP_EDGE + 22, VALLEY_Y), Vector2(-200, VALLEY_Y)])


func _draw_hill(c: Node2D, pts: PackedVector2Array, top_y: float, x0: float, x1: float) -> void:
	# Earth with an outline, strata lines and a grass cap along the top.
	var centre := Vector2.ZERO
	for p in pts:
		centre += p
	centre /= pts.size()
	var ol := PackedVector2Array()
	for p in pts:
		ol.append(p + (p - centre).normalized() * 5.0)
	c.draw_colored_polygon(ol, OUTLINE)
	c.draw_colored_polygon(pts, Color("c49364"))
	for i in 7:
		var y := top_y + 60 + i * 55
		var sx := x0 + 20 + (i % 2) * 60
		while sx < x1 - 60:
			c.draw_line(Vector2(sx, y), Vector2(sx + 110, y + 8), Color("9c6f47"), 4)
			sx += 230
	c.draw_rect(Rect2(x0 - 4, top_y - 6, x1 - x0 + 8, 26), OUTLINE)
	c.draw_rect(Rect2(x0, top_y - 2, x1 - x0, 18), Color("7cc05a"))
	var x := x0 + 10
	while x < x1 - 20:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, top_y + 16), Vector2(x + 10, top_y + 30), Vector2(x + 20, top_y + 16)]), Color("7cc05a"))
		x += 42


func _draw_backdrop(c: Node2D) -> void:
	# Sky, top to bottom, with extra above and below for tall phones.
	var sky_top := Color("7ec4e6")
	var sky_low := Color("d9f0f5")
	c.draw_polygon(PackedVector2Array([Vector2(-200, -700), Vector2(920, -700), Vector2(920, 1000), Vector2(-200, 1000)]),
		PackedColorArray([sky_top, sky_top, sky_low, sky_low]))
	if bg_texture:
		c.draw_texture_rect(bg_texture, Rect2(0, 0, 720, 1280), false)
		c.draw_rect(Rect2(-200, 1270, 1120, 800), Color("6fae4f"))
		return
	# Sun and clouds.
	c.draw_circle(Vector2(600, 150), 58, Color("fff3c4"))
	c.draw_circle(Vector2(600, 150), 46, Color("ffe07a"))
	for cl in [[Vector2(140, 210), 1.0], [Vector2(420, 90), 0.8], [Vector2(250, 470), 0.7]]:
		_cloud(c, cl[0], cl[1])
	# Far hills.
	var hills := PackedVector2Array([Vector2(-200, 1000)])
	for i in 13:
		var x := -200.0 + i * 95.0
		hills.append(Vector2(x, 780 + sin(i * 1.3) * 60 - (i % 3) * 20))
	hills.append(Vector2(920, 1000))
	c.draw_colored_polygon(hills, Color("a9cf9a"))
	# The ravine floor between the two hills.
	c.draw_rect(Rect2(-200, VALLEY_Y, 1120, 900), Color("6fae4f"))
	c.draw_rect(Rect2(-200, VALLEY_Y - 4, 1120, 8), OUTLINE)
	c.draw_rect(Rect2(-200, VALLEY_Y + 4, 1120, 16), Color("86c461"))
	# The castle's cliff (right) and your camp's hill (left).
	_draw_hill(c, PackedVector2Array([Vector2(CLIFF_X, GROUND_Y), Vector2(1000, GROUND_Y),
		Vector2(1000, VALLEY_Y), Vector2(CLIFF_X - 24, VALLEY_Y)]), GROUND_Y, CLIFF_X, 1000)
	_draw_hill(c, _camp_points(), CAMP_Y, -200, CAMP_EDGE)
	_tent(c, Vector2(12, CAMP_Y), Color("e86a3a"))


func _cloud(c: Node2D, at: Vector2, s: float) -> void:
	for pass_i in 2:
		var col := OUTLINE if pass_i == 0 else Color.WHITE
		var g := 4.0 if pass_i == 0 else 0.0
		for blob in [[Vector2(-40, 8), 26], [Vector2(-8, -10), 34], [Vector2(30, 4), 28], [Vector2(0, 14), 26]]:
			c.draw_circle(at + blob[0] * s, blob[1] * s + g, col)


func _tent(c: Node2D, at: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(-40, 0), at + Vector2(0, -62), at + Vector2(40, 0)])
	var ol := PackedVector2Array([at + Vector2(-46, 3), at + Vector2(0, -69), at + Vector2(46, 3)])
	c.draw_colored_polygon(ol, OUTLINE)
	c.draw_colored_polygon(pts, col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 0), at + Vector2(0, -26), at + Vector2(10, 0)]), OUTLINE)
	c.draw_line(at + Vector2(0, -62), at + Vector2(0, -84), OUTLINE, 3)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(1, -84), at + Vector2(18, -78), at + Vector2(1, -72)]), CREAM)


func _draw_moat(c: Node2D) -> void:
	# Drawn in front of the knights, so a short throw sinks into the moat.
	var w := Rect2(CAMP_EDGE, MOAT_Y, CLIFF_X - CAMP_EDGE + 10, VALLEY_Y - MOAT_Y + 20)
	c.draw_rect(w, Color(0.3, 0.62, 0.85, 0.85))
	c.draw_line(Vector2(w.position.x, MOAT_Y), Vector2(w.end.x, MOAT_Y), OUTLINE, 4)
	var t := Time.get_ticks_msec() / 1000.0
	for i in 3:
		var x := w.position.x + 16 + i * 36 + sin(t * 2.0 + i) * 6
		c.draw_arc(Vector2(x, MOAT_Y + 18 + i * 10), 7, PI * 0.1, PI * 0.9, 6, Color(1, 1, 1, 0.7), 2.5)


func _check_splashes() -> void:
	for k in world.get_children():
		if k is Knight and not k.splashed:
			var c: Vector2 = k.centre()
			if c.y > MOAT_Y and c.x > CAMP_EDGE and c.x < CLIFF_X:
				k.splashed = true
				Sfx.play("splash")
				_puff(Vector2(c.x, MOAT_Y), Color("bfe6f5"), 18)


func _draw_catapult(c: Node2D) -> void:
	var base_y := CAMP_Y
	# Frame and wheels.
	var frame := Rect2(PIVOT.x - 62, base_y - 34, 124, 18)
	c.draw_rect(frame.grow(3.5), OUTLINE)
	c.draw_rect(frame, Color("b07a45"))
	c.draw_colored_polygon(PackedVector2Array([PIVOT + Vector2(-30, 40), PIVOT + Vector2(-6, -6),
		PIVOT + Vector2(6, -6), PIVOT + Vector2(30, 40)]), OUTLINE)
	c.draw_colored_polygon(PackedVector2Array([PIVOT + Vector2(-23, 38), PIVOT + Vector2(-3, 0),
		PIVOT + Vector2(3, 0), PIVOT + Vector2(23, 38)]), Color("d9a066"))
	for wx in [PIVOT.x - 42, PIVOT.x + 42]:
		c.draw_circle(Vector2(wx, base_y - 14), 18, OUTLINE)
		c.draw_circle(Vector2(wx, base_y - 14), 13, Color("8a5a30"))
		c.draw_circle(Vector2(wx, base_y - 14), 4, OUTLINE)
	# The throwing arm and its bucket.
	var tip := _bucket()
	c.draw_line(PIVOT, tip, OUTLINE, 16)
	c.draw_line(PIVOT, tip, Color("d9a066"), 9)
	c.draw_circle(PIVOT, 9, OUTLINE)
	c.draw_circle(PIVOT, 5, GOLD)
	var n := Vector2.from_angle(arm_angle)
	var side := n.orthogonal()
	var cup := PackedVector2Array([tip + side * 20 - n * 4, tip - side * 20 - n * 4,
		tip - side * 16 + n * 12, tip + side * 16 + n * 12])
	c.draw_colored_polygon(cup, OUTLINE)
	c.draw_colored_polygon(PackedVector2Array([cup[0] + (tip - cup[0]) * 0.2, cup[1] + (tip - cup[1]) * 0.2,
		cup[2] + (tip - cup[2]) * 0.2, cup[3] + (tip - cup[3]) * 0.2]), Color("8a5a30"))
	# The next knight, waiting in the bucket.
	if state == State.PLAYING and knights_left > 0 and reload <= 0.0:
		var h := tip + Vector2(0, -24)
		c.draw_circle(h, 16.5, OUTLINE)
		c.draw_circle(h, 13, Color("cfd8e0"))
		c.draw_rect(Rect2(h.x - 9, h.y - 3, 18, 6), OUTLINE)
		c.draw_circle(h + Vector2(0, -16), 6, Knight.TABARDS[(level.knights - knights_left) % Knight.TABARDS.size()])


func _draw_aim(c: Node2D) -> void:
	if not aiming or aim_pull.length() < MIN_PULL * 0.5:
		return
	# A short dotted arc showing where the knight will head — only the start of it.
	var v := throw_velocity(aim_pull)
	var g := Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))
	var p0 := launch_point()
	for i in range(1, 15):
		var t := i * 0.045
		var p := p0 + v * t + 0.5 * g * t * t
		var a := 1.0 - i / 16.0
		c.draw_circle(p, 8.0 - i * 0.3, Color(OUTLINE, a))
		c.draw_circle(p, 5.0 - i * 0.2, Color(1, 1, 1, a))
	# How hard you are pulling, 0..100%.
	var f := aim_pull.length() / MAX_PULL
	var bar := Rect2(PIVOT.x - 60, CAMP_Y + 34, 120, 18)
	c.draw_rect(bar.grow(3), OUTLINE)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), GOLD.lerp(Color("e86a3a"), f))


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	ui_theme = Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 40
	ui_theme.set_color("font_color", "Label", Color.WHITE)
	ui_theme.set_color("font_outline_color", "Label", OUTLINE)
	ui_theme.set_constant("outline_size", "Label", 14)
	ui_theme.set_stylebox("normal", "Button", _box(GOLD, 16))
	ui_theme.set_stylebox("hover", "Button", _box(GOLD.lightened(0.15), 16))
	ui_theme.set_stylebox("pressed", "Button", _box(GOLD.darkened(0.2), 16))
	ui_theme.set_stylebox("disabled", "Button", _box(Color("b9ae98"), 16))
	ui_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ui_theme.set_color(s, "Button", OUTLINE)
	ui_theme.set_color("font_disabled_color", "Button", Color("7a705e"))
	ui_theme.set_font_size("font_size", "Button", 44)
	ui_theme.set_stylebox("panel", "PanelContainer", _box(CREAM, 26, 7))

	var root := Control.new()
	root.theme = ui_theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	# Top bar: level name, knights left, retry.
	top_bar = Control.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 150)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)
	level_label = Label.new()
	level_label.position = Vector2(24, 26)
	level_label.add_theme_font_size_override("font_size", 38)
	top_bar.add_child(level_label)
	knights_row = Control.new()
	knights_row.position = Vector2(24, 86)
	knights_row.size = Vector2(420, 50)
	knights_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knights_row.draw.connect(_draw_knights_row)
	top_bar.add_child(knights_row)
	var retry := _button("", func(): _click(); start_level(level_index), Vector2(96, 96))
	retry.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	retry.position = Vector2(-120, 24)
	retry.draw.connect(_draw_retry_icon.bind(retry))
	top_bar.add_child(retry)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(-340, 250)
	banner.size = Vector2(680, 200)
	banner.add_theme_font_size_override("font_size", 64)
	banner.add_theme_constant_override("outline_size", 20)
	banner.modulate.a = 0.0
	root.add_child(banner)

	# End-of-level card.
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 0)
	panel.position = Vector2(-300, -260)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	panel_title = Label.new()
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.add_theme_font_size_override("font_size", 56)
	col.add_child(panel_title)
	panel_stars = Control.new()
	panel_stars.custom_minimum_size = Vector2(0, 110)
	panel_stars.draw.connect(_draw_panel_stars)
	col.add_child(panel_stars)
	panel_text = Label.new()
	panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_text.add_theme_font_size_override("font_size", 34)
	panel_text.add_theme_color_override("font_color", OUTLINE)
	panel_text.add_theme_constant_override("outline_size", 0)
	col.add_child(panel_text)
	panel_buttons = HBoxContainer.new()
	panel_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_buttons.add_theme_constant_override("separation", 24)
	col.add_child(panel_buttons)
	panel.hide()

	_build_title(root)


func _box(fill: Color, radius: int, border := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = OUTLINE
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(22)
	s.shadow_color = Color(OUTLINE, 0.35)
	s.shadow_offset = Vector2(0, 6)
	s.shadow_size = 1
	return s


func _button(text: String, on_press: Callable, min_size := Vector2(220, 100)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b


func _click() -> void:
	Sfx.play("click")


func _build_title(root: Control) -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_screen)
	var shade := ColorRect.new()
	shade.color = Color(OUTLINE, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 26)
	title_screen.add_child(col)
	var title := Label.new()
	title.text = "FLOP\nSIEGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 150)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_constant_override("outline_size", 34)
	title.add_theme_constant_override("line_spacing", -40)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Knock the king off his tower!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 40)
	col.add_child(sub)
	var play_row := CenterContainer.new()
	col.add_child(play_row)
	var play := _button("PLAY", func(): _click(); _hide_title(); start_level(min(unlocked - 1, Levels.count() - 1)), Vector2(340, 124))
	play.add_theme_font_size_override("font_size", 64)
	play_row.add_child(play)
	var grid_row := CenterContainer.new()
	col.add_child(grid_row)
	level_grid = GridContainer.new()
	level_grid.columns = 4
	level_grid.add_theme_constant_override("h_separation", 18)
	level_grid.add_theme_constant_override("v_separation", 18)
	grid_row.add_child(level_grid)
	var hint := Label.new()
	hint.text = "Drag back anywhere and let go to fling a knight"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 30)
	col.add_child(hint)


func _show_title() -> void:
	state = State.TITLE
	panel.hide()
	top_bar.hide()
	title_screen.show()
	for c in level_grid.get_children():
		c.queue_free()
	for i in Levels.count():
		var s: int = best.get(i, 0)
		var b := _button(str(i + 1), func(): _click(); _hide_title(); start_level(i), Vector2(120, 120))
		b.add_theme_font_size_override("font_size", 48)
		b.disabled = i >= unlocked
		if s > 0:
			b.draw.connect(_draw_grid_stars.bind(b, s))
		level_grid.add_child(b)


func _hide_title() -> void:
	title_screen.hide()
	top_bar.show()


func _show_banner(text: String) -> void:
	banner.text = text
	var tw := create_tween()
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.7, 0.7)
	banner.pivot_offset = banner.size / 2
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.3)


func _show_panel(title: String, text: String, stars: int, buttons: Array) -> void:
	panel_title.text = title
	panel_text.text = text
	stars_shown = stars
	panel_stars.visible = stars > 0
	panel_stars.queue_redraw()
	for c in panel_buttons.get_children():
		c.queue_free()
	for name in buttons:
		var b := _button(name, _on_panel_button.bind(name))
		panel_buttons.add_child(b)
	panel.show()
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_panel_button(name: String) -> void:
	_click()
	match name:
		"NEXT": start_level(level_index + 1)
		"RETRY": start_level(level_index)
		"MENU":
			start_level(level_index)
			_show_title()


func _draw_knights_row() -> void:
	if level.is_empty():
		return
	for i in level.knights:
		var h := Vector2(22 + i * 50, 22)
		var left: bool = i >= level.knights - knights_left
		var a := 1.0 if left else 0.25
		knights_row.draw_circle(h, 20, Color(OUTLINE, a))
		knights_row.draw_circle(h, 16, Color(Color("cfd8e0"), a))
		knights_row.draw_rect(Rect2(h.x - 11, h.y - 3, 22, 6), Color(OUTLINE, a))
		knights_row.draw_circle(h + Vector2(0, -19), 7, Color(Knight.TABARDS[i % Knight.TABARDS.size()], a))


func _draw_panel_stars() -> void:
	var w := panel_stars.size.x
	for i in 3:
		var centre := Vector2(w / 2 + (i - 1) * 120, 55 - (12 if i == 1 else 0))
		var fill := GOLD if i < stars_shown else Color("d8ccb4")
		_star(panel_stars, centre, 50 if i == 1 else 42, fill)


func _draw_retry_icon(b: Button) -> void:
	# A circular arrow: "try this castle again".
	var c := b.size / 2
	b.draw_arc(c, 24, 0.5, TAU - 0.3, 24, OUTLINE, 9)
	var tip := c + Vector2.from_angle(0.5) * 24
	b.draw_colored_polygon(PackedVector2Array([tip + Vector2(-14, -4), tip + Vector2(10, -6), tip + Vector2(2, 16)]), OUTLINE)


func _draw_grid_stars(b: Button, n: int) -> void:
	for i in 3:
		_star(b, Vector2(b.size.x / 2 + (i - 1) * 30, b.size.y - 20), 11, GOLD if i < n else Color("b9ae98"), 3.5)


func _star(c: CanvasItem, at: Vector2, r: float, fill: Color, edge := 7.0) -> void:
	var pts := PackedVector2Array()
	var ol := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(at + Vector2.from_angle(ang) * rr)
		ol.append(at + Vector2.from_angle(ang) * (rr + edge))
	c.draw_colored_polygon(ol, OUTLINE)
	c.draw_colored_polygon(pts, fill)


# --- saving -----------------------------------------------------------------

func _load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://progress.cfg") == OK:
		unlocked = cf.get_value("progress", "unlocked", 1)
		best = cf.get_value("progress", "best", {})


func _save_progress() -> void:
	if not saving:
		return
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "best", best)
	cf.save("user://progress.cfg")
