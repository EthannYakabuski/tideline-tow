extends Control

const Model = preload("res://game/tow_model.gd")
const Profile = preload("res://game/profile.gd")
const Content = preload("res://game/content.gd")
const Harbor = preload("res://game/harbor.gd")
const Helm = preload("res://game/helm.gd")
const Audio = preload("res://game/audio.gd")
const INK := Color("113440")
const CREAM := Color("fff2d5")
const MUTED := Color("b9d7d9")
const CORAL := Color("f69b79")
const GOLD := Color("ffd17e")
const DISTRICTS := ["Sunwake Cove","Copperdock","Lantern Strait"]
var model = Model.new()
var profile = Profile.new()
var profile_path := "user://profile_v1.json"
var screen := "home"
var view: SubViewport
var viewport_holder: SubViewportContainer
var harbor: Node3D
var overlay: Control
var canvas: VBoxContainer
var modal: Control
var toast_label: Label
var audio: Node
var helm: Control
var hud_status: Label
var hud_score: Label
var hud_hearts: Label
var hud_time: Label
var hint: Label
var steering := Vector2.ZERO
var water_target := Vector2.ZERO
var water_held := false
var pause_reason := ""
var ad_locked := false
var reward_pending := false
var last_reward := {}
var save_clock := 0.0
var toast_clock := 0.0
var qa_mode := false
var ready_complete := false
var profile_error := ""
var probe := {}
var probe_events: Array = []
var probe_time := 0.0
var probe_phase := ""
var probe_captured := {}
var probe_path := ""
var probe_last_write := -1
var last_screen_before_pause := ""
var victory_pending := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().auto_accept_quit = false
	setup_theme()
	audio = Audio.new()
	add_child(audio)
	read_probe_config()
	if not qa_mode:
		profile.load_from(profile_path)
		if profile.recovered_backup:
			profile_error="Your harbor was recovered from its last good backup."
		elif FileAccess.file_exists(profile_path) and not profile.last_error.is_empty():
			profile_error="This save could not be read. A fresh harbor is open."
	profile.advance_day(today())
	audio.configure(profile.data.settings)
	build_base()
	connect_services()
	sync_progress()
	show_home()
	ready_complete = true
	if not probe.is_empty():
		start_probe.call_deferred()

func today() -> String:
	return Time.get_date_string_from_system(true)

func setup_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color","Label",CREAM)
	t.set_color("font_color","Button",INK)
	t.set_color("font_hover_color","Button",INK)
	t.set_color("font_pressed_color","Button",INK)
	t.set_color("font_disabled_color","Button",Color("8ba3a9"))
	t.set_constant("outline_size","Label",0)
	t.set_constant("h_separation","HBoxContainer",12)
	t.set_constant("v_separation","VBoxContainer",10)
	t.set_stylebox("normal","Button",style(CREAM,16,14))
	t.set_stylebox("hover","Button",style(Color("fff9e9"),16,14))
	t.set_stylebox("pressed","Button",style(GOLD,16,14))
	t.set_stylebox("disabled","Button",style(Color("294d58"),16,14))
	t.set_stylebox("focus","Button",border_style(GOLD))
	t.set_stylebox("panel","PanelContainer",style(INK,20,18))
	t.set_stylebox("background","ProgressBar",style(Color("284d57"),7,0))
	t.set_stylebox("fill","ProgressBar",style(Color("7ed6c6"),7,0))
	theme = t

