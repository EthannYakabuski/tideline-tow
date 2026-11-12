extends SceneTree

const Model = preload("res://game/tow_model.gd")
const Profile = preload("res://game/profile.gd")
const Content = preload("res://game/content.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	check(Content.campaign_count() == 30,"30 campaign contracts")
	check(Content.achievements().size() == 20,"20 achievement definitions")
	check(Content.boards().size() == 3,"three board definitions")
	var real_seed := Model.new()
	real_seed.begin("campaign",0,int(Time.get_unix_time_from_system()))
	check(Model.valid_snapshot(real_seed.snapshot()),"real epoch seed validates")
	real_seed.begin("daily",0,"2026-11-12".hash())
	check(Model.valid_snapshot(real_seed.snapshot()),"actual date hash seed validates")
	var m := Model.new()
	m.begin("campaign",0,123)
	_single_boat_fixture(m)
	check(Model.valid_snapshot(m.snapshot()),"initial snapshot validates")
	for i in range(65): m.step(0.02,Vector2.UP)
	check(m.state.tow.size() == 1,"movement hooks boat")
	var saved := m.snapshot()
	var restored := Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"JSON cold carrying snapshot restores")
	for i in range(30):
		m.step(0.02,Vector2.RIGHT)
		restored.step(0.02,Vector2.RIGHT)
	check(Model.vec(m.state.position).distance_to(Model.vec(restored.state.position)) < 0.00001,"restored movement deterministic")
	check(Model.vec(m.state.tow_positions[0]).distance_to(Model.vec(restored.state.tow_positions[0])) < 0.00001,"restored tow path deterministic")
	for i in range(110):
		var delta := Model.HARBOR - Model.vec(m.state.position)
		m.step(0.02,delta.normalized())
	check(m.state.status == "won" and m.state.delivered == 1,"complete isolated pickup-delivery fixture")
	var won := m.snapshot()
	check(m.step(1.0,Vector2.UP).is_empty() and m.snapshot() == won,"terminal run cannot advance")
	var p := Profile.new()
	p.advance_day("2026-11-12")
	var reward := p.settle(won)
	check(reward.ok and reward.coins > 0 and reward.xp > 0,"victory pays progression")
	var settled := p.data.duplicate(true)
	check(not p.settle(won).ok and p.data == settled,"result settlement is idempotent")
	check("first_tow" in p.achievements() and "first_delivery" in p.achievements(),"core achievements unlock from real result")
	check(p.data.stars[0] == 3 and p.unlocked_level() == 1,"victory stars unlock next contract")
	check(not p.purchase("rope"),"unaffordable upgrade rejected")
	p.data.coins = 10000
	for i in range(3): check(p.purchase("rope"),"rope rank %d purchased" % i)
	var coins_before: int = p.data.coins
	check(not p.purchase("rope") and p.data.coins == coins_before,"upgrade cap leaves currency unchanged")
	var invalid_profile := p.data.duplicate(true)
	invalid_profile.coins = 1.5
	check(not Profile.valid_data(invalid_profile),"fractional currency corruption rejected")
	_test_undelivered_convoy()
	m.begin("campaign",2,4)
	m.state.position = [-4.0,-2.0]
	m.state.trail = [[-4.0,-2.0],[-5.0,-2.0]]
	m.step(2.0,Vector2.RIGHT)
	check(m.state.damage >= 1 and m.state.position[0] < -2.0,"large frame cannot tunnel through rock")
	m.state.hull = 1
	m.state.damage_cooldown = 0.0
	m.step(0.1,Vector2.RIGHT)
	check(m.state.status == "failed","last hull loss ends run")
	check(m.revive() and m.state.hull == 2 and m.state.continued,"earned caller can revive once")
	m.state.status = "failed"
	check(not m.revive(),"revive cannot repeat")
	var original := m.snapshot()
	var corrupt := original.duplicate(true)
	corrupt.tow = [999]
	check(not m.restore(corrupt) and m.state == original,"invalid snapshot cannot partially replace state")
	corrupt = original.duplicate(true)
	corrupt.position = [INF,0]
	check(not m.restore(corrupt),"nonfinite positions rejected")
	m.begin("campaign",0,6)
	_single_boat_fixture(m)
	for i in range(60): m.step(0.02,Vector2.UP)
	var trail_before := Model.vec(m.state.trail[0])
	for i in range(200): m.step(0.02,Vector2(0.005,0))
	check(Model.vec(m.state.trail[0]).x > trail_before.x+0.05 and Model.vec(m.state.trail[0]).distance_to(Model.vec(m.state.position)) < 0.041,"very slow analog movement advances tow trail within sample tolerance")
	_test_slow_convoy()
	m.begin("campaign",7,7)
	m.step(0.001,Vector2.ZERO)
	check(absf(m.state.ferries[0].pos[0]) < 0.01,"ferry starts continuously from authored position")
	var elapsed: float = m.state.elapsed
	m.step(-1.0,Vector2.UP)
	m.step(NAN,Vector2.UP)
	check(m.state.elapsed == elapsed,"invalid delta does not advance time")
	var no_input := Model.vec(m.state.position)
	m.step(0.1,Vector2.ZERO)
	check(Model.vec(m.state.position) == no_input,"release anchors tug")
	_test_daily()
	_test_save(won)
	if "--fast" not in OS.get_cmdline_user_args():
		_test_campaign()
		_test_endless()
	print("TIDELINE MODEL CHECKS: %d passed / %d total" % [checks-failures.size(),checks])
	if not failures.is_empty():
		for failure in failures: print("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)

func _test_daily() -> void:
	var p := Profile.new()
	check(p.claim_login("2026-11-12").ok,"first login claim")
	var coins: int = p.data.coins
	check(not p.claim_login("2026-11-12").ok and p.data.coins == coins,"same-day gift cannot repeat")
	check(not p.claim_login("2026-11-11").ok,"rollback cannot claim old gift")
	for day in range(13,19): check(p.claim_login("2026-11-%02d" % day).ok,"streak day %d" % day)
	check(p.data.login.streak == 7 and "week_welcome" in p.achievements(),"seventh day unlock persists")
	check(p.claim_login("2026-11-19").day == 1,"gift cycle restarts after seven")
	check(p.claim_login("2026-11-22").day == 1,"missed days restart streak")
	check(not p.claim_login("2026-13-01").ok,"invalid date rejected")
	p.data.daily.rescues = 8
	check(p.quest_claim("rescues","2026-11-22").ok,"completed daily goal pays")
	coins = p.data.coins
	check(not p.quest_claim("rescues","2026-11-22").ok and p.data.coins == coins,"daily goal claim idempotent")
	p.advance_day("2026-11-23")
	check(p.data.daily.rescues == 0 and p.data.daily.claimed.is_empty(),"new UTC day resets goals")
	p.advance_day("2026-11-21")
	check(p.data.day == "2026-11-23","clock rollback preserves newest daily period")
	var a := Model.new()
	var b := Model.new()
	a.begin("daily",0,20261112)
	b.begin("daily",0,20261112)
	check(a.state.boats == b.state.boats and a.state.rocks == b.state.rocks,"daily layout deterministic")

func _test_slow_convoy() -> void:
	var model := Model.new()
	model.begin("endless",0,919,{"rope":3})
	# Six-boat fixture exercises long-distance low analog steering without timer,
	# pickups, delivery or obstacle interference; the actual path recorder is used.
	model.state.position=[-7.0,-10.0]
	model.state.heading=[1.0,0.0]
	model.state.trail=[[-7.0,-10.0],[-8.0,-10.0]]
	model.state.rocks=[]
	model.state.ferries=[]
	model.state.currents=[]
	model.state.remaining=5000.0
	model.state.boats=[]
	model.state.tow=[]
	for id in range(6):
		model.state.boats.append({"id":id,"pos":[-7.0,-10.0],"type":id%5,"status":"towed"})
		model.state.tow.append(id)
	for target in [Vector2(7,-10),Vector2(7,0),Vector2(-7,0),Vector2(-7,8)]:
		var loops:=0
		while Model.vec(model.state.position).distance_to(target)>0.05 and loops<1000:
			var offset:Vector2=target-Model.vec(model.state.position)
			var dt:=minf(1.0,offset.length()/(float(model.state.speed)*0.05*0.85))
			model.step(dt,offset.normalized()*0.05)
			loops+=1
		check(loops<1000,"slow convoy reaches long-path waypoint")
	check(model.state.tow_positions.size()==6,"all six slow-moving tow positions retained")
	check(model.state.trail.size()<=650,"distance-sampled trail remains bounded")
	var retained_length:=0.0
	for i in range(1,model.state.trail.size()):
		retained_length+=Model.vec(model.state.trail[i-1]).distance_to(Model.vec(model.state.trail[i]))
	check(retained_length>6.0*Model.BOAT_SPACING,"bounded trail retains whole six-boat convoy after long slow travel")
	check(Model.vec(model.state.trail[0]).distance_to(Model.vec(model.state.position))<0.041,"slow trail head stays attached to tug")
	# At the last corner the tail must still be on the preceding horizontal leg.
	var tail:=Model.vec(model.state.tow_positions[5])
	check(absf(tail.y)<0.08 and tail.x>-6.0 and tail.x<-1.5,"sixth boat follows historical turn instead of stale trail extrapolation")
	for i in range(1,model.state.tow_positions.size()):
		check(Model.vec(model.state.tow_positions[i-1]).distance_to(Model.vec(model.state.tow_positions[i]))>1.4,"adjacent hulls retain visual clearance around turn")
	model.state.status="failed"
	check(model.revive(),"six-boat convoy can revive")
	var inside:=true
	for point in model.state.tow_positions:
		if absf(point[0])>8.5 or point[1]<-12.0 or point[1]>11.5: inside=false
	check(inside,"revived six-boat convoy remains within harbor world bounds")

func _test_undelivered_convoy() -> void:
	var empty_watch:=Model.new()
	empty_watch.begin("campaign",0,91)
	empty_watch.end_run()
	var empty_profile:=Profile.new()
	var empty_reward:Dictionary=empty_profile.settle(empty_watch.snapshot())
	check(empty_reward.ok and empty_reward.coins==0 and empty_reward.xp==0 and empty_profile.data.coins==0 and empty_profile.data.xp==0,"zero-work finish cannot farm coins or XP")
	var model:=Model.new()
	model.begin("campaign",0,92)
	model.state.boats=[{"id":0,"pos":[0.0,1.0],"type":0,"status":"afloat"},{"id":1,"pos":[0.2,1.0],"type":1,"status":"afloat"},{"id":2,"pos":[-0.2,1.0],"type":2,"status":"afloat"}]
	for i in range(65): model.step(0.02,Vector2.UP)
	check(model.state.tow.size()==3 and model.state.max_convoy==0,"hooking three does not count as delivering a convoy")
	model.end_run()
	var profile:=Profile.new()
	var active_reward:Dictionary=profile.settle(model.snapshot())
	check(active_reward.ok and active_reward.coins==5 and active_reward.xp==10,"actual unsuccessful rescue activity retains modest consolation")
	check("convoy_three" not in profile.achievements(),"undelivered convoy never awards delivery achievement")
	model.state.status="running"
	model.state.hull=1
	model.state.damage_cooldown=0.0
	model._damage("fixture ferry")
	check(model.state.status=="failed" and model.state.tow.size()==2,"fatal collision drops one of three held boats")
	check(Model.valid_snapshot(model.snapshot()),"fatal carrying collision retains coherent terminal tow snapshot")

func _test_save(won: Dictionary) -> void:
	var root_path := OS.get_environment("TIDELINE_TEST_ROOT")
	if root_path.is_empty():
		root_path = OS.get_environment("TEMP").path_join("tideline-tow-tests") if OS.get_name() == "Windows" else "/tmp/tideline-tow-tests"
	var path := root_path.path_join("model-%d" % Time.get_ticks_usec()).path_join("profile.json")
	var p := Profile.new()
	p.advance_day("2026-11-12")
	p.settle(won)
	check(p.save_to(path),"initial atomic save succeeds")
	var first := p.data.duplicate(true)
	p.data.coins += 20
	check(p.save_to(path),"subsequent save replaces primary and preserves backup")
	var restored := Profile.new()
	var loaded := restored.load_from(path)
	if loaded:
		for key in p.data:
			if not _equivalent(restored.data[key],p.data[key]): print("SAVE DIFFERENCE %s expected=%s actual=%s" % [key,p.data[key],restored.data[key]])
	check(loaded and _equivalent(restored.data,p.data),"save cold-load is exact")
	check(not restored.settle(won).ok,"settled run stays paid once across cold load")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(restored.load_from(path) and restored.recovered_backup and _equivalent(restored.data,first),"corrupt primary recovers genuine previous backup")
	check(restored.save_to(path),"recovered profile can save without destroying good backup")
	var invalid := restored.data.duplicate(true)
	restored.data.coins = -2
	check(not restored.save_to(path),"invalid profile cannot overwrite disk")
	restored.data = invalid
	var m := Model.new()
	m.begin("campaign",0,8)
	_single_boat_fixture(m)
	for i in range(60): m.step(0.02,Vector2.UP)
	restored.data.active = m.snapshot()
	check(restored.save_to(path),"active carrying run persists")
	var carrying := Profile.new()
	check(carrying.load_from(path) and carrying.data.active.tow.size() == 1,"cold active profile retains convoy")
	var before := carrying.data.duplicate(true)
	check(not carrying.load_from(path+".missing") and carrying.data == before,"failed read preserves in-memory profile")
	# Only this test's individually named files are removed; never genuine game user:// saves.
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	DirAccess.remove_absolute(path.get_base_dir())

func _single_boat_fixture(model: RefCounted) -> void:
	model.state.boats = [{"id":0,"pos":[0.0,1.0],"type":0,"status":"afloat"}]
	model.state.target = 1

func _equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not _equivalent(a[i],b[i]): return false
		return true
	return a == b

func _path(model: RefCounted, target: Vector2) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,35,49)
	grid.cell_size = Vector2(0.5,0.5)
	grid.offset = Vector2(-8.5,-12)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(35):
		for y in range(49):
			var p := Vector2(-8.5+x*0.5,-12+y*0.5)
			var solid := false
			for rock in model.state.rocks:
				if p.distance_to(Model.vec(rock.pos)) < float(rock.radius)+0.9: solid = true
			for ferry in model.state.ferries:
				if p.distance_to(Model.vec(ferry.pos)) < 2.2: solid = true
			grid.set_point_solid(Vector2i(x,y),solid)
	var from := Vector2i(roundi((model.state.position[0]+8.5)*2),roundi((model.state.position[1]+12)*2))
	var to := Vector2i(roundi((target.x+8.5)*2),roundi((target.y+12)*2))
	grid.set_point_solid(from,false)
	grid.set_point_solid(to,false)
	return grid.get_point_path(from,to)

