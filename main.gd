extends Node2D

# OPERATION STRIKE 2D - playable vertical-slice prototype.
# All artwork is drawn procedurally so the starter project has no external asset dependencies.

const WORLD_W := 3000.0
const GROUND_Y := 625.0
const PLAYER_RADIUS := 22.0
const GRAVITY := 1450.0
const MOVE_SPEED := 340.0
const JUMP_SPEED := -610.0
const JETPACK_ACCEL := -1150.0
const MAX_HP := 100.0
const FIRE_DEADZONE := 0.22
const TOUCH_LEFT := 0
const TOUCH_AIM := 1

var player_pos := Vector2(260, GROUND_Y - 28)
var player_vel := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var hp := 100.0
var max_hp := 100.0
var heart_time := 0.0
var invuln_time := 0.0
var is_grounded := true
var jetpack_fuel := 100.0
var selected_weapon := 0
var weapons := [
	{"name":"Pistol", "damage":22.0, "rate":0.34, "speed":900.0, "spread":0.035, "ammo":12, "mag":12, "auto":false, "pellets":1},
	{"name":"SMG", "damage":12.0, "rate":0.085, "speed":1050.0, "spread":0.10, "ammo":36, "mag":36, "auto":true, "pellets":1},
	{"name":"Rifle", "damage":19.0, "rate":0.13, "speed":1250.0, "spread":0.055, "ammo":30, "mag":30, "auto":true, "pellets":1},
	{"name":"Shotgun", "damage":11.0, "rate":0.72, "speed":850.0, "spread":0.34, "ammo":6, "mag":6, "auto":false, "pellets":7}
]
var fire_cooldown := 0.0
var reload_time := 0.0
var bullets: Array[Dictionary] = []
var bots: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var explosives: Array[Dictionary] = []
var smoke_clouds: Array[Dictionary] = []
var kill_count := 0
var deaths := 0
var team_score := 0
var enemy_score := 0
var gun_level := 0
var match_time := 0.0
var mode_index := 0
var modes := ["PRACTICE", "TEAM DEATHMATCH", "GUN GAME", "BATTLE ROYALE"]
var message := "Tap PLAY or move to begin"
var message_time := 4.0
var started := false
var left_touch := -1
var aim_touch := -1
var left_origin := Vector2.ZERO
var left_current := Vector2.ZERO
var aim_origin := Vector2.ZERO
var aim_current := Vector2.ZERO
var left_stick := Vector2.ZERO
var aim_stick := Vector2.ZERO
var mouse_left := false
var mouse_aim := false
var jetpack_active := false
var grenade_kind := 0
var grenades := {"FRAG":3, "STICKY":1, "SMOKE":2, "STUN":1}
var button_rects: Dictionary = {}
var screen_size := Vector2(1280, 720)
var camera_x := 0.0
var camera_y := 0.0
var spawn_clock := 0.0
var bot_id_counter := 0

const GRENADE_NAMES := ["FRAG", "STICKY", "SMOKE", "STUN"]
const GUN_LADDER := [0, 1, 2, 3, 0, 2, 1, 3]

func _ready() -> void:
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	_reset_match()
	set_process(true)
	set_physics_process(true)

func _on_resize() -> void:
	screen_size = get_viewport_rect().size
	queue_redraw()

func _reset_match() -> void:
	player_pos = Vector2(260, GROUND_Y - 28)
	player_vel = Vector2.ZERO
	hp = MAX_HP
	max_hp = MAX_HP
	heart_time = 0.0
	jetpack_fuel = 100.0
	selected_weapon = 0
	bullets.clear()
	bots.clear()
	pickups.clear()
	explosives.clear()
	smoke_clouds.clear()
	kill_count = 0
	deaths = 0
	team_score = 0
	enemy_score = 0
	gun_level = 0
	match_time = 0.0
	spawn_clock = 0.0
	for i in range(6):
		_spawn_bot(650.0 + i * 310.0)
	for i in range(24):
		_spawn_random_pickup(true)
	message = "OPERATION STRIKE 2D  •  DUAL STICK COMBAT"
	message_time = 5.0
	started = true

