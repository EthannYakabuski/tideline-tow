extends RefCounted

const Content = preload("res://game/content.gd")
const HARBOR := Vector2(0, 10)
const PICKUP_RADIUS := 1.1
const BOAT_SPACING := 2.05
const TUG_RADIUS := 0.48
var state: Dictionary = {}

static func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func arr(value: Vector2) -> Array:
	return [value.x, value.y]

func begin(mode: String, index: int, seed_value: int, upgrades: Dictionary = {}) -> Dictionary:
	if mode not in ["campaign", "endless", "daily"]:
		mode = "campaign"
	index = clampi(index, 0, 29)
	if mode == "daily":
		index = 10 + posmod(seed_value, 20)
	var layout := Content.campaign(index if mode != "endless" else 2)
	var boats: Array = []
	for p in layout.b:
		boats.append({"id":boats.size(),"pos":p.duplicate(),"type":boats.size() % 5,"status":"afloat"})
	var rocks: Array = []
	for r in layout.r:
		rocks.append({"pos":[r[0],r[1]],"radius":r[2]})
	var ferries: Array = []
	for f in layout.f:
		ferries.append({"pos":[f[0],f[1]],"origin":[f[0],f[1]],"axis":[1,0],"speed":f[2],"range":f[3],"radius":0.8})
	var currents: Array = []
	for c in layout.c:
		currents.append({"pos":[c[0],c[1]],"radius":c[2],"force":[c[3],c[4]]})
	var max_hull := 3 + clampi(int(upgrades.get("hull", 0)), 0, 1)
	state = {"version":1,"run_id":"%s-%s-%s" % [Time.get_unix_time_from_system(),Time.get_ticks_usec(),seed_value], "mode":mode,"level":index,"district":int(layout.district) if mode != "endless" else 0,
		"name":layout.name if mode == "campaign" else ("Daily Rescue" if mode == "daily" else "Endless Watch"),"seed":seed_value,
		"position":[0.0,7.0],"heading":[0.0,-1.0],"boats":boats,"tow":[],"tow_positions":[],"rocks":rocks,"ferries":ferries,"currents":currents,
		"delivered":0,"score":0,"hull":max_hull,"max_hull":max_hull,"elapsed":0.0,"remaining":float(layout.time) if mode != "endless" else 150.0,"limit":float(layout.time) if mode != "endless" else 150.0,
		"target":int(layout.target) if mode != "endless" else 0,"par":float(layout.par),"status":"running","continued":false,"damage":0,"damage_cooldown":0.0,"pickups":0,"deliveries":0,"max_convoy":0,
		"capacity":3+clampi(int(upgrades.get("rope",0)),0,3),"speed":5.0+clampi(int(upgrades.get("engine",0)),0,3)*0.25,"trail":[[0.0,7.0],[0.0,8.0],[0.0,9.0],[0.0,10.0]],
		"events":[],"endless_wave":0,"stars":0,"failure":""}
	return state

func step(dt: float, input_dir: Vector2) -> Array:
	if state.is_empty() or state.status != "running" or not is_finite(dt) or dt <= 0:
		return []
	state.events = []
	if not is_finite(input_dir.x) or not is_finite(input_dir.y):
		input_dir = Vector2.ZERO
	input_dir = input_dir.limit_length(1.0)
	# Bounded 1/60 simulation catches both tug and tow against rocks even after a frame hitch.
	var pending := minf(dt, 2.0)
	while pending > 0.000001 and state.status == "running":
		var slice := minf(pending, 1.0 / 60.0)
		_tick(slice, input_dir)
		pending -= slice
	return state.events.duplicate()

func _tick(dt: float, input_dir: Vector2) -> void:
	state.elapsed += dt
	state.remaining = maxf(0.0, state.remaining - dt)
	state.damage_cooldown = maxf(0.0, state.damage_cooldown - dt)
	for ferry in state.ferries:
		var range_value: float = float(ferry.range)
		var phase: float = fposmod(state.elapsed * float(ferry.speed) + range_value, range_value * 4.0)
		var x: float = -range_value + phase if phase <= range_value * 2.0 else range_value * 3.0 - phase
		ferry.pos = [x, ferry.origin[1]]
	var before := vec(state.position)
	var movement := input_dir * float(state.speed) * (1.0 - minf(state.tow.size() * 0.025, 0.15))
	# Letting go anchors the tug; currents add a strategic drift only while steering.
	if input_dir.length() > 0.01:
		state.heading = arr(input_dir.normalized())
		for current in state.currents:
			if before.distance_to(vec(current.pos)) < float(current.radius):
				movement += vec(current.force)
	var destination := before + movement * dt
	destination.x = clampf(destination.x, -8.5, 8.5)
	destination.y = clampf(destination.y, -12.0, 11.5)
	var blocked := false
	for rock in state.rocks:
		if destination.distance_to(vec(rock.pos)) < float(rock.radius) + TUG_RADIUS:
			blocked = true
			_damage("rocks")
			break
	if not blocked:
		state.position = arr(destination)
		if vec(state.trail[0]).distance_to(destination) >= 0.04:
			state.trail.push_front(arr(destination))
			if state.trail.size() > 650:
				state.trail.resize(650)
	_update_tow()
	if state.status != "running":
		return
	for ferry in state.ferries:
		if vec(state.position).distance_to(vec(ferry.pos)) < float(ferry.radius) + TUG_RADIUS:
			_damage("ferry")
	for p in state.tow_positions:
		for rock in state.rocks:
			if vec(p).distance_to(vec(rock.pos)) < float(rock.radius) + 0.32:
				_damage("tow snag")
		for ferry in state.ferries:
			if vec(p).distance_to(vec(ferry.pos)) < float(ferry.radius) + 0.32:
				_damage("ferry")
	if state.status != "running":
		return
	if state.damage_cooldown < 0.6 and state.tow.size() < int(state.capacity):
		for boat in state.boats:
			if boat.status == "afloat" and vec(boat.pos).distance_to(vec(state.position)) < PICKUP_RADIUS and state.tow.size() < int(state.capacity):
				boat.status = "towed"
				state.tow.append(boat.id)
				state.pickups += 1
				state.events.append("pickup")
	_update_tow()
	if not state.tow.is_empty() and vec(state.position).distance_to(HARBOR) <= 2.0:
		_deliver()
	if state.remaining <= 0.0 and state.status == "running":
		state.status = "failed"
		state.failure = "The watch is over"
		state.events.append("fail")

