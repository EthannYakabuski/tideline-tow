extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the project root after --")
		quit(1)
		return
	var root := args[0].replace("\\", "/").trim_suffix("/")
	for folder in ["assets/brand", "assets/brand/achievements", "assets/brand/leaderboards", "marketing/achievements", "marketing/leaderboards", "marketing/source"]:
		DirAccess.make_dir_recursive_absolute(root + "/" + folder)
	var icon := Image.load_from_file(root + "/marketing/source/app-icon-source.png")
	if icon == null:
		push_error("Missing app-icon-source.png")
		quit(1)
		return
	icon.save_png(root + "/marketing/source/app-icon-source.png")
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon.save_png(root + "/assets/brand/app-icon.png")
	icon.save_png(root + "/marketing/app-icon.png")
	var hero := Image.load_from_file(root + "/marketing/source/keyart-source.png")
	hero.save_png(root + "/marketing/source/keyart-source.png")
	hero.resize(1536, 750, Image.INTERPOLATE_LANCZOS)
	hero.save_png(root + "/assets/brand/keyart.png")
	hero.resize(1024, 500, Image.INTERPOLATE_LANCZOS)
	hero.save_png(root + "/marketing/feature-graphic.png")
	var splash := Image.load_from_file(root + "/marketing/source/splash-source.png")
	splash.save_png(root + "/marketing/source/splash-source.png")
	var target_height := roundi(splash.get_height() * 768.0 / splash.get_width())
	splash.resize(768, target_height, Image.INTERPOLATE_LANCZOS)
	splash.save_png(root + "/assets/brand/splash.png")
	splash.save_png(root + "/marketing/splash.png")
	var groups: Array = [["first_tow","first_delivery","convoy_three","convoy_six"],["rescue_25","rescue_100","rescue_500","clean_contract"],["cove_complete","dock_complete","strait_complete","campaign_complete"],["stars_30","stars_90","swift_contract","endless_1000"],["daily_watch","week_welcome","level_5","level_10"],["total_rescues","best_endless","skipper_xp","tow_emblem"]]
	for g in range(groups.size()):
		var sheet := Image.load_from_file(root + "/marketing/source/badges-" + str(g) + ".png")
		sheet.save_png(root + "/marketing/source/badges-" + str(g) + ".png")
		var w := sheet.get_width() / 2
		var h := sheet.get_height() / 2
		for i in range(4):
			var key: String = groups[g][i]
			var badge := sheet.get_region(Rect2i((i % 2) * w + 2, (i / 2) * h + 2, w - 4, h - 4))
			var folder := "leaderboards" if g == 5 else "achievements"
			if key == "tow_emblem":
				badge.resize(512,512,Image.INTERPOLATE_LANCZOS)
				badge.save_png(root + "/marketing/tow-emblem.png")
				continue
			badge.resize(512, 512, Image.INTERPOLATE_LANCZOS)
			badge.save_png(root + "/marketing/" + folder + "/" + key + ".png")
			badge.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			badge.save_png(root + "/assets/brand/" + folder + "/" + key + ".png")
	print("ART_PACKAGED: app icon512, feature1024x500, portrait splash, 20achievement and3leaderboard icons512+128.")
	quit()
