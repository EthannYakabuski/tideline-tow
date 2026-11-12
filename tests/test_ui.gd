extends SceneTree

const Main=preload("res://game/main.gd")
const Profile=preload("res://game/profile.gd")

class FailingProfile extends Profile:
	func save_to(_path: String) -> bool:
		last_error = "Synthetic disk failure for transaction regression"
		return false

var checks:=0
var failures:=0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool,message:String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)

func _run() -> void:
	var app=Main.new()
	app.qa_mode=true
	root.add_child(app)
	await process_frame
	app.set_process(false)
	check(app.ready_complete,"main ready")
	check(app.screen=="home","initial home")
	check(app.profile.data.stats.rounds==0,"QA fresh profile")
	app.start_run("campaign",0,true)
	check(app.screen=="play","launch enters play immediately")
	check(app.model.state.status=="running","running contract")
	check(app.harbor.boat_nodes.size()==app.model.state.boats.size(),"all boats render")
	for node in app.harbor.boat_nodes.values():
		check(node.get_node("SOS").visible,"afloat SOS marker visible")
	app.pause_game("Paused","test")
	var elapsed:float=app.model.state.elapsed
	app._process(0.5)
	check(app.model.state.elapsed==elapsed,"pause freezes simulation")
	app.resume_play()
	app._fullscreen_changed(true)
	app._process(0.5)
	check(app.model.state.elapsed==elapsed,"native fullscreen freezes simulation")
	app._fullscreen_changed(false)
	check(not app.pause_reason.is_empty(),"native dismissal needs neutral resume")
	app.resume_play()
	app.steering=Vector2.UP
	app._process(0.1)
	check(app.model.state.elapsed>elapsed,"resume ticks")
	app.go_back()
	check(not app.pause_reason.is_empty(),"Back pauses")
	app.go_back()
	check(app.screen=="home","second Back saves to home")
	check(not app.profile.data.active.is_empty(),"active rescue retained")
	var saved_run_id:String=app.profile.data.active.run_id
	app.start_run("daily",0)
	check(app.screen=="home" and app.profile.data.active.run_id==saved_run_id,"new mode needs explicit active rescue replacement")
	app.resume_run()
	check(not app.pause_reason.is_empty(),"cold-style resume stays paused")
	app.resume_play()
	# Drive the actual introductory model into a successful delivery.
	for i in 2400:
		if app.model.state.status!="running":break
		app.model.step(1.0/30.0,app.autopilot_direction())
	check(app.model.state.status=="won","actual first contract solves")
	# A failed commit must leave the genuine earned run available for retry.
	var real_profile=app.profile
	var failed_profile=FailingProfile.new()
	failed_profile.data=real_profile.data.duplicate(true)
	app.profile=failed_profile
	app.profile_path="user://synthetic_failure.json"
	var before_failure:Dictionary=app.profile.data.duplicate(true)
	app.finish_run()
	check(app.profile.data==before_failure,"failed result save rolls back all payout and settlement fields")
	check(app.pause_reason=="save_error" and app.last_reward.is_empty(),"failed result offers retry without showing payment")
	app.profile=real_profile
	app.profile_path="user://profile_v1.json"
	app.finish_run()
	check(app.screen=="result","win result appears")
	check(app.profile.data.stats.rounds==1,"one settled result")
	var coins:int=app.profile.data.coins
	app.finish_run()
	check(app.profile.data.coins==coins,"result reopening cannot pay again")
	app.show_campaign()
	check(app.screen=="campaign","campaign screen")
	app.show_shipyard()
	check(app.screen=="shipyard","shipyard screen")
	failed_profile=FailingProfile.new()
	failed_profile.data=app.profile.data.duplicate(true)
	failed_profile.data.coins=1000 # Explicit affordability fixture; discarded below.
	app.profile=failed_profile
	app.profile_path="user://synthetic_failure.json"
	before_failure=app.profile.data.duplicate(true)
	app.purchase("rope")
	check(app.profile.data==before_failure,"failed upgrade save restores coins and gear")
	app.claim_login()
	check(app.profile.data==before_failure,"failed login save restores gift and streak")
	app.profile.data.daily.rescues=8 # Explicit completed-quest fixture; discarded below.
	before_failure=app.profile.data.duplicate(true)
	app.claim_quest("rescues")
	check(app.profile.data==before_failure,"failed quest save restores currency XP and claim flag")
	app.profile=real_profile
	app.profile_path="user://profile_v1.json"
	app.show_daily()
	check(app.screen=="daily","daily screen")
	app.claim_login()
	var claimed:int=app.profile.data.coins
	app.claim_login()
	check(app.profile.data.coins==claimed,"UI login claim idempotent")
	app.show_journal()
	check(app.screen=="journal","journal screen")
	app.show_options()
	check(app.screen=="options","options screen")
	# Isolated renderer fixture advances actual wave generation; this is not an earned run.
	app.start_run("endless",0)
	check(app.hud_time.text=="2:30","endless shows actual remaining deadline")
	for i in 3:
		app.model._next_wave()
		app.harbor.sync(app.model.state)
	check(app.harbor.ferry_nodes.size()==app.model.state.ferries.size(),"new wave ferry always visible")
	check(app.harbor.district==app.model.state.district,"endless district scene advances")
	check(app.harbor.boat_nodes.size()==app.model.state.boats.size(),"wave replacements remove stale boats")
	for node in app.harbor.boat_nodes.values():
		check(node.scale.is_equal_approx(Vector3.ONE),"new wave boats full scale after delivery")
	app.start_run("campaign",0,true)
	for i in 700:
		app.model.step(0.1,Vector2.ZERO)
	check(app.model.state.status=="failed","watch can timeout")
	app.show_failure()
	app.request_continue()
	check(not app.model.state.continued,"unavailable QA service never fabricates reward")
	app.queue_free()
	await process_frame
	await process_frame
	print("UI_ASSERTIONS %d FAILURES %d"%[checks,failures])
	quit(1 if failures else 0)
