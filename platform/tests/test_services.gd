extends Node
## Isolated adapter fixtures, not native ad presentation or real PGS proof.

const Adapter = preload("res://platform/services.gd")
var passed := 0
var failed := 0

class FakeSignIn extends PlayGamesSignInClient:
	var checks := 0
	var requests := 0
	func is_authenticated() -> void: checks += 1
	func sign_in() -> void: requests += 1

class FakeAchievements extends PlayGamesAchievementsClient:
	var requests: Array[String] = []
	func unlock_achievement(id: String) -> void: requests.append(id)

class FakeBoards extends PlayGamesLeaderboardsClient:
	var requests: Array[Dictionary] = []
	func submit_score(id: String, value: int) -> void: requests.append({"id":id,"value":value})

class RewardHarness extends "res://platform/services.gd":
	func can_reward() -> bool: return not fullscreen_ad_active()
	func reward_requested(context: String, callback: Callable) -> void:
		_reward_context = context
		_reward_callback = callback
		_reward_granted = false
		_reward_showing = true
		_reward_request_serial += 1
		_refresh_fullscreen_signal()

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("PLATFORM FAIL: " + label)

func write_file(path: String, data: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert(f != null)
	f.store_string(data)
	f.close()

func _run() -> void:
	var adapter := Adapter.new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/test-platform"))
	adapter.pending_path = "res://build/test-platform/pending-%d.json" % Time.get_ticks_usec()
	adapter.settings = {"admob":{"test_mode":false,"rewarded_unit_id":"release-placeholder"}, "play_games":{"enabled":false,"game_id":"","achievements":{"first_tow":"achievement-a","level_5":"achievement-b"},"leaderboards":{"best_endless":"board-a","skipper_xp":"board-b"}}}
	var shipping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://platform/config.json"))
	check(shipping.admob.test_mode and not shipping.play_games.enabled,"shipping uses test ads and disabled PGS")
	check(shipping.play_games.achievements.size() == 20 and shipping.play_games.leaderboards.size() == 3,"shipping mappings cover all 20 achievements and 3 boards")
	check(shipping.play_games.game_id.is_empty() and shipping.play_games.achievements.values().all(func(value): return value == "") and shipping.play_games.leaderboards.values().all(func(value): return value == ""),"production backend IDs remain blank")
	check(Adapter._ad_id_for_build(adapter.settings,"rewarded",true) == Adapter.TEST_AD_UNIT_IDS.rewarded,"debug overrides release mapping")
	check(Adapter._ad_id_for_build(adapter.settings,"rewarded",false) == "release-placeholder","release uses explicit mapping")
	check(Adapter._ad_id_for_build({},"banner",false) == Adapter.TEST_AD_UNIT_IDS.banner,"missing config defaults to test")
	check(Adapter._ad_id_for_build({},"unknown",true).is_empty(),"unknown format rejected")
	check(Adapter._safe_probe_namespace("run-1_A") == "run-1_A","valid acceptance namespace retained")
	check(Adapter._safe_probe_namespace("../../profile") == "acceptance","probe traversal cannot touch genuine journal")
	check(Adapter._safe_probe_namespace(99) == "acceptance","malformed probe namespace rejected")
	check(not adapter.can_reward(),"editor/web has no native reward")
	check(not adapter.request_rewarded_continue("run-a"),"unavailable request rejected")
	check(adapter._rewarded_runs.is_empty(),"unavailable never consumes or grants a reward")
	check(not adapter.request_rewarded_continue(""),"empty run ID rejected")
	var outcomes: Array[bool] = []
	adapter._reward_callback = func(earned: bool) -> void: outcomes.append(earned)
	adapter._reward_showing = true
	adapter._reward_context = "fixture-run"
	adapter._earned_reward(null)
	adapter._earned_reward(null)
	check(outcomes == [true],"duplicate earned callbacks deliver once")
	check(adapter.fullscreen_ad_active(),"earning does not end fullscreen")
	adapter._rewarded_closed()
	check(outcomes == [true],"earned dismissal cannot issue second decision")
	check(not adapter.fullscreen_ad_active(),"reward dismissal clears fullscreen")
	adapter._reward_granted = false
	adapter._reward_showing = true
	adapter._reward_callback = func(earned: bool) -> void: outcomes.append(earned)
	adapter._rewarded_closed()
	check(outcomes == [true,false],"early closure reports unearned")
	adapter._earned_reward(null)
	check(outcomes == [true,false],"late earned callback after closure is ignored")
	adapter._reward_showing = true
	adapter._reward_callback = func(earned: bool) -> void: outcomes.append(earned)
	adapter._earned_reward_for_request(null, adapter._reward_request_serial - 1)
	check(outcomes == [true,false],"prior ad's earned callback cannot pay the new request")
	adapter._rewarded_closed()
	var rewards := RewardHarness.new()
	var earned_runs: Array[String] = []
	var finished_runs: Array[Dictionary] = []
	rewards.reward_earned.connect(func(id: String) -> void: earned_runs.append(id))
	rewards.reward_finished.connect(func(id: String, earned: bool) -> void: finished_runs.append({"id":id,"earned":earned}))
	check(rewards.request_rewarded_continue("one"),"opt-in run request enters pending fixture")
	check(not rewards.request_rewarded_continue("two"),"concurrent reward request rejected")
	rewards._earned_reward_for_request(null,rewards._reward_request_serial)
	rewards._earned_reward_for_request(null,rewards._reward_request_serial)
	check(earned_runs == ["one"],"one earned signal per run")
	check(finished_runs == [{"id":"one","earned":true}],"earned decision emitted once")
	rewards._rewarded_closed()
	check(not rewards.request_rewarded_continue("one"),"already earned run cannot request twice")
	check(rewards.request_rewarded_continue("two"),"different run can request after dismissal")
	rewards._rewarded_closed()
	check(earned_runs == ["one"] and finished_runs.back() == {"id":"two","earned":false},"early dismissal has no reward signal")
	rewards.free()
	var fullscreens: Array[bool] = []
	adapter.fullscreen_changed.connect(func(value: bool) -> void: fullscreens.append(value))
	adapter._consent_showing = true
	adapter._refresh_fullscreen_signal()
	adapter._refresh_fullscreen_signal()
	adapter._consent_showing = false
	adapter._refresh_fullscreen_signal()
	check(fullscreens == [true,false],"consent fullscreen changes emitted once")
	adapter._on_ads_initialized(null)
	check(not adapter._ads_ready,"late initialization cannot bypass blocked consent")
	adapter._ads_ready = true
	adapter._ads_permitted = true
	adapter._pause_ad_requests()
	check(not adapter._ads_ready and not adapter._ads_permitted,"privacy changes pause cached ad use")
	adapter.round_completed(1,"one")
	adapter.round_completed(3,"three")
	adapter.round_completed(3,"three")
	adapter.round_completed(2,"two")
	check(adapter._round_count == 3,"replayed or stale result counts cannot advance cadence")
	adapter.round_completed(4,"three")
	check(adapter._round_count == 3,"duplicate result ID cannot advance cadence")
	check(not adapter.fullscreen_ad_active(),"unavailable interstitial skipped")
	check(Adapter._menu_reserve_from_pixels(100,48,1,2) == 80.0,"native banner pixels converted to game units")
	check(Adapter._menu_reserve_from_pixels(0,0,1,1) == 62.0,"startup banner reserve remains usable")
	check(Adapter._menu_safe_bottom_pixels(900,1000,0,0,2,false) == 96.0,"empty safe rect avoids whole-screen reserve")
	check(Adapter._menu_safe_bottom_pixels(900,1000,1000,900,2,false) == 96.0,"navigation allowance retained")
	adapter.submit_progress(["first_tow","unknown"],{"best_endless":100,"skipper_xp":-1,"unknown":50})
	adapter.submit("best_endless",50)
	check(adapter._pending_unlocks.size() == 1 and adapter._pending_unlocks.has("first_tow"),"only configured achievement keys queued")
	check(adapter._pending_scores == {"best_endless":100},"records keep max and reject negative/unknown")
	adapter.submit_progress([],{"skipper_xp":NAN})
	adapter.submit_progress([],{"skipper_xp":2.5})
	check(not adapter._pending_scores.has("skipper_xp"),"nonfinite/fractional board values rejected")
	check(FileAccess.file_exists(adapter.pending_path),"desired progress persisted")
	write_file(adapter.pending_path + ".bak",JSON.stringify({"unlocks":{"level_5":true},"scores":{"best_endless":110}}))
	write_file(adapter.pending_path + ".tmp",JSON.stringify({"unlocks":{"unknown":true},"scores":{"skipper_xp":80,"best_endless":-4}}))
	write_file(adapter.pending_path,"{broken")
	adapter._load_pending()
	check(adapter._pending_unlocks == {"level_5":true},"corrupt primary recovers valid allowed backup unlock")
	check(adapter._pending_scores == {"best_endless":110,"skipper_xp":80},"backup and interrupted journal merge max records")
	adapter._start_play_games()
	check(not adapter._pgs_ready,"blank disabled PGS never starts native auth")
	var auth := FakeSignIn.new()
	var achievements := FakeAchievements.new()
	var boards := FakeBoards.new()
	adapter._bind_play_games_clients(auth,achievements,boards)
	check(auth.checks == 1 and auth.requests == 0,"first PGS check is noninteractive")
	adapter._authentication_changed(true)
	adapter._flush_pending()
	check(achievements.requests == ["achievement-b"],"authenticated unlock dispatched")
	check(boards.requests.size() == 2,"authenticated high scores dispatched")
	check(adapter._submitted_scores.is_empty(),"dispatch is not acknowledged success")
	adapter._score_submitted(true,"board-a")
	check(adapter._submitted_scores.best_endless.value == 110,"native success acknowledges matching score")
	adapter.submit("best_endless",200)
	adapter._flush_pending()
	check(boards.requests.back() == {"id":"board-a","value":200},"higher record submitted after acknowledgment")
	adapter._invalidate_play_games_requests()
	adapter._pgs_clock += 31.0
	adapter._flush_pending()
	adapter._score_submitted(true,"board-a")
	check(adapter._submitted_scores.best_endless.value == 110,"ambiguous late callback cannot acknowledge newer score")
	adapter._score_submitted(false,"board-a")
	check(adapter._pgs_needs_auth_check,"failed score causes reconnect before retry")
	adapter._authentication_changed(false)
	check(not adapter._signed_in,"cancelled auth leaves local progress usable")
	check(adapter._pending_scores.best_endless == 200,"auth cancellation retains durable desired record")
	adapter.sign_in()
	check(auth.requests == 1,"manual reconnect is explicit native sign-in")
	adapter._process_play_games(21.0)
	check(not adapter._pgs_auth_pending,"auth timeout clears pending state")
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = adapter.pending_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	adapter.free()
	print("PLATFORM_FIXTURES passed=%d failed=%d (scripted fixtures; no native presentation claimed)" % [passed,failed])
	get_tree().quit(1 if failed else 0)