func _damage(reason: String) -> void:
	if state.damage_cooldown > 0 or state.status != "running":
		return
	state.hull -= 1
	state.damage += 1
	state.damage_cooldown = 2.2
	state.events.append("bump")
	if not state.tow.is_empty():
		var dropped: int = int(state.tow.pop_back())
		for boat in state.boats:
			if int(boat.id) == dropped:
				boat.status = "afloat"
				# A snagged boat drifts clear of the obstacle and can always be recovered.
				var p := vec(boat.pos)
				for rock in state.rocks:
					var offset := p - vec(rock.pos)
					if offset.length() < float(rock.radius) + 1.0:
						p = vec(rock.pos) + (offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT) * (float(rock.radius) + 1.1)
				p.x = clampf(p.x,-8.1,8.1)
				p.y = clampf(p.y,-11.5,11.0)
				boat.pos = arr(p)
		_update_tow()
	if state.hull <= 0:
		state.hull = 0
		state.status = "failed"
		state.failure = "Tug needs repairs · " + reason
		state.events.append("fail")

func _update_tow() -> void:
	state.tow_positions = []
	for i in range(state.tow.size()):
		var p := _trail_at((i + 1) * BOAT_SPACING)
		state.tow_positions.append(arr(p))
		for boat in state.boats:
			if boat.id == state.tow[i]:
				boat.pos = arr(p)
				break

func _trail_at(distance: float) -> Vector2:
	var trail: Array = state.trail
	var previous := vec(trail[0])
	for i in range(1, trail.size()):
		var next := vec(trail[i])
		var segment := previous.distance_to(next)
		if segment >= distance:
			return previous.lerp(next, distance / maxf(segment, 0.00001))
		distance -= segment
		previous = next
	return previous - vec(state.heading) * distance

func _deliver() -> void:
	var count: int = state.tow.size()
	for boat in state.boats:
		if boat.status == "towed":
			boat.status = "delivered"
	state.delivered += count
	state.deliveries += 1
	state.max_convoy = maxi(int(state.max_convoy), count)
	state.score += count * 100 + count * (count - 1) * 25
	state.tow = []
	state.tow_positions = []
	state.events.append("delivery")
	if state.mode == "endless":
		state.remaining = minf(180.0, state.remaining + count * 13.0)
		var afloat := 0
		for boat in state.boats:
			if boat.status == "afloat": afloat += 1
		if afloat == 0:
			_next_wave()
	elif state.delivered >= state.target:
		state.status = "won"
		state.stars = 1 + (1 if state.damage == 0 else 0) + (1 if state.elapsed <= state.par else 0)
		state.score += int(state.remaining) * 3
		state.events.append("win")

func _next_wave() -> void:
	state.endless_wave += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.seed) + int(state.endless_wave) * 173
	# Keep active entities bounded; lifetime counters retain the full watch.
	state.boats = []
	for i in range(mini(3 + state.endless_wave / 2, 7)):
		var p := Vector2(rng.randf_range(-6.7,6.7), rng.randf_range(-10.5,-3.0))
		for attempt in range(32):
			var clear := true
			for rock in state.rocks:
				if p.distance_to(vec(rock.pos)) < float(rock.radius) + 1.5: clear = false
			for boat in state.boats:
				if p.distance_to(vec(boat.pos)) < 1.7: clear = false
			if clear: break
			p = Vector2(rng.randf_range(-6.7,6.7),rng.randf_range(-10.5,-3.0))
		state.boats.append({"id":i,"pos":arr(p),"type":rng.randi_range(0,4),"status":"afloat"})
	if state.endless_wave == 2:
		state.ferries.append({"pos":[-6.0,2.0],"origin":[0.0,2.0],"axis":[1,0],"speed":1.8,"range":6.0,"radius":0.8})
	if state.endless_wave == 4:
		state.currents.append({"pos":[-4.0,-6.0],"radius":2.5,"force":[0.8,0.0]})
	if state.endless_wave % 3 == 0:
		state.district = (int(state.district) + 1) % 3
	state.events.append("wave")