func _process(delta: float) -> void:
	match_time += delta
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	invuln_time = maxf(0.0, invuln_time - delta)
	if reload_time > 0.0:
		reload_time -= delta
		if reload_time <= 0.0:
			var w: Dictionary = weapons[selected_weapon]
			w["ammo"] = int(w["mag"])
			weapons[selected_weapon] = w
			_show_message("RELOADED  •  " + str(w["name"]))
	if heart_time > 0.0:
		heart_time = maxf(0.0, heart_time - delta)
		if heart_time == 0.0:
			max_hp = MAX_HP
			hp = minf(hp, MAX_HP)
			_show_message("GOLDEN HEART EXPIRED")
	if message_time > 0.0:
		message_time -= delta
	_update_bullets(delta)
	_update_bots(delta)
	_update_explosives(delta)
	_update_smoke(delta)
	_update_pickup_spawns(delta)
	_update_camera()
	queue_redraw()

func _physics_process(delta: float) -> void:
	var move_input := left_stick.x
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input += 1.0
	move_input = clampf(move_input, -1.0, 1.0)
	player_vel.x = move_toward(player_vel.x, move_input * MOVE_SPEED, 1900.0 * delta)
	if is_grounded and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
		_jump()
	if jetpack_active and jetpack_fuel > 0.0:
		player_vel.y += JETPACK_ACCEL * delta
		jetpack_fuel = maxf(0.0, jetpack_fuel - 34.0 * delta)
	else:
		jetpack_fuel = minf(100.0, jetpack_fuel + 17.0 * delta)
	player_vel.y += GRAVITY * delta
	player_pos += player_vel * delta
	player_pos.x = clampf(player_pos.x, 40.0, WORLD_W - 40.0)
	if player_pos.y >= GROUND_Y - 28.0:
		player_pos.y = GROUND_Y - 28.0
		player_vel.y = 0.0
		is_grounded = true
	else:
		is_grounded = false
	if aim_stick.length() > FIRE_DEADZONE:
		aim_dir = aim_stick.normalized()
		_try_fire()
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _is_over_hud(get_global_mouse_position()):
		var world_mouse := get_global_mouse_position() + Vector2(camera_x, camera_y)
		aim_dir = (world_mouse - player_pos).normalized()
		_try_fire()
	if Input.is_key_pressed(KEY_R):
		_reload()
	if Input.is_key_pressed(KEY_Q):
		_switch_weapon()

func _jump() -> void:
	if is_grounded:
		player_vel.y = JUMP_SPEED
		is_grounded = false
		_show_message("JUMP")

func _try_fire() -> void:
	if reload_time > 0.0 or fire_cooldown > 0.0:
		return
	var w: Dictionary = weapons[selected_weapon]
	if int(w["ammo"]) <= 0:
		_show_message("OUT OF AMMO  •  RELOAD")
		return
	w["ammo"] = int(w["ammo"]) - 1
	weapons[selected_weapon] = w
	fire_cooldown = float(w["rate"])
	var base_angle := aim_dir.angle()
	for i in range(int(w["pellets"])):
		var spread_angle := base_angle + randf_range(-float(w["spread"]), float(w["spread"]))
		var dir := Vector2.RIGHT.rotated(spread_angle)
		bullets.append({"pos": player_pos + dir * 28.0, "vel": dir * float(w["speed"]), "damage": float(w["damage"]), "life": 1.6, "owner":"player"})

func _reload() -> void:
	if reload_time > 0.0:
		return
	var w: Dictionary = weapons[selected_weapon]
	if int(w["ammo"]) >= int(w["mag"]):
		return
	reload_time = 1.05
	_show_message("RELOADING...")

func _switch_weapon() -> void:
	selected_weapon = (selected_weapon + 1) % weapons.size()
	_show_message("EQUIPPED  •  " + str(weapons[selected_weapon]["name"]))

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] = b["pos"] + b["vel"] * delta
		b["life"] = float(b["life"]) - delta
		var remove := float(b["life"]) <= 0.0 or float(b["pos"].x) < 0.0 or float(b["pos"].x) > WORLD_W or float(b["pos"].y) < 0.0 or float(b["pos"].y) > 900.0
		if str(b["owner"]) == "player":
			for j in range(bots.size() - 1, -1, -1):
				var bot: Dictionary = bots[j]
				if Vector2(b["pos"]).distance_to(bot["pos"]) < 28.0:
					bot["hp"] = float(bot["hp"]) - float(b["damage"])
					bots[j] = bot
					remove = true
					if float(bot["hp"]) <= 0.0:
						_on_bot_killed(j)
					break
		else:
			if Vector2(b["pos"]).distance_to(player_pos) < 25.0 and invuln_time <= 0.0:
				_take_damage(float(b["damage"]))
				remove = true
		if remove:
			bullets.remove_at(i)
		else:
			bullets[i] = b

