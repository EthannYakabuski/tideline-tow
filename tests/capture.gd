extends SceneTree
const Main=preload("res://game/main.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var selected:="home"
	var output:="res://build/capture.png"
	var profile_name:="phone"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):selected=arg.trim_prefix("--view=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--profile="):profile_name=arg.trim_prefix("--profile=")
	var target_size:Vector2i={"phone":Vector2i(1080,1920),"tablet7":Vector2i(800,1280),"tablet10":Vector2i(1200,1920)}.get(profile_name,Vector2i(1080,1920))
	DisplayServer.window_set_size(target_size)
	root.size=target_size
	await process_frame
	var app=Main.new()
	app.qa_mode=true
	root.add_child(app)
	await process_frame
	app.set_process(false)
	if selected in ["tow","result","journal","shipyard"]:
		app.start_run("campaign",0)
		for i in 2400:
			if app.model.state.status!="running":break
			app.model.step(1.0/30.0,app.autopilot_direction())
			if selected=="tow" and app.model.state.tow.size()>=3:break
		app.harbor.sync(app.model.state)
		app.update_hud()
		if selected!="tow":app.finish_run()
		if selected=="journal":app.show_journal()
		if selected=="shipyard":app.show_shipyard()
	elif selected=="campaign":app.show_campaign()
	elif selected=="daily":app.show_daily()
	elif selected=="district":
		app.start_run("campaign",23)
	elif selected=="copperdock":
		app.start_run("campaign",15)
	app.toast_label.visible=false
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error=image.save_png(output)
	print("CAPTURE ",selected," ",image.get_size()," result=",error," genuine_simulation=",selected in ["tow","result","journal","shipyard"])
	app.queue_free()
	await process_frame
	quit(error)
