extends Node2D
## Prototype "greybox" de la phase de NUIT du Phare des Échos.
##
## Tout est dessiné avec des formes simples (cercles, triangles) dans _draw(),
## pour tester le gameplay avant de faire de vrais graphismes.
##
## Règles :
## - Le rayon du phare suit la souris (ou les flèches gauche/droite).
## - Un bateau éclairé voit les rochers : il les évite et file vers le port.
## - Un bateau dans le noir dérive au gré du vent de la tempête.
## - Les rochers ne se voient que dans la lumière... ou pendant un éclair.
## - Victoire : tous les bateaux sont arrivés ou perdus, avec moins de
##   MAX_WRECKS naufrages. Défaite : MAX_WRECKS naufrages.

# --- Réglages : change ces valeurs pour ajuster la difficulté ---------------
const SCREEN := Vector2(1280, 720)
const LIGHTHOUSE_POS := Vector2(640, 680)
const BEAM_LENGTH := 950.0
const BEAM_HALF_ANGLE := 0.19          # demi-ouverture du rayon, en radians (~11°)
const BEAM_TURN_SPEED := 1.8           # vitesse max de rotation du rayon (rad/s)
const HALO_RADIUS := 110.0             # petite zone toujours éclairée autour du phare
const HARBOR := Rect2(1050, 590, 210, 115)
const SHIP_COUNT := 4
const SHIP_SPEED := 38.0
const SHIP_TURN_SPEED := 1.6           # vitesse de virage d'un bateau éclairé
const SHIP_RADIUS := 9.0
const SPAWN_INTERVAL := 7.0            # secondes entre deux bateaux
const MAX_WRECKS := 2                  # nombre de naufrages = défaite
const INTRO_DURATION := 7.0


class Rock:
	var pos: Vector2
	var radius: float
	var always_visible: bool

	func _init(p: Vector2, r: float, visible_always: bool = false) -> void:
		pos = p
		radius = r
		always_visible = visible_always


class Ship:
	var pos: Vector2
	var heading: float                 # direction en radians
	var state: String = "sailing"      # "sailing", "saved" ou "wrecked"
	var lit: bool = false
	var wander: float = 0.0            # dérive aléatoire quand il fait noir


var rocks: Array[Rock] = []
var ships: Array[Ship] = []
var rain: Array[Vector2] = []
var rng := RandomNumberGenerator.new()

var beam_angle := -PI / 2.0
var use_mouse := true
var spawned := 0
var spawn_timer := 1.5
var saved := 0
var wrecked := 0
var game_over := false
var won := false
var elapsed := 0.0

var wind := Vector2.ZERO
var wind_target := Vector2.ZERO
var wind_timer := 0.0
var lightning := 0.0                   # 1 = flash, puis redescend à 0
var lightning_timer := 4.0


func _ready() -> void:
	rng.randomize()
	_build_rocks()
	for i in 220:
		rain.append(Vector2(rng.randf() * SCREEN.x, rng.randf() * SCREEN.y))


func _build_rocks() -> void:
	# L'îlot du phare : toujours visible, et dangereux lui aussi.
	rocks.append(Rock.new(LIGHTHOUSE_POS, 46.0, true))
	# Les récifs, placés à la main pour que le niveau soit toujours le même.
	var layout := [
		Vector3(300, 240, 28), Vector3(530, 320, 34), Vector3(770, 250, 30),
		Vector3(990, 370, 36), Vector3(640, 470, 26), Vector3(870, 540, 28),
		Vector3(420, 520, 32), Vector3(1160, 290, 26), Vector3(190, 440, 24),
		Vector3(1110, 480, 22),
	]
	for v: Vector3 in layout:
		rocks.append(Rock.new(Vector2(v.x, v.y), v.z))


# --- Boucle de jeu ------------------------------------------------------------

func _process(delta: float) -> void:
	elapsed += delta
	_update_beam(delta)
	_update_weather(delta)
	if not game_over:
		_update_spawning(delta)
		for ship in ships:
			if ship.state == "sailing":
				_update_ship(ship, delta)
		_check_end()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		use_mouse = true
	if not game_over or not event.is_pressed():
		return
	var restart := event is InputEventMouseButton
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_R:
		restart = true
	if restart:
		get_tree().reload_current_scene()


func _update_beam(delta: float) -> void:
	var key_dir := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		key_dir -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		key_dir += 1.0

	if key_dir != 0.0:
		use_mouse = false
		beam_angle += key_dir * BEAM_TURN_SPEED * delta
	elif use_mouse:
		# Le rayon tourne vers la souris, mais pas plus vite que BEAM_TURN_SPEED.
		var target := (get_global_mouse_position() - LIGHTHOUSE_POS).angle()
		var diff := wrapf(target - beam_angle, -PI, PI)
		var step := BEAM_TURN_SPEED * delta
		beam_angle += clampf(diff, -step, step)
	beam_angle = wrapf(beam_angle, -PI, PI)