func _spawn_bot(x: float) -> void:
	bot_id_counter += 1
	bots.append({"id":bot_id_counter, "pos":Vector2(clampf(x, 120.0, WORLD_W - 120.0), GROUND_Y - 28.0), "hp":100.0, "dir":-1.0 if randf() > 0.5 else 1.0, "fire":randf_range(0.6, 2.0), "speed":randf_range(90.0, 155.0), "jump":randf_range(1.5, 4.0), "stun":0.0, "weapon":randi_range(0, 2)})

func _update_bots(delta: float) -> void:
	for i in range(bots.size()):
		var bot: Dictionary = bots[i]
		var pos: Vector2 = bot["pos"]
		var dx := player_pos.x - pos.x
		if float(bot["stun"]) > 0.0:
			bot["stun"] = maxf(0.0, float(bot["stun"]) - delta)
		else:
			if absf(dx) > 170.0:
				pos.x += signf(dx) * float(bot["speed"]) * delta
			else:
				bot["fire"] = float(bot["fire"]) - delta
				if float(bot["fire"]) <= 0.0:
					var dir := (player_pos - pos).normalized()
					bullets.append({"pos":pos + dir * 25.0, "vel":dir * 620.0, "damage":8.0, "life":2.0, "owner":"bot"})
					bot["fire"] = randf_range(1.0, 2.0)
			if randf() < 0.002 and pos.y >= GROUND_Y - 29.0:
				bot["jump"] = randf_range(1.5, 3.0)
			if float(bot["jump"]) > 0.0:
				bot["jump"] = float(bot["jump"]) - delta
			bot["pos"] = pos
		bots[i] = bot

func _on_bot_killed(index: int) -> void:
	var dead: Dictionary = bots[index]
	var death_pos: Vector2 = dead["pos"]
	bots.remove_at(index)
	kill_count += 1
	team_score += 1
	if mode_index == 2:
		gun_level = mini(gun_level + 1, GUN_LADDER.size() - 1)
		selected_weapon = GUN_LADDER[gun_level]
		_show_message("GUN UPGRADE  •  " + str(weapons[selected_weapon]["name"]))
	else:
		_show_message("ELIMINATION  •  " + str(kill_count))
	_spawn_random_pickup_at(death_pos + Vector2(0, -12))
	_spawn_bot(death_pos.x + randf_range(-600.0, 600.0))

func _take_damage(amount: float) -> void:
	hp -= amount
	invuln_time = 0.22
	if hp <= 0.0:
		hp = 0.0
		deaths += 1
		enemy_score += 1
		_show_message("ELIMINATED  •  RESPAWNING")
		player_pos = Vector2(clampf(player_pos.x - 260.0, 100.0, WORLD_W - 100.0), GROUND_Y - 28.0)
		player_vel = Vector2.ZERO
		hp = MAX_HP
		max_hp = MAX_HP
		heart_time = 0.0
		invuln_time = 2.0

func _spawn_random_pickup(initial: bool = false) -> void:
	var x := randf_range(120.0, WORLD_W - 120.0)
	_spawn_random_pickup_at(Vector2(x, GROUND_Y - 20.0))

func _spawn_random_pickup_at(pos: Vector2) -> void:
	var roll := randf()
	var kind := "AMMO"
	if roll < 0.25:
		kind = "WEAPON"
	elif roll < 0.43:
		kind = "BANDAGE"
	elif roll < 0.50:
		kind = "FIRST AID"
	elif roll < 0.56:
		kind = "MEDKIT"
	elif roll < 0.64:
		kind = "FRAG"
	elif roll < 0.72:
		kind = "STICKY"
	elif roll < 0.80:
		kind = "SMOKE"
	elif roll < 0.87:
		kind = "STUN"
	elif roll < 0.90:
		kind = "GOLDEN HEART"
	elif roll < 0.96:
		kind = "AMMO"
	else:
		kind = "ADRENALINE"
	pickups.append({"pos":Vector2(clampf(pos.x, 80.0, WORLD_W - 80.0), minf(pos.y, GROUND_Y - 18.0)), "kind":kind, "life":45.0, "phase":randf() * TAU})

