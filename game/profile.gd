extends RefCounted

const Content = preload("res://game/content.gd")
const TowModel = preload("res://game/tow_model.gd")
var data: Dictionary = {}
var recovered_backup := false
var last_error := ""

func _init() -> void:
	reset()

func reset() -> void:
	var stars: Array = []
	stars.resize(30)
	stars.fill(0)
	data = {"version":1,"xp":0,"coins":0,"upgrades":{"rope":0,"engine":0,"hull":0},"stars":stars,"unlocked":[],
		"stats":{"rescues":0,"rounds":0,"pickups":0,"convoy":0,"clean":0,"daily_wins":0},"best_endless":0,"settled":[],"active":{},"day":"",
		"daily":{"rescues":0,"deliveries":0,"score":0,"claimed":[]},"login":{"last_day":"","streak":0,"claimed_days":[]},
		"settings":{"music":true,"effects":true,"reduced_motion":false}}

func level() -> int:
	return int(floor(sqrt(float(data.xp) / 100.0))) + 1

func xp_for_level(rank: int) -> int:
	return (maxi(rank, 1) - 1) * (maxi(rank, 1) - 1) * 100

func unlocked_level() -> int:
	for i in range(30):
		if data.stars[i] == 0:
			return i
	return 29

func total_stars() -> int:
	var total := 0
	for n in data.stars: total += int(n)
	return total

func upgrade_cost(key: String) -> int:
	if key not in ["rope","engine","hull"]: return 0
	var rank: int = int(data.upgrades[key])
	return 500 if key == "hull" else (180 if key == "rope" else 150) * (rank + 1) * (rank + 1)

func upgrade_max(key: String) -> int:
	return 1 if key == "hull" else 3

func purchase(key: String) -> bool:
	if key not in ["rope","engine","hull"] or data.upgrades[key] >= upgrade_max(key): return false
	var cost := upgrade_cost(key)
	if data.coins < cost: return false
	data.coins -= cost
	data.upgrades[key] += 1
	return true

func settle(run: Dictionary) -> Dictionary:
	if not TowModel.valid_snapshot(run) or run.status not in ["won","failed"] or run.run_id in data.settled:
		return {"ok":false,"coins":0,"xp":0,"new_achievements":[]}
	var previous_level := level()
	var previous_unlocks: Array = data.unlocked.duplicate()
	var won: bool = run.status == "won"
	var active_watch:bool=int(run.pickups)>0 or int(run.delivered)>0
	var consolation_coins:=5 if active_watch else 0
	var consolation_xp:=10 if active_watch else 0
	var earned_coins: int = int(run.delivered) * 18 + int(run.score) / 20 + (30 if won else consolation_coins)
	var earned_xp: int = int(run.delivered) * 20 + (40 if won else consolation_xp)
	data.coins += earned_coins
	data.xp += earned_xp
	data.stats.rescues += int(run.delivered)
	data.stats.rounds += 1
	data.stats.pickups += int(run.pickups)
	data.stats.convoy = maxi(data.stats.convoy, int(run.max_convoy))
	if won and run.damage == 0:
		data.stats.clean += 1
	if won and run.remaining >= run.limit * 0.5:
		_unlock("swift_contract")
	if run.mode == "campaign" and won:
		data.stars[int(run.level)] = maxi(int(data.stars[int(run.level)]), int(run.stars))
	if run.mode == "endless":
		data.best_endless = maxi(data.best_endless, int(run.score))
	if run.mode == "daily" and won:
		data.stats.daily_wins += 1
	data.daily.rescues += int(run.delivered)
	data.daily.deliveries += int(run.deliveries)
	data.daily.score += int(run.score)
	data.settled.append(run.run_id)
	# Active run/result state is cleared only by successful once-only settlement.
	data.active = {}
	var rank_bonus := maxi(0, level() - previous_level) * 50
	data.coins += rank_bonus
	_refresh_achievements()
	var earned: Array = []
	for key in data.unlocked:
		if key not in previous_unlocks: earned.append(key)
	return {"ok":true,"coins":earned_coins+rank_bonus,"xp":earned_xp,"level_bonus":rank_bonus,"level":level(),"stars":run.stars,"new_achievements":earned}

func advance_day(day: String) -> void:
	if _day_number(day) < 0: return
	if data.day.is_empty() or day > data.day:
		data.day = day
		data.daily = {"rescues":0,"deliveries":0,"score":0,"claimed":[]}