func _update_weather(delta: float) -> void:
	# Le vent change de direction toutes les quelques secondes.
	wind_timer -= delta
	if wind_timer <= 0.0:
		wind_target = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 28.0)
		wind_timer = rng.randf_range(3.0, 6.0)
	wind = wind.lerp(wind_target, clampf(delta * 0.6, 0.0, 1.0))

	# Éclairs.
	lightning = maxf(lightning - delta * 2.2, 0.0)
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		lightning = 1.0
		lightning_timer = rng.randf_range(6.0, 11.0)

	# Pluie.
	var fall := Vector2(wind.x * 8.0, 520.0) * delta
	for i in rain.size():
		var drop := rain[i] + fall
		if drop.y > SCREEN.y:
			drop.y -= SCREEN.y + 20.0
		drop.x = fposmod(drop.x, SCREEN.x)
		rain[i] = drop


func _update_spawning(delta: float) -> void:
	if spawned >= SHIP_COUNT:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var ship := Ship.new()
		ship.pos = Vector2(rng.randf_range(120.0, 860.0), -20.0)
		ship.heading = PI / 2.0 + rng.randf_range(-0.4, 0.4)
		ships.append(ship)
		spawned += 1
		spawn_timer = SPAWN_INTERVAL


func _update_ship(ship: Ship, delta: float) -> void:
	ship.lit = is_lit(ship.pos)
	var velocity: Vector2

	if ship.lit:
		# Éclairé : le capitaine voit les rochers, il les évite et vise le port.
		var desired := (HARBOR.get_center() - ship.pos).normalized()
		for rock in rocks:
			var away := ship.pos - rock.pos
			var dist := away.length()
			var danger := rock.radius + 80.0
			if dist < danger and dist > 0.01:
				desired += away / dist * (danger - dist) / 40.0
		var diff := wrapf(desired.angle() - ship.heading, -PI, PI)
		var step := SHIP_TURN_SPEED * delta
		ship.heading += clampf(diff, -step, step)
		velocity = Vector2.from_angle(ship.heading) * SHIP_SPEED + wind * 0.3
	else:
		# Dans le noir : le bateau dérive et le vent le pousse.
		ship.wander = clampf(ship.wander + rng.randf_range(-1.5, 1.5) * delta, -0.8, 0.8)
		ship.heading += ship.wander * delta
		velocity = Vector2.from_angle(ship.heading) * SHIP_SPEED * 0.8 + wind

	ship.pos += velocity * delta
	ship.heading = wrapf(ship.heading, -PI, PI)
	_keep_on_screen(ship)

	for rock in rocks:
		if ship.pos.distance_to(rock.pos) < rock.radius + SHIP_RADIUS:
			ship.state = "wrecked"
			wrecked += 1
			return
	if HARBOR.has_point(ship.pos):
		ship.state = "saved"
		saved += 1


func _keep_on_screen(ship: Ship) -> void:
	# Les bords de l'écran renvoient les bateaux vers la mer.
	var dir := Vector2.from_angle(ship.heading)
	if ship.pos.x < 10.0 and dir.x < 0.0:
		dir.x = -dir.x
	if ship.pos.x > SCREEN.x - 10.0 and dir.x > 0.0:
		dir.x = -dir.x
	if ship.pos.y < -30.0 and dir.y < 0.0:
		dir.y = -dir.y
	if ship.pos.y > SCREEN.y - 10.0 and dir.y > 0.0:
		dir.y = -dir.y
	ship.heading = dir.angle()
	ship.pos.x = clampf(ship.pos.x, 0.0, SCREEN.x)
	ship.pos.y = clampf(ship.pos.y, -40.0, SCREEN.y)


func _check_end() -> void:
	if wrecked >= MAX_WRECKS:
		game_over = true
		won = false
	elif saved + wrecked >= SHIP_COUNT:
		game_over = true
		won = true


func is_lit(point: Vector2) -> bool:
	var to_point := point - LIGHTHOUSE_POS
	var dist := to_point.length()
	if dist <= HALO_RADIUS:
		return true
	if dist > BEAM_LENGTH:
		return false
	return absf(wrapf(to_point.angle() - beam_angle, -PI, PI)) <= BEAM_HALF_ANGLE


# --- Dessin -------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.035, 0.06, 0.11))
	_draw_harbor()
	_draw_beam()
	_draw_rocks()
	_draw_ships()
	_draw_lighthouse()
	_draw_rain()
	if lightning > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.8, 0.85, 1.0, lightning * 0.35))
	_draw_hud()