func style(color: Color, radius := 16, padding := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.content_margin_left=padding
	s.content_margin_right=padding
	s.content_margin_top=padding
	s.content_margin_bottom=padding
	return s

func border_style(color: Color) -> StyleBoxFlat:
	var s:=style(Color.TRANSPARENT,16,0)
	s.border_color=color
	s.set_border_width_all(3)
	return s

func build_base() -> void:
	var background := ColorRect.new()
	background.color=INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	viewport_holder=SubViewportContainer.new()
	viewport_holder.stretch=true
	viewport_holder.mouse_filter=Control.MOUSE_FILTER_STOP
	viewport_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(viewport_holder)
	view=SubViewport.new()
	view.size=Vector2i(540,960)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.msaa_3d=Viewport.MSAA_2X
	view.own_world_3d=true
	view.handle_input_locally=false
	viewport_holder.add_child(view)
	harbor=Harbor.new()
	view.add_child(harbor)
	harbor.reduced_motion=bool(profile.data.settings.get("reduced_motion",false))
	viewport_holder.gui_input.connect(_water_input)
	view.size_changed.connect(func(): harbor.frame_camera())
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	toast_label=Label.new()
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_stylebox_override("normal",style(Color("113440f2"),14,12))
	toast_label.add_theme_font_size_override("font_size",19)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left=-235
	toast_label.offset_right=235
	toast_label.offset_top=-172
	toast_label.offset_bottom=-118
	toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_label.visible=false
	add_child(toast_label)

func connect_services() -> void:
	var services := get_node_or_null("/root/Services")
	if services:
		services.fullscreen_changed.connect(_fullscreen_changed)
		services.reward_earned.connect(_reward_earned)
		services.reward_finished.connect(_reward_finished)
		services.service_notice.connect(func(message): toast(str(message)))
		services.menu_bottom_reserve_changed.connect(_banner_changed)

func sync_progress() -> void:
	var services:=get_node_or_null("/root/Services")
	if services and not qa_mode:
		services.submit_progress(profile.achievements(),profile.boards())

func _banner_changed() -> void:
	if screen=="home" or screen=="result":
		var spacer=overlay.find_child("BannerReserve",true,false)
		if spacer:
			spacer.custom_minimum_size.y=banner_reserve()

func banner_reserve() -> float:
	var services:=get_node_or_null("/root/Services")
	return services.menu_bottom_reserve(self)+10 if services and not qa_mode else 10.0

func clear_ui(new_screen: String) -> void:
	screen=new_screen
	steering=Vector2.ZERO
	water_held=false
	helm=null
	modal=null
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	viewport_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var services:=get_node_or_null("/root/Services")
	if services and not qa_mode:
		services.set_banner_visible(screen in ["home","result"])

func page(title: String, subtitle: String, back := true) -> VBoxContainer:
	clear_ui(title.to_lower().replace(" ","_"))
	var tint := ColorRect.new()
	tint.color=Color(0.025,0.12,0.16,0.86)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(tint)
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",22)
	margin.add_theme_constant_override("margin_right",22)
	margin.add_theme_constant_override("margin_top",24)
	margin.add_theme_constant_override("margin_bottom",16)
	overlay.add_child(margin)
	var outer:=VBoxContainer.new()
	margin.add_child(outer)
	var row:=HBoxContainer.new()
	outer.add_child(row)
	var title_label:=label(title,32)
	title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	if back:
		row.add_child(button("Back",show_home,false,76))
	if not subtitle.is_empty():
		outer.add_child(label(subtitle,18,MUTED))
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	canvas=VBoxContainer.new()
	canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	canvas.add_theme_constant_override("separation",12)
	scroll.add_child(canvas)
	return canvas

func label(text: String, font_size:=22, color:=CREAM) -> Label:
	var node:=Label.new()
	node.text=text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func button(text: String, action: Callable, primary:=false, width:=0) -> Button:
	var node:=Button.new()
	node.text=text
	node.custom_minimum_size=Vector2(width,56)
	node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size",22)
	if primary:
		node.add_theme_stylebox_override("normal",style(GOLD,16,14))
	node.pressed.connect(func(): audio.play_sfx("click"); action.call())
	return node

func panel(parent: Node, color:=INK) -> VBoxContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(color,20,17))
	parent.add_child(p)
	var box:=VBoxContainer.new()
	p.add_child(box)
	return box

func stars(parent: Node, count: int, size_px:=30) -> void:
	var row:=HBoxContainer.new()
	row.alignment=BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	for i in 3:
		var icon:=TextureRect.new()
		icon.texture=load("res://assets/ui/star.png" if i<count else "res://assets/ui/star_empty.png")
		icon.custom_minimum_size=Vector2(size_px,size_px)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