func _update_pickup_spawns(delta: float) -> void:
	spawn_clock += delta
	if spawn_clock >= 4.0 and pickups.size() < 30:
		spawn_clock = 0.0
		_spawn_random_pickup()
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			pickups.remove_at(i)
		elif Vector2(p["pos"]).distance_to(player_pos) < 48.0:
			_collect_pickup(str(p["kind"]))
			pickups.remove_at(i)
		else:
			pickups[i] = p

func _collect_pickup(kind: String) -> void:
	match kind:
		"WEAPON":
			_switch_weapon()
		"BANDAGE":
			hp = minf(max_hp, hp + 15.0)
			_show_message("BANDAGE  +15 HP")
		"FIRST AID":
			hp = minf(max_hp, 75.0)
			_show_message("FIRST AID  •  UP TO 75 HP")
		"MEDKIT":
			hp = max_hp
			_show_message("MED KIT  •  FULL HEALTH")
		"FRAG", "STICKY", "SMOKE", "STUN":
			grenades[kind] = int(grenades.get(kind, 0)) + 1
			_show_message(kind + " GRENADE +1")
		"GOLDEN HEART":
			max_hp = 200.0
			hp = minf(200.0, hp * 2.0)
			heart_time = 15.0
			_show_message("GOLDEN HEART  •  2× HP  •  15 SEC")
		"ADRENALINE":
			hp = minf(max_hp, hp + 30.0)
			jetpack_fuel = 100.0
			_show_message("ADRENALINE  •  +30 HP")
		"AMMO":
			var w: Dictionary = weapons[selected_weapon]
			w["ammo"] = mini(int(w["mag"]), int(w["ammo"]) + int(w["mag"] / 2))
			weapons[selected_weapon] = w
			_show_message("AMMO COLLECTED")

func _throw_grenade(kind: String) -> void:
	if int(grenades.get(kind, 0)) <= 0:
		_show_message("NO " + kind + " GRENADES")
		return
	grenades[kind] = int(grenades[kind]) - 1
	var dir := aim_dir.normalized()
	explosives.append({"pos":player_pos + dir * 35.0, "vel":dir * 440.0 + Vector2(0, -280.0), "kind":kind, "timer":1.35, "stuck":false})
	_show_message(kind + " OUT!")

func _update_explosives(delta: float) -> void:
	for i in range(explosives.size() - 1, -1, -1):
		var e: Dictionary = explosives[i]
		if not bool(e["stuck"]):
			e["vel"] = e["vel"] + Vector2(0, GRAVITY * 0.65) * delta
			e["pos"] = e["pos"] + e["vel"] * delta
			if float(e["pos"].y) >= GROUND_Y - 12.0:
				e["pos"].y = GROUND_Y - 12.0
				e["vel"] = Vector2.ZERO
				if str(e["kind"]) == "STICKY":
					e["stuck"] = true
		e["timer"] = float(e["timer"]) - delta
		if float(e["timer"]) <= 0.0:
			var pos: Vector2 = e["pos"]
			var kind := str(e["kind"])
			if kind == "SMOKE":
				smoke_clouds.append({"pos":pos, "life":7.0, "kind":"SMOKE"})
			elif kind == "STUN":
				for j in range(bots.size()):
					var bot: Dictionary = bots[j]
					if Vector2(bot["pos"]).distance_to(pos) < 270.0:
						bot["stun"] = 3.0
					bots[j] = bot
				_show_message(kind + " DETONATED")
			else:
				for j in range(bots.size() - 1, -1, -1):
					if Vector2(bots[j]["pos"]).distance_to(pos) < 190.0:
						bots[j]["hp"] = float(bots[j]["hp"]) - 85.0
						if float(bots[j]["hp"]) <= 0.0:
							_on_bot_killed(j)
				if player_pos.distance_to(pos) < 150.0 and invuln_time <= 0.0:
					_take_damage(28.0)
				_show_message("BOOM!")
			explosives.remove_at(i)
		else:
			explosives[i] = e