func _draw_harbor() -> void:
	draw_rect(HARBOR, Color(0.12, 0.32, 0.22, 0.55))
	draw_rect(HARBOR, Color(0.35, 0.8, 0.5), false, 2.0)
	_text("PORT", HARBOR.position + Vector2(12, 26), 18, Color(0.6, 1.0, 0.7))


func _draw_beam() -> void:
	# Plusieurs cônes superposés pour un dégradé simple.
	for layer in 3:
		var spread := BEAM_HALF_ANGLE * (1.0 - layer * 0.3)
		var a := LIGHTHOUSE_POS + Vector2.from_angle(beam_angle - spread) * BEAM_LENGTH
		var b := LIGHTHOUSE_POS + Vector2.from_angle(beam_angle + spread) * BEAM_LENGTH
		draw_colored_polygon(PackedVector2Array([LIGHTHOUSE_POS, a, b]), Color(1.0, 0.92, 0.55, 0.09))
	draw_circle(LIGHTHOUSE_POS, HALO_RADIUS, Color(1.0, 0.92, 0.55, 0.06))


func _draw_rocks() -> void:
	for rock in rocks:
		var visibility := lightning
		if rock.always_visible or is_lit(rock.pos):
			visibility = 1.0
		if visibility <= 0.02:
			continue
		draw_circle(rock.pos, rock.radius, Color(0.42, 0.42, 0.46, visibility))
		draw_circle(rock.pos + Vector2(-rock.radius * 0.25, -rock.radius * 0.25),
			rock.radius * 0.45, Color(0.55, 0.55, 0.6, visibility))


func _draw_ships() -> void:
	for ship in ships:
		var forward := Vector2.from_angle(ship.heading)
		var side := forward.orthogonal()
		var hull := PackedVector2Array([
			ship.pos + forward * 14.0,
			ship.pos - forward * 9.0 + side * 7.0,
			ship.pos - forward * 9.0 - side * 7.0,
		])
		match ship.state:
			"wrecked":
				var c := Color(1.0, 0.3, 0.25)
				draw_line(ship.pos + Vector2(-9, -9), ship.pos + Vector2(9, 9), c, 3.0)
				draw_line(ship.pos + Vector2(-9, 9), ship.pos + Vector2(9, -9), c, 3.0)
			"saved":
				draw_colored_polygon(hull, Color(0.5, 1.0, 0.6))
			_:
				var alpha := 1.0 if ship.lit else 0.3
				draw_colored_polygon(hull, Color(0.95, 0.95, 0.9, alpha))
				# Petite lanterne de bord, toujours un peu visible.
				draw_circle(ship.pos, 2.5, Color(1.0, 0.8, 0.3))


func _draw_lighthouse() -> void:
	draw_rect(Rect2(LIGHTHOUSE_POS + Vector2(-10, -34), Vector2(20, 34)), Color(0.9, 0.9, 0.88))
	draw_rect(Rect2(LIGHTHOUSE_POS + Vector2(-10, -24), Vector2(20, 7)), Color(0.8, 0.2, 0.2))
	draw_circle(LIGHTHOUSE_POS + Vector2(0, -38), 7.0, Color(1.0, 0.95, 0.6))


func _draw_rain() -> void:
	var slant := Vector2(wind.x * 0.25, 12.0)
	for drop in rain:
		draw_line(drop, drop + slant, Color(0.6, 0.7, 0.9, 0.25), 1.0)


func _draw_hud() -> void:
	var to_come := SHIP_COUNT - spawned
	_text("Sauvés : %d / %d     Naufrages : %d (max %d)     À venir : %d"
		% [saved, SHIP_COUNT, wrecked, MAX_WRECKS - 1, to_come], Vector2(20, 32), 20, Color.WHITE)

	if elapsed < INTRO_DURATION and not game_over:
		var alpha := clampf(INTRO_DURATION - elapsed, 0.0, 1.0)
		_text_centered("Guide les bateaux jusqu'au port avec le rayon du phare.", 300, 26, Color(1, 1, 1, alpha))
		_text_centered("Les rochers n'apparaissent que dans la lumière... ou sous les éclairs.", 336, 20, Color(0.8, 0.85, 1, alpha))
		_text_centered("Souris pour viser (ou flèches gauche / droite).", 366, 18, Color(0.8, 0.8, 0.8, alpha))

	if game_over:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, 0.55))
		if won:
			_text_centered("L'aube se lève : %d bateau(x) sauvé(s) !" % saved, 320, 40, Color(1.0, 0.95, 0.6))
		else:
			_text_centered("La tempête a gagné cette nuit...", 320, 40, Color(1.0, 0.5, 0.45))
		_text_centered("Clique ou appuie sur R pour rejouer", 370, 22, Color.WHITE)


func _text(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_centered(text: String, y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, SCREEN.x, size, color)