func show_home() -> void:
	clear_ui("home")
	pause_reason=""
	var display=Model.new()
	display.begin("campaign",0,128,{})
	harbor.build(display.state,true)
	audio.play_music("menu")
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:
		margin.add_theme_constant_override("margin_"+side,24)
	margin.add_theme_constant_override("margin_top",24)
	margin.add_theme_constant_override("margin_bottom",8)
	overlay.add_child(margin)
	var stack:=VBoxContainer.new()
	margin.add_child(stack)
	var heading:=panel(stack,Color("113440ee"))
	var top:=HBoxContainer.new()
	heading.add_child(top)
	var name_box:=VBoxContainer.new()
	name_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(name_box)
	name_box.add_child(label("TIDELINE",24,Color("8ddfce")))
	name_box.add_child(label("TOW",58,CREAM))
	var stats:=VBoxContainer.new()
	stats.custom_minimum_size.x=136
	top.add_child(stats)
	var rank_label:=label("SKIPPER %d"%profile.level(),18,GOLD)
	rank_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	stats.add_child(rank_label)
	var coin_label:=label("%d coins"%int(profile.data.coins),20)
	coin_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	stats.add_child(coin_label)
	var xp:=ProgressBar.new()
	xp.custom_minimum_size.y=8
	xp.show_percentage=false
	xp.max_value=100*profile.level()*profile.level()
	xp.value=profile.data.xp
	heading.add_child(xp)
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=160
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	var dock:=panel(stack,Color("113440f7"))
	dock.add_child(label("A little tug. A growing convoy.",23,GOLD))
	var next:=next_contract()
	var has_active:bool=not profile.data.active.is_empty()
	dock.add_child(button("Resume rescue" if has_active else "Launch · Contract %02d"%(next+1),resume_run if has_active else func():start_run("campaign",next),true))
	var modes:=HBoxContainer.new()
	dock.add_child(modes)
	modes.add_child(button("Contracts",show_campaign))
	modes.add_child(button("Harbor Watch",func():start_run("endless",0)))
	var daily_row:=HBoxContainer.new()
	dock.add_child(daily_row)
	daily_row.add_child(button("Daily voyage",func():start_run("daily",0)))
	daily_row.add_child(button("Daily gifts",show_daily))
	var tools:=HBoxContainer.new()
	dock.add_child(tools)
	for item in [["Shipyard",show_shipyard],["Logbook",show_journal],["Options",show_options]]:
		var b:=button(item[0],item[1])
		b.add_theme_font_size_override("font_size",18)
		tools.add_child(b)
	var banner:=Control.new()
	banner.name="BannerReserve"
	banner.custom_minimum_size.y=banner_reserve()
	stack.add_child(banner)
	if not profile_error.is_empty():
		toast(profile_error)

func next_contract() -> int:
	for i in 30:
		if int(profile.data.stars[i])==0:
			return i
	return 29

func show_campaign() -> void:
	var body:=page("Coastal contracts","Thirty rescues. Three unforgettable coasts.")
	screen="campaign"
	var unlocked:=next_contract()
	for region in 3:
		var chapter:=panel(body,Color("194652"))
		chapter.add_child(label("%02d  %s"%[region+1,DISTRICTS[region]],25,GOLD))
		var grid:=GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",10)
		grid.add_theme_constant_override("v_separation",10)
		chapter.add_child(grid)
		for j in 10:
			var index:=region*10+j
			var data:Dictionary=Content.campaign(index)
			var card:=panel(grid,Color("205765"))
			card.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var b:=button("%02d · %s"%[index+1,str(data.get("name","Rescue"))],func():start_run("campaign",index))
			b.add_theme_font_size_override("font_size",17)
			b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.y=66
			b.disabled=index>unlocked
			card.add_child(b)
			stars(card,int(profile.data.stars[index]),25)
			card.add_child(label("%d boats · %ds"%[int(data.get("target",3)),int(data.get("time",120))],15,MUTED))

func start_run(mode: String,index: int,replace_active:=false) -> void:
	if ad_locked:
		return
	if not replace_active and not profile.data.active.is_empty():
		var box:=open_modal("A rescue is still at sea","Your current tow is saved. Starting another voyage replaces it.")
		box.add_child(button("Resume saved rescue",resume_run,true))
		box.add_child(button("Start new voyage",func():start_run(mode,index,true)))
		return
	profile.advance_day(today())
	var seed_value:=int(Time.get_unix_time_from_system())
	if mode=="daily":
		seed_value=today().hash()
	model.begin(mode,index,seed_value,profile.data.upgrades)
	profile.data.active=model.snapshot()
	save_profile()
	last_reward={}
	victory_pending=false
	pause_reason=""
	show_play()
	if index==0 and mode=="campaign":
		toast("Hold the helm to steer. Reach SOS boats, then return to the glowing harbor.",6)

func resume_run() -> void:
	if model.restore(profile.data.active):
		show_play()
		if model.state.status=="running":
			pause_game("Your rescue is ready", "Resume when you're ready to take the helm.")
		elif model.state.status=="failed":
			show_failure()
		else:
			finish_run()
	else:
		profile.data.active={}
		save_profile()
		toast("That rescue could not be restored. Your harbor progress is safe.")