func _update_smoke(delta: float) -> void:
	for i in range(smoke_clouds.size() - 1, -1, -1):
		var s: Dictionary = smoke_clouds[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			smoke_clouds.remove_at(i)
		else:
			smoke_clouds[i] = s

func _update_camera() -> void:
	camera_x = clampf(player_pos.x - screen_size.x * 0.5, 0.0, WORLD_W - screen_size.x)
	camera_y = 0.0

func _show_message(text: String) -> void:
	message = text
	message_time = 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_touch_down(touch_event.index, touch_event.position)
		else:
			_handle_touch_up(touch_event.index)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == left_touch:
			left_current = drag_event.position
			left_stick = _stick_vector(left_origin, left_current, 95.0)
		elif drag_event.index == aim_touch:
			aim_current = drag_event.position
			aim_stick = _stick_vector(aim_origin, aim_current, 95.0)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_mouse_down(mouse_event.position)
			else:
				mouse_left = false
				mouse_aim = false
				left_stick = Vector2.ZERO
				aim_stick = Vector2.ZERO
	elif event is InputEventMouseMotion:
		if mouse_left:
			left_stick = _stick_vector(left_origin, event.position, 95.0)
		if mouse_aim:
			aim_stick = _stick_vector(aim_origin, event.position, 95.0)

func _handle_touch_down(index: int, pos: Vector2) -> void:
	if _handle_button(pos):
		return
	if pos.x < screen_size.x * 0.43 and pos.y > screen_size.y * 0.40 and left_touch == -1:
		left_touch = index
		left_origin = pos
		left_current = pos
		left_stick = Vector2.ZERO
	elif pos.x > screen_size.x * 0.57 and pos.y > screen_size.y * 0.38 and aim_touch == -1:
		aim_touch = index
		aim_origin = pos
		aim_current = pos
		aim_stick = Vector2.ZERO

func _handle_touch_up(index: int) -> void:
	if index == left_touch:
		left_touch = -1
		left_stick = Vector2.ZERO
	if index == aim_touch:
		aim_touch = -1
		aim_stick = Vector2.ZERO

func _handle_mouse_down(pos: Vector2) -> void:
	if _handle_button(pos):
		return
	if pos.x < screen_size.x * 0.43 and pos.y > screen_size.y * 0.40:
		mouse_left = true
		left_origin = pos
		left_stick = Vector2.ZERO
	elif pos.x > screen_size.x * 0.57 and pos.y > screen_size.y * 0.38:
		mouse_aim = true
		aim_origin = pos
		aim_stick = Vector2.ZERO

func _stick_vector(origin: Vector2, current: Vector2, radius: float) -> Vector2:
	var delta := current - origin
	if delta.length() > radius:
		delta = delta.normalized() * radius
	return delta / radius

func _handle_button(pos: Vector2) -> bool:
	for key in button_rects.keys():
		if Rect2(button_rects[key]).has_point(pos):
			match str(key):
				"JUMP": _jump()
				"JET": jetpack_active = not jetpack_active
				"RELOAD": _reload()
				"SWAP": _switch_weapon()
				"HEAL": _use_heal()
				"FRAG": _throw_grenade("FRAG")
				"STICKY": _throw_grenade("STICKY")
				"SMOKE": _throw_grenade("SMOKE")
				"STUN": _throw_grenade("STUN")
				"HEART": _activate_heart()
				"MODE": _cycle_mode()
			return true
	return false

func _use_heal() -> void:
	if hp >= max_hp:
		_show_message("HEALTH ALREADY FULL")
	else:
		hp = minf(max_hp, hp + 35.0)
		_show_message("QUICK HEAL  +35 HP")

func _activate_heart() -> void:
	if heart_time > 0.0:
		_show_message("GOLDEN HEART ACTIVE")
		return
	max_hp = 200.0
	hp = minf(200.0, hp * 2.0)
	heart_time = 15.0
	_show_message("GOLDEN HEART  •  2× HP")

func _cycle_mode() -> void:
	mode_index = (mode_index + 1) % modes.size()
	_reset_match()
	_show_message("MODE  •  " + modes[mode_index])

func _is_over_hud(pos: Vector2) -> bool:
	for rect in button_rects.values():
		if Rect2(rect).has_point(pos):
			return true
	return false

func _draw() -> void:
	_draw_world()
	_draw_entities()
	_draw_hud()

func _world_to_screen(p: Vector2) -> Vector2:
	return Vector2(p.x - camera_x, p.y - camera_y)

func _draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#79b9d4"))
	# Distant hills and clouds.
	for i in range(9):
		var x := float(i) * 390.0 - fmod(camera_x * 0.25, 390.0)
		draw_circle(Vector2(x + 100, 440), 150, Color("#8cae91"))
		draw_circle(Vector2(x + 230, 465), 190, Color("#72977d"))
	# Sun and clouds.
	draw_circle(Vector2(screen_size.x - 130, 115), 48, Color("#ffe69a"))
	for i in range(5):
		var cx := float(i) * 330.0 - fmod(camera_x * 0.12, 330.0)
		draw_circle(Vector2(cx + 100, 120 + (i % 2) * 45), 24, Color("#e9f3ed"))
		draw_circle(Vector2(cx + 130, 112 + (i % 2) * 45), 30, Color("#e9f3ed"))
		draw_circle(Vector2(cx + 160, 125 + (i % 2) * 45), 22, Color("#e9f3ed"))
	# Ground.
	draw_rect(Rect2(Vector2(0, GROUND_Y - camera_y), Vector2(screen_size.x, screen_size.y - GROUND_Y + 100)), Color("#526d42"))
	draw_rect(Rect2(Vector2(0, GROUND_Y - camera_y), Vector2(screen_size.x, 18)), Color("#8d7046"))
	for i in range(45):
		var x := float(i) * 90.0 - fmod(camera_x, 90.0)
		draw_line(Vector2(x, GROUND_Y + 25), Vector2(x + 26, GROUND_Y + 25), Color("#718a4f"), 3.0)
	# Platforms / crates.
	for i in range(8):
		var wx := 430.0 + i * 345.0
		var sx := wx - camera_x
		if sx > -150 and sx < screen_size.x + 150:
			draw_rect(Rect2(Vector2(sx, GROUND_Y - 100 - (i % 3) * 32), Vector2(90, 82 + (i % 3) * 32)), Color("#947044"))
			draw_rect(Rect2(Vector2(sx + 8, GROUND_Y - 92 - (i % 3) * 32), Vector2(74, 8)), Color("#bd965d"))

func _draw_entities() -> void:
	for s in smoke_clouds:
		var p := _world_to_screen(s["pos"])
		var alpha := clampf(float(s["life"]) / 2.0, 0.18, 0.58)
		for j in range(8):
			draw_circle(p + Vector2(cos(j * TAU / 8.0), sin(j * TAU / 8.0)) * (42.0 + j * 3.0), 46.0, Color(0.65, 0.68, 0.69, alpha))
	for p in pickups:
		_draw_pickup(_world_to_screen(p["pos"]), str(p["kind"]))
	for e in explosives:
		var ep := _world_to_screen(e["pos"])
		draw_circle(ep, 10, Color("#e9a43b"))
		draw_circle(ep, 5, Color("#4a3a2b"))
	for b in bullets:
		var bp := _world_to_screen(b["pos"])
		draw_line(bp, bp - Vector2(b["vel"]).normalized() * 13.0, Color("#fff2a3") if b["owner"] == "player" else Color("#ff8466"), 4.0)
	for bot in bots:
		_draw_soldier(_world_to_screen(bot["pos"]), -1.0 if float(bot["pos"].x) > player_pos.x else 1.0, Color("#b94f45"), float(bot["hp"]), false)
	_draw_soldier(_world_to_screen(player_pos), 1.0 if aim_dir.x >= 0.0 else -1.0, Color("#397cbd"), hp, true)

func _draw_soldier(pos: Vector2, facing: float, uniform: Color, health: float, is_player: bool) -> void:
	if is_player and heart_time > 0.0:
		draw_circle(pos, 39.0, Color(1.0, 0.78, 0.12, 0.22 + 0.12 * sin(match_time * 8.0)))
	# Legs and boots.
	draw_line(pos + Vector2(-8, 12), pos + Vector2(-13, 27), Color("#30383a"), 8.0)
	draw_line(pos + Vector2(8, 12), pos + Vector2(13, 27), Color("#30383a"), 8.0)
	# Body and vest.
	draw_rect(Rect2(pos + Vector2(-15, -15), Vector2(30, 34)), uniform, true, 5.0)
	draw_rect(Rect2(pos + Vector2(-11, -8), Vector2(22, 18)), Color("#4c5c45"))
	draw_rect(Rect2(pos + Vector2(-14, -25), Vector2(28, 12)), Color("#d5b17a"), true, 5.0)
	# Helmet.
	draw_arc(pos + Vector2(0, -24), 15, PI, TAU, 18, Color("#425b43"), 9.0)
	# Arm and weapon follow aim direction.
	var dir := aim_dir if is_player else (player_pos - (pos + Vector2(camera_x, camera_y))).normalized()
	if not is_player:
		dir = Vector2(facing, -0.08)
	var gun_start := pos + Vector2(5.0 * facing, -7)
	draw_line(gun_start, gun_start + dir * 35.0, Color("#20292d"), 8.0)
	draw_line(gun_start + dir * 35.0, gun_start + dir * 42.0, Color("#6b7779"), 4.0)
	# Health bar.
	draw_rect(Rect2(pos + Vector2(-22, -48), Vector2(44, 6)), Color("#333333"))
	draw_rect(Rect2(pos + Vector2(-22, -48), Vector2(44.0 * clampf(health / (200.0 if is_player and heart_time > 0.0 else 100.0), 0.0, 1.0), 6)), Color("#65d36e") if is_player else Color("#e36a58"))

func _draw_pickup(pos: Vector2, kind: String) -> void:
	var color := Color("#e5cf5b")
	match kind:
		"WEAPON": color = Color("#b8c5cf")
		"BANDAGE", "FIRST AID", "MEDKIT": color = Color("#e65d5d")
		"FRAG", "STICKY": color = Color("#d7a34b")
		"SMOKE": color = Color("#aeb8c0")
		"STUN": color = Color("#8b80d8")
		"GOLDEN HEART": color = Color("#ffd13b")
		"ADRENALINE": color = Color("#68d6cf")
	draw_circle(pos, 17 + 2 * sin(match_time * 4.0), Color(color.r, color.g, color.b, 0.22))
	draw_rect(Rect2(pos + Vector2(-10, -10), Vector2(20, 20)), color, true, 4.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(-22, -22), kind.left(7), HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color.WHITE)

func _draw_hud() -> void:
	# Top status strip.
	draw_rect(Rect2(Vector2(14, 12), Vector2(350, 86)), Color(0.05, 0.08, 0.10, 0.78), true, 12.0)
	draw_string(ThemeDB.fallback_font, Vector2(30, 38), "OPERATION STRIKE 2D", HORIZONTAL_ALIGNMENT_LEFT, 320, 19, Color("#f3f1dc"))
	draw_string(ThemeDB.fallback_font, Vector2(30, 63), modes[mode_index] + "  •  KILLS " + str(kill_count) + "  •  DEATHS " + str(deaths), HORIZONTAL_ALIGNMENT_LEFT, 330, 13, Color("#c4d1d4"))
	draw_rect(Rect2(Vector2(30, 74), Vector2(210, 12)), Color("#30383b"), true, 5.0)
	draw_rect(Rect2(Vector2(30, 74), Vector2(210.0 * clampf(hp / max_hp, 0.0, 1.0), 12)), Color("#55c86a"), true, 5.0)
	draw_string(ThemeDB.fallback_font, Vector2(250, 85), str(roundi(hp)) + "/" + str(roundi(max_hp)), HORIZONTAL_ALIGNMENT_LEFT, 90, 13, Color.WHITE)
	# Mode cycle button.
	_draw_button("MODE", Rect2(Vector2(380, 18), Vector2(105, 43)), modes[mode_index], Color("#395c76"))
	# Top-right action buttons, arranged two rows.
	var bx := screen_size.x - 340.0
	var by := 18.0
	_draw_button("JUMP", Rect2(Vector2(bx, by), Vector2(72, 42)), "JUMP", Color("#477eaa"))
	_draw_button("JET", Rect2(Vector2(bx + 78, by), Vector2(72, 42)), "JET", Color("#477eaa"))
	_draw_button("RELOAD", Rect2(Vector2(bx + 156, by), Vector2(78, 42)), "RELOAD", Color("#566a78"))
	_draw_button("SWAP", Rect2(Vector2(bx + 240, by), Vector2(82, 42)), "SWAP", Color("#566a78"))
	_draw_button("HEAL", Rect2(Vector2(bx, by + 49), Vector2(72, 42)), "HEAL", Color("#39865f"))
	_draw_button("HEART", Rect2(Vector2(bx + 78, by + 49), Vector2(72, 42)), "HEART", Color("#b58b25"))
	_draw_button("FRAG", Rect2(Vector2(bx + 156, by + 49), Vector2(78, 42)), "FRAG", Color("#9b6336"))
	_draw_button("SMOKE", Rect2(Vector2(bx + 240, by + 49), Vector2(82, 42)), "SMOKE", Color("#66737b"))
	_draw_button("STICKY", Rect2(Vector2(bx + 78, by + 98), Vector2(72, 42)), "STICKY", Color("#9b6336"))
	_draw_button("STUN", Rect2(Vector2(bx + 156, by + 98), Vector2(78, 42)), "STUN", Color("#7664a5"))
	# Small grenade cycling indicators.
	draw_string(ThemeDB.fallback_font, Vector2(screen_size.x - 330, 173), "FRAG " + str(grenades["FRAG"]) + "  STICKY " + str(grenades["STICKY"]) + "  STUN " + str(grenades["STUN"]), HORIZONTAL_ALIGNMENT_LEFT, 320, 12, Color.WHITE)
	# Weapon info.
	var w: Dictionary = weapons[selected_weapon]
	draw_rect(Rect2(Vector2(screen_size.x * 0.5 - 105, 16), Vector2(210, 58)), Color(0.05, 0.08, 0.10, 0.75), true, 10.0)
	draw_string(ThemeDB.fallback_font, Vector2(screen_size.x * 0.5 - 90, 40), str(w["name"]), HORIZONTAL_ALIGNMENT_LEFT, 180, 17, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(screen_size.x * 0.5 - 90, 61), str(w["ammo"]) + " / " + str(w["mag"]), HORIZONTAL_ALIGNMENT_LEFT, 180, 14, Color("#d4dfdf"))
	if heart_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(screen_size.x * 0.5 - 90, 92), "GOLDEN HEART  " + str(snappedf(heart_time, 0.1)) + "s", HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color("#ffd34e"))
	if message_time > 0.0:
		draw_rect(Rect2(Vector2(screen_size.x * 0.5 - 230, 115), Vector2(460, 36)), Color(0.04, 0.07, 0.08, 0.72), true, 8.0)
		draw_string(ThemeDB.fallback_font, Vector2(screen_size.x * 0.5 - 210, 139), message, HORIZONTAL_ALIGNMENT_CENTER, 420, 15, Color.WHITE)
	# Dual joysticks.
	var left_center := Vector2(145, screen_size.y - 145)
	var right_center := Vector2(screen_size.x - 150, screen_size.y - 145)
	if left_touch == -1 and not mouse_left:
		draw_circle(left_center, 72, Color(0.06, 0.10, 0.12, 0.22))
		draw_circle(left_center, 48, Color(0.75, 0.85, 0.86, 0.12), false, 3.0)
		draw_circle(left_center, 27, Color(0.75, 0.85, 0.86, 0.25))
	else:
		draw_circle(left_origin, 72, Color(0.06, 0.10, 0.12, 0.28))
		draw_circle(left_origin, 48, Color(0.75, 0.85, 0.86, 0.20), false, 3.0)
		draw_circle(left_origin + left_stick * 48.0, 27, Color(0.85, 0.93, 0.94, 0.65))
	if aim_touch == -1 and not mouse_aim:
		draw_circle(right_center, 72, Color(0.06, 0.10, 0.12, 0.22))
		draw_circle(right_center, 48, Color(0.90, 0.72, 0.40, 0.18), false, 3.0)
		draw_circle(right_center, 27, Color(0.90, 0.72, 0.40, 0.25))
	else:
		draw_circle(aim_origin, 72, Color(0.06, 0.10, 0.12, 0.28))
		draw_circle(aim_origin, 48, Color(0.90, 0.72, 0.40, 0.22), false, 3.0)
		draw_circle(aim_origin + aim_stick * 48.0, 27, Color(1.0, 0.82, 0.47, 0.75))
	draw_string(ThemeDB.fallback_font, Vector2(75, screen_size.y - 48), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(1,1,1,0.55))
	draw_string(ThemeDB.fallback_font, Vector2(screen_size.x - 220, screen_size.y - 48), "AIM + FIRE", HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(1,1,1,0.65))
	draw_string(ThemeDB.fallback_font, Vector2(20, screen_size.y - 18), "WASD/ARROWS + SPACE + MOUSE (DESKTOP TEST)", HORIZONTAL_ALIGNMENT_LEFT, 400, 11, Color(1,1,1,0.45))

func _draw_button(key: String, rect: Rect2, label: String, color: Color) -> void:
	button_rects[key] = rect
	draw_rect(rect, Color(color.r, color.g, color.b, 0.88), true, 8.0)
	draw_rect(rect, Color(1,1,1,0.20), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.65), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color.WHITE)