func claim_login(day: String) -> Dictionary:
	var day_number := _day_number(day)
	if day_number < 0 or (not data.login.last_day.is_empty() and day <= data.login.last_day):
		return {"ok":false,"coins":0,"day":int(data.login.streak)}
	advance_day(day)
	var previous_day := _day_number(data.login.last_day)
	var streak: int = (int(data.login.streak) % 7) + 1 if day_number - previous_day == 1 else 1
	var gifts := [25,35,45,60,75,100,180]
	var gift: int = gifts[streak-1]
	data.login.last_day = day
	data.login.streak = streak
	data.login.claimed_days.append(day)
	if data.login.claimed_days.size() > 32: data.login.claimed_days.pop_front()
	data.coins += gift
	if streak == 7: _unlock("week_welcome")
	return {"ok":true,"coins":gift,"day":streak}

func quest_claim(key: String, day: String) -> Dictionary:
	advance_day(day)
	if day != data.day or key in data.daily.claimed:
		return {"ok":false,"coins":0,"xp":0}
	for quest in Content.quests():
		if quest.key == key and int(data.daily.get(key,0)) >= int(quest.target):
			data.daily.claimed.append(key)
			data.coins += int(quest.coins)
			var previous_level := level()
			data.xp += int(quest.xp)
			var rank_bonus := maxi(0,level()-previous_level)*50
			data.coins += rank_bonus
			_refresh_achievements()
			return {"ok":true,"coins":int(quest.coins)+rank_bonus,"xp":int(quest.xp)}
	return {"ok":false,"coins":0,"xp":0}

func achievements() -> Array:
	_refresh_achievements()
	return data.unlocked.duplicate()

func boards() -> Dictionary:
	return {"total_rescues":int(data.stats.rescues),"best_endless":int(data.best_endless),"skipper_xp":int(data.xp)}

func _unlock(key: String) -> void:
	if key not in data.unlocked: data.unlocked.append(key)

func _refresh_achievements() -> void:
	if data.stats.pickups >= 1: _unlock("first_tow")
	if data.stats.rescues >= 1: _unlock("first_delivery")
	if data.stats.convoy >= 3: _unlock("convoy_three")
	if data.stats.convoy >= 6: _unlock("convoy_six")
	if data.stats.rescues >= 25: _unlock("rescue_25")
	if data.stats.rescues >= 100: _unlock("rescue_100")
	if data.stats.rescues >= 500: _unlock("rescue_500")
	var completed := 0
	for district in range(3):
		var district_complete := true
		for i in range(district*10,district*10+10):
			if data.stars[i] < 1: district_complete = false
			else: completed += 1
		if district_complete: _unlock(["cove_complete","dock_complete","strait_complete"][district])
	if completed == 30: _unlock("campaign_complete")
	if total_stars() >= 30: _unlock("stars_30")
	if total_stars() >= 90: _unlock("stars_90")
	if data.stats.clean >= 1: _unlock("clean_contract")
	if data.best_endless >= 1000: _unlock("endless_1000")
	if data.stats.daily_wins >= 1: _unlock("daily_watch")
	if level() >= 5: _unlock("level_5")
	if level() >= 10: _unlock("level_10")

static func utc_day() -> String:
	return Time.get_date_string_from_system(true)

static func _day_number(day: String) -> int:
	if day.length() != 10 or day[4] != "-" or day[7] != "-": return -1
	var segments := day.split("-")
	if segments.size() != 3 or not segments[0].is_valid_int() or not segments[1].is_valid_int() or not segments[2].is_valid_int(): return -1
	if int(segments[0]) < 2020 or int(segments[0]) > 2200 or int(segments[1]) < 1 or int(segments[1]) > 12 or int(segments[2]) < 1 or int(segments[2]) > 31: return -1
	var stamp := Time.get_unix_time_from_datetime_string(day+"T00:00:00")
	if Time.get_date_string_from_unix_time(stamp) != day: return -1
	return int(stamp / 86400)