func end_run(reason: String = "Returned to harbor") -> bool:
	if state.is_empty() or state.status != "running": return false
	state.status = "failed"
	state.failure = reason
	state.events = ["fail"]
	return true

func revive() -> bool:
	if state.is_empty() or state.status != "failed" or state.continued:
		return false
	state.continued = true
	state.status = "running"
	state.hull = mini(int(state.max_hull), 2)
	state.remaining = maxf(45.0, state.remaining)
	state.damage_cooldown = 3.0
	state.position = [0.0,7.0]
	state.heading = [0.0,-1.0]
	state.trail = [[0.0,7.0],[0.0,8.0],[-7.0,8.0],[-7.0,1.0]]
	state.failure = ""
	_update_tow()
	return true

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(candidate: Dictionary) -> bool:
	if not valid_snapshot(candidate):
		return false
	state = candidate.duplicate(true)
	state.events = []
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0],-100,100) and _number(value[1],-100,100)

static func valid_snapshot(s: Dictionary) -> bool:
	var required := ["version","run_id","mode","level","district","position","heading","boats","tow","tow_positions","rocks","ferries","currents","delivered","score","hull","max_hull","elapsed","remaining","limit","target","par","status","continued","damage","damage_cooldown","pickups","deliveries","max_convoy","capacity","speed","trail","events","endless_wave","stars","failure","seed","name"]
	for key in required:
		if not s.has(key): return false
	if s.version != 1 or not s.run_id is String or s.run_id.is_empty() or s.run_id.length() > 120: return false
	if s.mode not in ["campaign","daily","endless"] or s.status not in ["running","failed","won"]: return false
	if not _point(s.position) or not _point(s.heading) or not s.continued is bool: return false
	for key in ["level","district","delivered","score","hull","max_hull","target","damage","pickups","deliveries","max_convoy","capacity","endless_wave","stars"]:
		if not _number(s[key],0,100000000) or float(s[key]) != floor(float(s[key])): return false
	if not _number(s.seed,0,4294967295) or float(s.seed) != floor(float(s.seed)): return false
	if s.level > 29 or s.district > 2 or s.hull > s.max_hull or s.max_hull < 3 or s.max_hull > 4 or s.capacity < 3 or s.capacity > 6 or s.stars > 3: return false
	if absf(s.position[0]) > 8.501 or s.position[1] < -12.001 or s.position[1] > 11.501 or vec(s.heading).length() > 1.001: return false
	if s.status == "running" and s.hull < 1: return false
	if s.status == "won" and (s.mode == "endless" or s.delivered != s.target or s.stars < 1): return false
	for key in ["elapsed","remaining","limit","damage_cooldown","speed","par"]:
		if not _number(s[key],0,10000000): return false
	if s.speed < 1 or s.speed > 6 or s.limit > 250 or s.damage_cooldown > 3: return false
	for key in ["boats","tow","tow_positions","rocks","ferries","currents","trail","events"]:
		if not s[key] is Array: return false
	if s.boats.size() > 12 or s.tow.size() > s.capacity or s.tow_positions.size() != s.tow.size() or s.trail.is_empty() or s.trail.size() > 650: return false
	if s.rocks.size() > 12 or s.ferries.size() > 4 or s.currents.size() > 4: return false
	for p in s.trail + s.tow_positions:
		if not _point(p): return false
	var ids: Array = []
	var towed_ids: Array = []
	var delivered_count := 0
	for b in s.boats:
		if not b is Dictionary or not b.has_all(["id","pos","type","status"]): return false
		if not _number(b.id,0,100) or float(b.id) != floor(float(b.id)) or b.id in ids or not _point(b.pos) or not _number(b.type,0,4) or float(b.type) != floor(float(b.type)) or b.status not in ["afloat","towed","delivered"]: return false
		ids.append(b.id)
		if b.status == "towed": towed_ids.append(b.id)
		if b.status == "delivered": delivered_count += 1
	if s.mode != "endless" and (s.boats.size() != s.target or delivered_count != s.delivered): return false
	if towed_ids.size() != s.tow.size(): return false
	var seen: Array = []
	for id in s.tow:
		if id not in towed_ids or id in seen: return false
		seen.append(id)
	for r in s.rocks:
		if not r is Dictionary or not r.has_all(["pos","radius"]) or not _point(r.pos) or not _number(r.radius,0.1,5): return false
	for f in s.ferries:
		if not f is Dictionary or not f.has_all(["pos","origin","axis","speed","range","radius"]): return false
		if not _point(f.pos) or not _point(f.origin) or not _point(f.axis) or not _number(f.speed,0.1,5) or not _number(f.range,1,9) or not _number(f.radius,0.1,2): return false
	for c in s.currents:
		if not c is Dictionary or not c.has_all(["pos","radius","force"]) or not _point(c.pos) or not _point(c.force) or not _number(c.radius,0.1,5): return false
	return true