func show_play() -> void:
	clear_ui("play")
	# Put the sea in a dedicated safe play area, leaving HUD and helm outside it.
	viewport_holder.anchor_top=0
	viewport_holder.anchor_bottom=1
	viewport_holder.offset_top=166
	viewport_holder.offset_bottom=-156
	harbor.build(model.state,false)
	audio.play_music(["sunwake","copperdock","lantern"][int(model.state.district)%3])
	var top:=MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left=14
	top.offset_right=-14
	top.offset_top=12
	overlay.add_child(top)
	var box:=panel(top)
	box.add_child(label(("CONTRACT %02d  ·  "%[int(model.state.level)+1] if model.state.mode=="campaign" else "DAILY  ·  " if model.state.mode=="daily" else "HARBOR WATCH  ·  ")+str(model.state.name),17,MUTED))
	var row:=HBoxContainer.new()
	box.add_child(row)
	hud_status=label("",24)
	hud_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(hud_status)
	var pause_button:=button("Ⅱ",func():pause_game("Safe at the helm","The sea will wait for you."),false,58)
	pause_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	row.add_child(pause_button)
	var info:=HBoxContainer.new()
	box.add_child(info)
	hud_hearts=label("",24,CORAL)
	hud_hearts.autowrap_mode=TextServer.AUTOWRAP_OFF
	hud_hearts.custom_minimum_size.x=110
	hud_hearts.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.add_child(hud_hearts)
	hud_score=label("",19,GOLD)
	hud_score.autowrap_mode=TextServer.AUTOWRAP_OFF
	hud_score.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.add_child(hud_score)
	hud_time=label("",19)
	hud_time.autowrap_mode=TextServer.AUTOWRAP_OFF
	hud_time.custom_minimum_size.x=62
	hud_time.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(hud_time)
	var bottom:=MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top=-155
	bottom.offset_left=14
	bottom.offset_right=-14
	bottom.offset_bottom=-8
	overlay.add_child(bottom)
	var bottom_box:=VBoxContainer.new()
	bottom.add_child(bottom_box)
	hint=label("Hold the helm to steer · release to stop",17,CREAM)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bottom_box.add_child(hint)
	helm=Helm.new()
	helm.steering.connect(func(value):steering=value)
	bottom_box.add_child(helm)
	update_hud()

func update_hud() -> void:
	if screen!="play" or not is_instance_valid(hud_status):
		return
	var state:Dictionary=model.state
	hud_status.text="%d / %d home"%[int(state.delivered),int(state.get("target",3))] if state.mode!="endless" else "%d boats home"%int(state.delivered)
	hud_hearts.text="♥".repeat(maxi(0,int(state.hull)))+"♡".repeat(maxi(0,int(state.get("max_hull",3))-int(state.hull)))
	hud_score.text="%d pts"%int(state.score)
	hud_time.text="%d:%02d"%[int(state.get("remaining",0))/60,int(state.get("remaining",0))%60]
	var count:int=state.tow.size()
	hint.text="%d in tow · steer into SAFE HARBOR"%count if count>0 else "Find SOS boats · deliveries add time" if state.mode=="endless" else "Hold the helm to steer · find SOS boats"

func _water_input(event: InputEvent) -> void:
	if screen!="play" or not pause_reason.is_empty() or ad_locked:
		return
	var point:=Vector2.ZERO
	var changed:=false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		water_held=event.pressed
		point=event.position
		changed=event.pressed
	elif event is InputEventMouseMotion and water_held:
		point=event.position
		changed=true
	elif event is InputEventScreenTouch:
		water_held=event.pressed
		point=event.position
		changed=event.pressed
	elif event is InputEventScreenDrag and water_held:
		point=event.position
		changed=true
	if changed:
		var ray:Vector3=harbor.camera.project_ray_origin(point)
		var normal:Vector3=harbor.camera.project_ray_normal(point)
		var distance:float=-ray.y/normal.y
		var world:Vector3=ray+normal*distance
		water_target=Vector2(world.x,world.z)

func _process(dt: float) -> void:
	if not ready_complete:
		return
	if toast_clock>0:
		toast_clock-=dt
		toast_label.visible=toast_clock>0
	if not probe.is_empty():
		probe_tick(dt)
	if screen=="play" and pause_reason.is_empty() and not ad_locked and model.state.get("status","")=="running":
		var direction:=steering
		if water_held:
			var target_delta:=water_target-Vector2(float(model.state.position[0]),float(model.state.position[1]))
			direction=target_delta.normalized() if target_delta.length()>0.25 else Vector2.ZERO
		if not qa_mode and probe.is_empty():
			var keys:=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
			if keys.length()>0:
				direction=keys.normalized()
		var events:Array=model.step(minf(dt,0.1),direction)
		handle_events(events)
		harbor.sync(model.state)
		update_hud()
		save_clock+=dt
		if save_clock>=3:
			save_clock=0
			persist_run()
		if model.state.status=="failed":
			persist_run()
			show_failure()
		elif model.state.status=="won" and not victory_pending:
			victory_pending=true
			persist_run()
			await get_tree().create_timer(0.85).timeout
			if screen=="play" and model.state.status=="won":
				finish_run()