func _baseline(model: RefCounted, until_delivered: int = -1) -> void:
	var steps := 0
	var route:Array[Vector2]=[]
	var was_carrying:=false
	while model.state.status == "running" and steps < 4000:
		if until_delivered >= 0 and model.state.delivered >= until_delivered: return
		var pos := Model.vec(model.state.position)
		var carrying:bool=not model.state.tow.is_empty()
		if route.is_empty() or carrying!=was_carrying:
			var destination:=Model.HARBOR
			if not carrying:
				var best := INF
				for boat in model.state.boats:
					if boat.status == "afloat" and pos.distance_to(Model.vec(boat.pos)) < best:
						best = pos.distance_to(Model.vec(boat.pos))
						destination = Model.vec(boat.pos)
			route=[]
			if not model.state.ferries.is_empty():
				# A conservative skipper uses the open outer channel. Avoid planning
				# for just the tug and then letting a ferry strike its trailing boat.
				var edge:=8.0 if (pos.x if carrying else destination.x)>=0 else -8.0
				if not carrying:
					for ferry in model.state.ferries:
						var offset_y:float=destination.y-float(ferry.origin[1])
						if absf(offset_y)<2.1: destination.y+=0.7*(1.0 if offset_y>=0 else -1.0)
				route.append(Vector2(edge,pos.y))
				route.append(Vector2(edge,destination.y))
			route.append(destination)
			was_carrying=carrying
		while route.size()>1 and pos.distance_to(route[0])<0.4: route.pop_front()
		var target:Vector2=route[0]
		var path := _path(model,target)
		var next := target
		if path.size() > 1:
			next = path[1]
			if pos.distance_to(next) < 0.25 and path.size() > 2: next = path[2]
		elif path.is_empty():
			model.step(0.1,Vector2.ZERO)
			steps += 1
			continue
		model.step(0.1,(next-pos).normalized())
		steps += 1

func _test_campaign() -> void:
	for index in range(30):
		var model := Model.new()
		model.begin("campaign",index,100+index)
		_baseline(model)
		check(model.state.status == "won","contract %02d baseline completes: %s / rescued %s / hull %s / elapsed %.1f" % [index+1,model.state.status,model.state.delivered,model.state.hull,model.state.elapsed])
		check(Model.valid_snapshot(model.snapshot()),"contract %02d end state remains valid" % (index+1))
		print("CONTRACT %02d %s %.1fs damage=%d" % [index+1,model.state.status,model.state.elapsed,model.state.damage])

func _test_endless() -> void:
	var model := Model.new()
	model.begin("endless",0,1001)
	_baseline(model,7)
	check(model.state.delivered >= 7 and model.state.status == "running","endless continues and respawns through multiple deliveries")
	check(model.state.boats.size() <= 7 and model.state.endless_wave >= 2,"endless entity count bounded and pressure rises")
	check(Model.valid_snapshot(model.snapshot()),"endless snapshot valid after wave transitions")
