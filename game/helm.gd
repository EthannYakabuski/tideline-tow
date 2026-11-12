extends Control

signal steering(value: Vector2)
var held := false
var finger := -1
var vector := Vector2.ZERO
var center := Vector2.ZERO
var motion_reduced := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0,112)
	gui_input.connect(_on_input)

func release() -> void:
	held = false
	finger = -1
	vector = Vector2.ZERO
	steering.emit(vector)
	queue_redraw()

func _on_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var valid := false
	if event is InputEventScreenTouch:
		if event.pressed and not held:
			finger = event.index
			held = true
		elif event.index == finger and not event.pressed:
			release()
			return
		if event.index == finger:
			point = event.position
			valid = true
	elif event is InputEventScreenDrag and event.index == finger:
		point = event.position
		valid = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			held = true
			point = event.position
			valid = true
		else:
			release()
	elif event is InputEventMouseMotion and held and finger == -1:
		point = event.position
		valid = true
	if valid:
		center = size/2
		vector = ((point-center)/50.0).limit_length()
		if vector.length()<0.12:
			vector=Vector2.ZERO
		steering.emit(vector)
		queue_redraw()

func _draw() -> void:
	center = size/2
	draw_style_box(_plate(),Rect2(Vector2(0,4),Vector2(size.x,size.y-8)))
	draw_arc(center,45,0,TAU,48,Color("6c9da4"),2,true)
	draw_circle(center,36,Color("1a505b"))
	for i in 8:
		var direction := Vector2.from_angle(i*TAU/8)
		draw_line(center+direction*37,center+direction*47,Color("e8d9b3"),3,true)
	draw_circle(center+vector*32,17,Color("ffd485") if held else Color("ebd8ad"))
	draw_arc(center+vector*32,13,0,TAU,24,Color("385f68"),1.5,true)

func _plate() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("143e4a")
	style.corner_radius_top_left=24
	style.corner_radius_top_right=24
	style.corner_radius_bottom_left=24
	style.corner_radius_bottom_right=24
	return style