func handle_events(events: Array) -> void:
	for event in events:
		var key:=str(event)
		if key.contains("pickup") or key.contains("hook"):
			audio.play_sfx("hook")
			persist_run()
		elif key.contains("deliver"):
			audio.play_sfx("delivery")
			harbor.celebrate()
			persist_run()
		elif key in ["bump","hit"] or key.contains("damage") or key.contains("collision"):
			audio.play_sfx("bump")
			toast("Hull bumped! A dropped boat can be picked up again.")
		elif key=="wave":
			audio.play_music(["sunwake","copperdock","lantern"][int(model.state.district)%3])
			toast("Fresh SOS calls · Watch %d"%[int(model.state.endless_wave)+1])
		if not probe.is_empty():
			probe_events.append({"event":key,"elapsed":model.state.get("elapsed",0),"score":model.state.get("score",0)})

func persist_run() -> void:
	if model.state.is_empty():
		return
	profile.data.active=model.snapshot()
	save_profile()

func save_profile() -> bool:
	if qa_mode and profile_path=="user://profile_v1.json":
		return true
	var ok:bool=profile.save_to(profile_path)
	if not ok:
		profile_error="Progress could not be saved. Please keep the app open and try again."
		toast(profile_error,5)
	return ok

func show_failure() -> void:
	steering=Vector2.ZERO
	water_held=false
	pause_reason="failure"
	audio.play_sfx("fail")
	var box:=open_modal("The tide won this time", "%d boats home · %d points"%[int(model.state.delivered),int(model.state.score)])
	if not bool(model.state.get("continued",false)):
		box.add_child(label("A rescue crew can repair your tug once and give you another chance.",20,MUTED))
		box.add_child(button("Watch ad · call rescue crew",request_continue,true))
	box.add_child(button("Return to harbor",finish_run))

func request_continue() -> void:
	var services:=get_node_or_null("/root/Services")
	if reward_pending or ad_locked:
		return
	if not services or qa_mode:
		toast("Rescue ads are unavailable here. You can retry for free.")
		return
	reward_pending=true
	steering=Vector2.ZERO
	water_held=false
	if is_instance_valid(helm):
		helm.release()
	var accepted:bool=services.request_rewarded_continue(str(model.state.run_id))
	if not accepted:
		reward_pending=false
		toast("No rescue ad is ready. Try again shortly or return to harbor.")

func _reward_earned(run_id: String) -> void:
	if str(model.state.get("run_id",""))!=run_id or not reward_pending:
		return
	if model.revive():
		persist_run()
		pause_reason="ad_return"
		harbor.sync(model.state)
		update_hud()
		if not probe.is_empty():
			probe_events.append({"event":"real_reward_earned","run_id":run_id})

func _reward_finished(run_id: String, earned: bool) -> void:
	if str(model.state.get("run_id",""))!=run_id:
		return
	reward_pending=false
	if earned and model.state.status=="running" and not ad_locked:
		pause_game("Rescue crew ready", "Your tug is repaired. Resume when you're ready.")
	elif not earned:
		toast("No reward earned. Your rescue result is still here.")

func _fullscreen_changed(active: bool) -> void:
	ad_locked=active
	steering=Vector2.ZERO
	water_held=false
	if is_instance_valid(helm):
		helm.release()
	if active:
		if screen=="play":
			persist_run()
		if not probe.is_empty():
			probe_events.append({"event":"native_fullscreen_open"})
	elif screen=="play" and model.state.get("status","")=="running":
		pause_game("Ready to set off?", "Take the helm when you're ready.")
	if not active and not probe.is_empty():
		probe_events.append({"event":"native_fullscreen_closed"})

func finish_run() -> void:
	if ad_locked:
		return
	if model.state.get("status","")=="running":
		model.end_run()
	var before:Dictionary=profile.data.duplicate(true)
	profile.advance_day(today())
	var result:Dictionary=profile.settle(model.snapshot())
	if not result.get("ok",false):
		if not last_reward.is_empty():
			show_result()
		return
	last_reward=result
	profile.data.active={}
	if not save_profile():
		profile.data=before
		last_reward={}
		pause_reason="save_error"
		var box:=open_modal("Save needs attention","Your result is ready. Try saving again before leaving.")
		box.add_child(button("Retry save",finish_run,true))
		return
	pause_reason=""
	audio.play_sfx("win" if model.state.status=="won" else "delivery")
	show_result()
	var services:=get_node_or_null("/root/Services")
	if services and not qa_mode:
		services.submit_progress(profile.achievements(),profile.boards())
		services.round_completed(int(profile.data.stats.rounds),str(model.state.run_id))
	if not probe.is_empty():
		probe_events.append({"event":"settled","reward":result,"profile":profile.data.duplicate(true)})