func save_to(path: String) -> bool:
	last_error = ""
	if not valid_data(data):
		last_error = "Profile validation failed"
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Cannot create save folder"
		return false
	var body := JSON.stringify(data)
	var envelope := JSON.stringify({"version":1,"body":body,"sha256":body.sha256_text()})
	var temp_path := absolute + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot write save"
		return false
	file.store_string(envelope)
	file.flush()
	file.close()
	if _read_valid(temp_path).is_empty():
		last_error = "Save verification failed"
		return false
	# Never replace the good backup with a corrupt primary.
	if FileAccess.file_exists(absolute) and not _read_valid(absolute).is_empty():
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			last_error = "Cannot preserve backup"
			return false
	if DirAccess.rename_absolute(temp_path, absolute) != OK:
		last_error = "Cannot finish save"
		return false
	return true

func load_from(path: String) -> bool:
	recovered_backup = false
	last_error = ""
	var found := _read_valid(path)
	if found.is_empty():
		found = _read_valid(path + ".bak")
		if found.is_empty():
			last_error = "No valid saved profile"
			return false
		recovered_backup = true
	data = found
	_refresh_achievements()
	return true

static func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 4000000: return {}
	var decoder := JSON.new()
	var parse_result := decoder.parse(file.get_as_text())
	file.close()
	if parse_result != OK: return {}
	var parsed: Variant = decoder.data
	if not parsed is Dictionary or not parsed.has_all(["version","body","sha256"]): return {}
	if parsed.version != 1 or not parsed.body is String or not parsed.sha256 is String or parsed.body.sha256_text() != parsed.sha256: return {}
	if decoder.parse(parsed.body) != OK: return {}
	var candidate: Variant = decoder.data
	if not candidate is Dictionary or not valid_data(candidate): return {}
	return candidate

static func valid_data(d: Dictionary) -> bool:
	if not d.has_all(["version","xp","coins","upgrades","stars","unlocked","stats","best_endless","settled","active","day","daily","login","settings"]): return false
	if d.version != 1 or not _whole(d.xp,0,100000000) or not _whole(d.coins,0,100000000) or not _whole(d.best_endless,0,100000000): return false
	if not d.upgrades is Dictionary or not d.upgrades.has_all(["rope","engine","hull"]): return false
	if not _whole(d.upgrades.rope,0,3) or not _whole(d.upgrades.engine,0,3) or not _whole(d.upgrades.hull,0,1): return false
	if not d.stars is Array or d.stars.size() != 30: return false
	for n in d.stars:
		if not TowModel._number(n,0,3) or float(n) != floor(float(n)): return false
	if not d.stats is Dictionary or not d.stats.has_all(["rescues","rounds","pickups","convoy","clean","daily_wins"]): return false
	for n in d.stats.values():
		if not _whole(n,0,100000000): return false
	if not d.active is Dictionary or (not d.active.is_empty() and not TowModel.valid_snapshot(d.active)): return false
	if not d.unlocked is Array or d.unlocked.size() > 20 or not d.settled is Array or d.settled.size() > 100000: return false
	var valid_keys: Array = []
	for achievement in Content.achievements(): valid_keys.append(achievement.key)
	var seen: Array = []
	for key in d.unlocked:
		if not key is String or key not in valid_keys or key in seen: return false
		seen.append(key)
	for key in d.settled:
		if not key is String or key.is_empty() or key.length() > 120: return false
	if not d.day is String or (not d.day.is_empty() and _day_number(d.day) < 0): return false
	if not d.daily is Dictionary or not d.daily.has_all(["rescues","deliveries","score","claimed"]) or not d.daily.claimed is Array: return false
	for key in ["rescues","deliveries","score"]:
		if not _whole(d.daily[key],0,100000000): return false
	if d.daily.claimed.size() > 3: return false
	for key in d.daily.claimed:
		if key not in ["rescues","deliveries","score"]: return false
	if not d.login is Dictionary or not d.login.has_all(["last_day","streak","claimed_days"]): return false
	if not d.login.last_day is String or (not d.login.last_day.is_empty() and _day_number(d.login.last_day) < 0) or not _whole(d.login.streak,0,7) or not d.login.claimed_days is Array or d.login.claimed_days.size() > 32: return false
	for day in d.login.claimed_days:
		if not day is String or _day_number(day) < 0: return false
	if not d.settings is Dictionary or not d.settings.has_all(["music","effects","reduced_motion"]): return false
	for key in ["music","effects","reduced_motion"]:
		if not d.settings[key] is bool: return false
	return true

static func _whole(value: Variant, low: int, high: int) -> bool:
	return TowModel._number(value,low,high) and float(value) == floor(float(value))