func show_result() -> void:
	var won:bool=model.state.get("status","")=="won"
	var body:=page("Welcome home" if won else "Watch complete",DISTRICTS[int(model.state.district)%3],false)
	screen="result"
	var card:=panel(body,Color("1e5360"))
	card.add_child(label("CONTRACT COMPLETE" if won else "EVERY RESCUE COUNTS",19,Color("8ae1cd")))
	var hero:=label("%d"%int(model.state.score),64,GOLD)
	hero.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(hero)
	var point_label:=label("POINTS",18,MUTED)
	point_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(point_label)
	if model.state.mode!="endless":
		stars(card,int(last_reward.get("stars",1 if won else 0)),55)
	card.add_child(label("%d boats brought home"%int(model.state.delivered),25))
	card.add_child(label("+%d coins       +%d XP"%[int(last_reward.get("coins",0)),int(last_reward.get("xp",0))],23,GOLD))
	card.add_child(label("Skipper level %d"%profile.level(),19,MUTED))
	if won and model.state.mode=="campaign" and int(model.state.level)<29:
		body.add_child(button("Next contract",func():start_run("campaign",int(model.state.level)+1),true))
	else:
		body.add_child(button("Sail again",func():start_run(str(model.state.mode),int(model.state.level)),true))
	body.add_child(button("Harbor home",show_home))
	body.add_child(button("Coastal contracts",show_campaign))
	var banner:=Control.new()
	banner.name="BannerReserve"
	banner.custom_minimum_size.y=banner_reserve()
	body.add_child(banner)
	var services:=get_node_or_null("/root/Services")
	if services and not qa_mode:
		services.set_banner_visible(true)

func pause_game(title: String, message: String) -> void:
	if screen!="play":
		return
	pause_reason="paused"
	steering=Vector2.ZERO
	water_held=false
	if is_instance_valid(helm):
		helm.release()
	persist_run()
	var box:=open_modal(title,message)
	box.add_child(button("Resume rescue",resume_play,true))
	box.add_child(button("Save & harbor",show_home))
	box.add_child(button("Finish this watch",finish_run))

func resume_play() -> void:
	if ad_locked or model.state.get("status","")!="running":
		return
	pause_reason=""
	steering=Vector2.ZERO
	water_held=false
	if is_instance_valid(modal):
		modal.queue_free()
	modal=null

func open_modal(title: String,message: String) -> VBoxContainer:
	if is_instance_valid(modal):
		overlay.remove_child(modal)
		modal.queue_free()
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(modal)
	var shade:=ColorRect.new()
	shade.color=Color(0.02,0.08,0.11,0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var p:=PanelContainer.new()
	p.custom_minimum_size=Vector2(minf(size.x-40,480),0)
	center.add_child(p)
	var box:=VBoxContainer.new()
	p.add_child(box)
	box.add_child(label(title,30,GOLD))
	box.add_child(label(message,21,MUTED))
	return box

func show_shipyard() -> void:
	var body:=page("Shipyard","Small improvements. A little more room to grow.")
	screen="shipyard"
	body.add_child(label("%d coins · Skipper %d"%[int(profile.data.coins),profile.level()],23,GOLD))
	for spec in [["rope","Towline","Carry one more boat per rank.",3,180],["engine","Engine","A little more speed for the long way home.",3,150],["hull","Hull plating","One extra heart for rougher waters.",1,500]]:
		var key:String=spec[0]
		var rank:=int(profile.data.upgrades[key])
		var card:=panel(body,Color("1b4d5b"))
		card.add_child(label("%s  %d / %d"%[spec[1],rank,int(spec[3])],27))
		card.add_child(label(spec[2],20,MUTED))
		var cost:=int(spec[4])*(rank+1)*(rank+1) if key!="hull" else 500
		var buy:=button("Fully fitted" if rank>=int(spec[3]) else "Fit upgrade · %d coins"%cost,func():purchase(key),true)
		buy.disabled=rank>=int(spec[3]) or int(profile.data.coins)<cost
		card.add_child(buy)

func purchase(key: String) -> void:
	var before:Dictionary=profile.data.duplicate(true)
	if profile.purchase(key):
		if not save_profile():
			profile.data=before
			return
		audio.play_sfx("upgrade")
		show_shipyard()
		toast("Fitted for your next voyage.")

func show_daily() -> void:
	profile.advance_day(today())
	var body:=page("Daily dock","A fresh reason to set sail · "+today())
	screen="daily"
	var gift:=panel(body,Color("1b4d5b"))
	gift.add_child(label("Seven-day harbor welcome",26,GOLD))
	gift.add_child(label("Return on consecutive days for a growing coin gift.",20,MUTED))
	var claimed:bool=str(profile.data.login.get("last_day",""))==today()
	gift.add_child(button("Gift collected today" if claimed else "Collect today's gift",claim_login,true))
	var row:=HBoxContainer.new()
	gift.add_child(row)
	for i in 7:
		var day:=label(str(i+1),18,GOLD if i<int(profile.data.login.get("streak",0)) else MUTED)
		day.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		day.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(day)
	for spec in Content.quests():
		var key:String=spec.key
		var card:=panel(body,Color("1b4d5b"))
		card.add_child(label(spec.description,23))
		card.add_child(label("%d / %d"%[mini(int(profile.data.daily.get(key,0)),int(spec.target)),int(spec.target)],19,MUTED))
		var collected:bool=key in profile.data.daily.get("claimed",[])
		var b:=button("Collected" if collected else "Collect quest reward",func():claim_quest(key))
		b.disabled=collected or int(profile.data.daily.get(key,0))<int(spec.target)
		card.add_child(b)
	body.add_child(button("Sail today's voyage",func():start_run("daily",0),true))

func claim_login() -> void:
	var before:Dictionary=profile.data.duplicate(true)
	var reward:Dictionary=profile.claim_login(today())
	if not save_profile():
		profile.data=before
		return
	show_daily()
	sync_progress()
	toast("Harbor welcome: +%d coins"%int(reward.get("coins",0)) if reward.get("ok",false) else "Today's gift is already collected.")

func claim_quest(key: String) -> void:
	var before:Dictionary=profile.data.duplicate(true)
	var reward:Dictionary=profile.quest_claim(key,today())
	if not save_profile():
		profile.data=before
		return
	show_daily()
	sync_progress()
	toast("Quest complete: +%d coins"%int(reward.get("coins",0)) if reward.get("ok",false) else "Keep sailing to finish this quest.")

func show_journal() -> void:
	var body:=page("Skipper's log","Your little harbor, one rescue at a time.")
	screen="journal"
	var stats:=panel(body,Color("1b4d5b"))
	stats.add_child(label("%d boats brought home"%int(profile.data.stats.rescues),28,GOLD))
	stats.add_child(label("Skipper %d · %d XP · %d contracts"%[profile.level(),int(profile.data.xp),completed_contracts()],20))
	stats.add_child(label("Best Harbor Watch: %d"%int(profile.data.best_endless),20,MUTED))
	var services_row:=HBoxContainer.new()
	body.add_child(services_row)
	services_row.add_child(button("Play Games",func():service_action("sign_in")))
	services_row.add_child(button("Leaderboards",func():service_action("show_leaderboards")))
	body.add_child(button("Play Games achievements",func():service_action("show_achievements")))
	body.add_child(label("BADGES",18,GOLD))
	var unlocked:Array=profile.achievements()
	for badge in Content.achievements():
		var card:=panel(body,Color("1b4d5b"))
		var row:=HBoxContainer.new()
		card.add_child(row)
		var key:String=badge.get("key",badge.get("id",""))
		var path:="res://assets/brand/achievements/%s.png"%key
		if ResourceLoader.exists(path):
			var image:=TextureRect.new()
			image.texture=load(path)
			image.custom_minimum_size=Vector2(62,62)
			image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.modulate=Color.WHITE if key in unlocked else Color(0.5,0.6,0.65,1)
			row.add_child(image)
		var text:=VBoxContainer.new()
		text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(label(str(badge.get("name",key))+("  ✓" if key in unlocked else ""),22,GOLD if key in unlocked else CREAM))
		text.add_child(label(str(badge.get("description","")),17,MUTED))

func completed_contracts() -> int:
	var total:=0
	for value in profile.data.stars:
		if int(value)>0:
			total+=1
	return total

func service_action(action: String) -> void:
	var services:=get_node_or_null("/root/Services")
	if services and services.has_method(action):
		services.call(action)
	else:
		toast("Your local harbor records are always available offline.")

func show_options() -> void:
	var body:=page("Options","Make yourself at home.")
	screen="options"
	for key in ["music","effects","reduced_motion"]:
		var b:=button(("Music" if key=="music" else "Sound effects" if key=="effects" else "Reduced motion")+": "+("On" if bool(profile.data.settings.get(key,true)) else "Off"),func():toggle_option(key))
		body.add_child(b)
	body.add_child(button("Ad privacy choices",func():service_action("show_privacy_options")))
	var card:=panel(body,Color("1b4d5b"))
	card.add_child(label("How to sail",27,GOLD))
	card.add_child(label("Hold the bottom helm in a direction, or hold a spot on the water. Release to stop. Sail close to SOS boats to hook them, then bring your tow into the glowing harbor. Rocks and ferries hurt your hull and can drop the last boat.",20))
	card.add_child(label("Desktop: WASD or arrows. Escape pauses. Your rescue saves automatically and continues safely after a break.",18,MUTED))
	card.add_child(label("Made with Kenney watercraft and coastal assets. Original code Apache 2.0. Optional ads support the harbor; ordinary retries are always free.",16,MUTED))
	body.add_child(button("Local achievements",show_journal))

func toggle_option(key: String) -> void:
	profile.data.settings[key]=not bool(profile.data.settings.get(key,true))
	audio.configure(profile.data.settings)
	harbor.reduced_motion=bool(profile.data.settings.get("reduced_motion",false))
	save_profile()
	show_options()

func toast(message: String,seconds:=3.5) -> void:
	if is_instance_valid(toast_label):
		toast_label.text=message
		toast_label.visible=true
		toast_clock=seconds

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		go_back()
		get_viewport().set_input_as_handled()

func go_back() -> void:
	if ad_locked:
		return
	if screen=="play":
		if model.state.get("status","")=="failed":
			finish_run()
		elif pause_reason.is_empty():
			pause_game("Taking a breather?","Your rescue is saved.")
		else:
			show_home()
	elif screen=="home":
		var box:=open_modal("Leave the harbor?","Your progress is saved on this device.")
		box.add_child(button("Keep playing",show_home,true))
		box.add_child(button("Close game",func():save_profile();get_tree().quit()))
	else:
		show_home()

func _notification(what: int) -> void:
	if not ready_complete:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if screen=="play" and model.state.get("status","")=="running":
			pause_game("Welcome back","Your rescue waited right here.")
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		if screen=="play":
			persist_run()
		save_profile()
		get_tree().quit()

func read_probe_config() -> void:
	if not OS.has_feature("acceptance") or not OS.has_feature("debug"):
		return
	var path:="user://qa_probe.json"
	if not FileAccess.file_exists(path):
		return
	var file:=FileAccess.open(path,FileAccess.READ)
	var parsed=JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("enabled",false):
		return
	probe=parsed
	var probe_namespace:=str(probe.get("profile","native-probe")).validate_filename()
	DirAccess.make_dir_recursive_absolute("user://qa")
	profile_path="user://qa/%s.json"%probe_namespace
	probe_path="user://qa/%s-evidence.json"%probe_namespace
	probe_phase="starting"

func start_probe() -> void:
	if str(probe.get("scenario","contract"))=="cold":
		resume_run()
		probe_phase="cold"
		write_probe()
		return
	if str(probe.get("scenario","contract"))=="interstitial":
		profile.data.stats.rounds=2
		probe_events.append({"event":"fixture_prior_round_count","value":2})
	start_run("campaign",0,true)
	probe_phase="sailing"
	write_probe()

func autopilot_direction() -> Vector2:
	var position:=Vector2(float(model.state.position[0]),float(model.state.position[1]))
	var target:=Vector2(0,10)
	if model.state.tow.size()<int(model.state.get("capacity",3)):
		var nearest:=INF
		for boat in model.state.boats:
			if str(boat.status)=="afloat":
				var p:=Vector2(float(boat.pos[0]),float(boat.pos[1]))
				if position.distance_to(p)<nearest:
					nearest=position.distance_to(p)
					target=p
	return (target-position).normalized() if position.distance_to(target)>0.3 else Vector2.ZERO

func probe_tick(dt: float) -> void:
	probe_time+=dt
	if screen=="play" and pause_reason.is_empty() and not ad_locked:
		steering=autopilot_direction()
		if str(probe.get("scenario","contract"))=="rewarded" and not bool(model.state.get("continued",false)):
			steering=Vector2.ZERO
		if model.state.get("tow",[]).size()>0 and not probe_captured.has("tow"):
			probe_captured["tow"]=true
			capture_probe("tow")
	if screen=="play" and model.state.get("status","")=="failed" and str(probe.get("scenario",""))=="rewarded" and not reward_pending and not probe_captured.has("reward_request"):
		probe_captured["reward_request"]=true
		request_continue()
	if screen=="result" and not probe_captured.has("result"):
		probe_captured["result"]=true
		probe_phase="result"
		capture_probe("result")
		write_probe()
	var bucket:=int(probe_time/3.0)
	if bucket!=probe_last_write:
		probe_last_write=bucket
		write_probe()

func capture_probe(key: String) -> void:
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var path:="user://qa/%s-%s.png"%[str(probe.get("profile","native-probe")).validate_filename(),key]
	image.save_png(path)
	probe_events.append({"event":"capture","path":path})
	write_probe()

func write_probe() -> void:
	if probe_path.is_empty():
		return
	var file:=FileAccess.open(probe_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"acceptance_only":true,"scenario":probe.get("scenario",""),"phase":probe_phase,"screen":screen,"pause":pause_reason,"fullscreen":ad_locked,"state":model.snapshot(),"profile":profile.data,"events":probe_events},"\t"))
