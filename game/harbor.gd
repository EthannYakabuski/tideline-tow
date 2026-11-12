extends Node3D

const SEA := [Color("329baf"), Color("397e89"), Color("243b6a")]
const LAND := [Color("b9a67f"), Color("a78974"), Color("69718b")]
var camera: Camera3D
var static_root: Node3D
var moving_root: Node3D
var player: Node3D
var ropes: Array[MeshInstance3D] = []
var boat_nodes := {}
var ferry_nodes: Array[Node3D] = []
var wake_nodes: Array[MeshInstance3D] = []
var current_markers: Array[Node3D] = []
var harbor_ring: MeshInstance3D
var water: MeshInstance3D
var elapsed := 0.0
var district := 0
var presentation := false
var burst_time := 0.0
var model_cache := {}
var environment: WorldEnvironment
var sunlight: DirectionalLight3D
var effects: Array = []
var last_player_position := Vector3.ZERO
var docking := {}
var reduced_motion := false
var rendered_wave := 0

func _ready() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fd1dc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5e9ed")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_color = Color("ffe4bd")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	add_child(sun)
	sunlight=sun
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(0,34,20)
	camera.look_at_from_position(camera.position, Vector3(0,0,0))
	camera.size = 24
	camera.near = 0.1
	camera.far = 100
	add_child(camera)
	camera.current = true
	static_root = Node3D.new()
	add_child(static_root)
	moving_root = Node3D.new()
	add_child(moving_root)

func material(color: Color, emission := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	if emission:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	parent.add_child(node)
	return node

func disc(parent: Node3D, at: Vector3, radius: float, color: Color, height := 0.05) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	node.mesh = mesh
	node.material_override = material(color, height < 0.1)
	node.position = at
	parent.add_child(node)
	return node

func ring(parent: Node3D, at: Vector3, radius: float, color: Color, thickness := 0.035) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 32
	mesh.ring_segments = 6
	node.mesh = mesh
	node.material_override = material(color, true)
	node.position = at
	parent.add_child(node)
	return node

func prop(pack: String, key: String, parent: Node3D, at: Vector3, scale_value := 1.0, yaw := 0.0) -> Node3D:
	var path := "res://assets/models/%s/%s.glb" % [pack,key]
	if not model_cache.has(path):
		model_cache[path] = load(path)
	var node: Node3D = model_cache[path].instantiate()
	var vessel:bool=pack=="watercraft" and ((key.begins_with("boat-") and not key.begins_with("boat-house")) or key=="ship-ocean-liner-small")
	var obstacle:bool=pack=="pirate" and key in ["rocks-a","rocks-b","rocks-c"]
	if vessel or obstacle:
		var holder:=Node3D.new()
		parent.add_child(holder)
		holder.add_child(node)
		var bounds:=bounds_of(node,Transform3D.IDENTITY)
		var length:=scale_value if obstacle else 1.65 if key.begins_with("boat-tug") else 1.9 if key.begins_with("ship-") else 1.45
		var factor:=length/maxf(bounds.size.x,bounds.size.z)
		node.scale=Vector3.ONE*factor
		node.position=Vector3(-bounds.get_center().x*factor,-bounds.position.y*factor,-bounds.get_center().z*factor)
		holder.position=at
		holder.rotation.y=yaw
		return holder
	else:
		parent.add_child(node)
		node.position = at
		node.scale = Vector3.ONE * scale_value
		node.rotation.y = yaw
		return node

func bounds_of(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform:=parent_transform*node.transform
	var bounds:=AABB()
	var found:=false
	if node is MeshInstance3D and node.mesh:
		bounds=transform*node.get_aabb()
		found=true
	for child in node.get_children():
		if child is Node3D:
			var child_bounds:=bounds_of(child,transform)
			if child_bounds.size.length()>0:
				bounds=bounds.merge(child_bounds) if found else child_bounds
				found=true
	return bounds

func label3(parent: Node3D, text: String, at: Vector3, color := Color.WHITE, scale_value := 0.008) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = 54
	node.outline_size = 10
	node.modulate = color
	node.outline_modulate = Color("193b4b")
	node.pixel_size = scale_value
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.position = at
	parent.add_child(node)
	return node

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func build(state: Dictionary, home := false) -> void:
	clear_children(static_root)
	clear_children(moving_root)
	boat_nodes.clear()
	ferry_nodes.clear()
	ropes.clear()
	wake_nodes.clear()
	current_markers.clear()
	effects.clear()
	docking.clear()
	district = int(state.get("district", 0)) % 3
	rendered_wave=int(state.get("endless_wave",0))
	presentation = home
	water = box(static_root, Vector3(0,-0.32,0), Vector3(100,0.5,100), SEA[district])
	var sea_shader:=Shader.new()
	sea_shader.code="shader_type spatial; render_mode unshaded; uniform vec4 sea_color : source_color; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float crest=sin(wp.x*2.1+wp.z*1.4+TIME*0.7)*sin(wp.z*3.2-TIME*0.45); float glint=smoothstep(0.91,1.0,crest); ALBEDO=sea_color.rgb*(0.93+0.05*crest)+vec3(0.12,0.20,0.20)*glint;}"
	var sea_material:=ShaderMaterial.new()
	sea_material.shader=sea_shader
	sea_material.set_shader_parameter("sea_color",SEA[district])
	water.material_override=sea_material
	environment.environment.background_color = SEA[district]
	sunlight.light_color=Color("bdcbff") if district==2 else Color("ffe4bd")
	sunlight.light_energy=0.42 if district==2 else 0.7
	environment.environment.ambient_light_color=Color("9aaed3") if district==2 else Color("d5e9ed")
	# Two fully dressed waterfronts frame the play area without hiding hazards.
	for side in [-1,1]:
		box(static_root, Vector3(side*12.7,-0.28,0), Vector3(5.2,0.55,32), LAND[district])
		box(static_root, Vector3(side*10.25,-0.02,0), Vector3(0.30,0.18,32), Color("eee0b5"))
		for i in 8:
			var z := -13.5 + i*3.7
			if not (side==1 and i in [3,4]):
				prop("pirate", "rocks-sand-a" if i%2==0 else "rocks-sand-b", static_root, Vector3(side*10.7,-0.1,z), 0.9+0.15*(i%3), i*0.9)
			else:
				prop("pirate","structure-platform-dock-small",static_root,Vector3(10.6,0.05,z),0.9,PI/2)
				prop("watercraft","cargo-container-b",static_root,Vector3(12.2,0.2,z),0.75)
			if district == 1:
				prop("industrial", ["building-a","building-c","building-f"][i%3], static_root, Vector3(side*13.2,0,z), 1.4, PI/2 if side<0 else -PI/2)
				prop("watercraft","cargo-container-a" if i%2==0 else "cargo-container-c",static_root,Vector3(side*11.5,0.08,z+1.4),0.7)
			else:
				prop("pirate","palm-detailed-bend" if i%2==0 else "palm-detailed-straight",static_root,Vector3(side*12.0,0,z),1.5,i*1.7)
				if i%3==0:
					prop("watercraft","boat-house-a" if i%2==0 else "boat-house-c",static_root,Vector3(side*14.0,0.04,z+0.5),1.4,PI/2)
			if district == 2 or i%2==0:
				var lantern := Vector3(side*10.5,0.1,z)
				box(static_root,lantern+Vector3(0,0.8,0),Vector3(0.08,1.6,0.08),Color("66584f"))
				disc(static_root,lantern+Vector3(0,1.65,0),0.17,Color("ffd685"),0.3)
	# Harbor landing: an unmistakable U-shaped sheltered berth.
	box(static_root,Vector3(0,-0.12,14.8),Vector3(25,0.45,5.4),LAND[district])
	for side in [-1,1]:
		for j in 3:
			prop("pirate","structure-platform-dock",static_root,Vector3(side*3.2,0.0,9.2+j*1.4),0.9,PI/2)
		prop("watercraft","buoy-flag",static_root,Vector3(side*2.5,0.0,7.7),0.65)
		prop("pirate","barrel",static_root,Vector3(side*4.3,0.1,12.9),0.8)
		prop("pirate","crate",static_root,Vector3(side*5.4,0.1,12.6),0.8,0.4)
	var lighthouse:=prop("pirate","tower-complete-small",static_root,Vector3(-7.0,0.0,12.0),1.12)
	var beacon_top:float=bounds_of(lighthouse,Transform3D.IDENTITY).end.y
	var lantern:=disc(static_root,Vector3(-7,beacon_top+0.35,12),0.42,Color("ffd17e"),0.7)
	lantern.material_override=material(Color("ffd17e"),true)
	var cap:=MeshInstance3D.new()
	var cone:=CylinderMesh.new()
	cone.top_radius=0
	cone.bottom_radius=0.65
	cone.height=0.5
	cone.radial_segments=10
	cap.mesh=cone
	cap.material_override=material(Color("2b5961"))
	cap.position=Vector3(-7,beacon_top+0.95,12)
	static_root.add_child(cap)
	prop("industrial","water-tower",static_root,Vector3(7.2,0.0,13.3),1.3)
	box(static_root,Vector3(0,0.11,13.0),Vector3(6.5,0.24,1.1),Color("aa7959"))
	harbor_ring = ring(static_root,Vector3(0,0.05,10),2.15,Color("a9fff0"),0.08)
	label3(static_root,"SAFE HARBOR",Vector3(0,1.4,12.0),Color("fff0ce"),0.010)
	if not presentation:
		label3(static_root,"DOCK HERE",Vector3(0,0.18,10),Color("d5fff2"),0.009)
	# Authored rock collision silhouettes and warning waterline match the model.
	for rock in state.get("rocks", []):
		var p := vec(rock.pos)
		var radius := float(rock.radius)
		disc(static_root,p+Vector3(0,-0.01,0),radius+0.11,Color("8dc0bf"))
		prop("pirate","rocks-a" if int(p.x*10)%2==0 else "rocks-b",static_root,p+Vector3(0,-0.01,0),radius*2.0)
		ring(static_root,p+Vector3(0,0.04,0),radius+0.28,Color("f5cf9d"),0.025)
	for zone in state.get("currents", []):
		var marker := Node3D.new()
		static_root.add_child(marker)
		marker.position = vec(zone.pos)
		ring(marker,Vector3(0,0.03,0),float(zone.radius),Color("91d5e0"),0.02)
		var force := Vector2(float(zone.force[0]),float(zone.force[1]))
		for k in 3:
			var base := Vector3(0,0.08,(k-1)*0.65)
			var shaft := box(marker,base,Vector3(0.8,0.025,0.06),Color("b5edf0"))
			shaft.material_override=material(Color("b5edf0"),true)
			var wing_a:=box(marker,base+Vector3(0.23,0,-0.13),Vector3(0.38,0.025,0.05),Color("b5edf0"))
			wing_a.rotation.y=PI/4
			var wing_b:=box(marker,base+Vector3(0.23,0,0.13),Vector3(0.38,0.025,0.05),Color("b5edf0"))
			wing_b.rotation.y=-PI/4
		marker.rotation.y = -force.angle()
		current_markers.append(marker)
	for ferry in state.get("ferries", []):
		var node := prop("watercraft","ship-ocean-liner-small",moving_root,vec(ferry.pos),0.8,PI/2)
		ferry_nodes.append(node)
	player = prop("watercraft",["boat-tug-a","boat-tug-b","boat-tug-c"][district],moving_root,vec(state.position),0.92)
	last_player_position=player.position
	var player_halo := ring(player,Vector3(0,0.02,0),0.83,Color("ffe8aa"),0.05)
	player_halo.name="PlayerHalo"
	for i in 8:
		var rope := box(moving_root,Vector3.ZERO,Vector3(0.055,0.055,1.0),Color("ffe1a7"))
		rope.visible = false
		ropes.append(rope)
	for i in 10:
		var wake := ring(moving_root,Vector3.ZERO,0.35,Color("a9dfe2"),0.02)
		wake.visible = false
		wake_nodes.append(wake)
	for boat in state.get("boats",[]):
		create_boat(boat)
	frame_camera()
	sync(state)

func create_boat(boat: Dictionary) -> void:
	var holder := Node3D.new()
	moving_root.add_child(holder)
	var kind := int(boat.get("type",0)) % 4
	prop("watercraft",["boat-fishing-small","boat-sail-a","boat-speed-d","boat-row-large"][kind],holder,Vector3.ZERO,0.78)
	var marker := label3(holder,"SOS",Vector3(0,1.05,0),Color("fff0be"),0.011)
	marker.name = "SOS"
	var halo := ring(holder,Vector3(0,0.03,0),0.72,Color("ffda89"),0.035)
	halo.name = "Halo"
	boat_nodes[int(boat.id)] = holder

func frame_camera() -> void:
	if not camera:
		return
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y,1.0)
	if presentation:
		camera.position = Vector3(15,21,28)
		camera.look_at(Vector3(0,0,4.8))
		camera.size = maxf(22.0,25*aspect)
	else:
		camera.position = Vector3(0,34,20)
		camera.look_at(Vector3(0,0,0))
		camera.size = maxf(23.0,27.0*aspect)

func vec(p: Array) -> Vector3:
	return Vector3(float(p[0]),0.12,float(p[1]))

func sync(state: Dictionary) -> void:
	if not player or state.is_empty():
		return
	if int(state.get("endless_wave",0))!=rendered_wave:
		build(state,presentation)
		return
	var moved:bool=last_player_position.distance_to(vec(state.position))>0.0001
	player.position = vec(state.position)
	last_player_position=player.position
	var heading = state.get("heading",[0,-1])
	if heading is Array:
		player.rotation.y = atan2(float(heading[0]),float(heading[1]))
	else:
		player.rotation.y = float(heading)
	var tow: Array = state.get("tow",[])
	var positions: Array = state.get("tow_positions",[])
	for boat in state.boats:
		var id := int(boat.id)
		if not boat_nodes.has(id):
			create_boat(boat)
		var node: Node3D = boat_nodes[id]
		var status := str(boat.status)
		if status=="delivered" and node.visible and not docking.has(id):
			docking[id]={"start":node.position,"time":0.0}
		node.visible = status != "delivered" or docking.has(id)
		node.get_node("SOS").visible = status == "afloat"
		node.get_node("Halo").visible = status == "afloat"
		if status=="delivered":
			continue
		node.scale=Vector3.ONE
		var index := tow.find(id)
		var p := vec(boat.pos)
		if index >= 0 and index < positions.size():
			p = vec(positions[index])
			var before := vec(state.position) if index == 0 else vec(positions[index-1])
			var direction := before-p
			node.rotation.y = atan2(direction.x,direction.z)
		else:
			node.rotation.y = sin(elapsed*0.3+id)*0.24 + id*0.7
		node.position = p + Vector3(0,0 if reduced_motion else sin(elapsed*2.0+id)*0.035,0)
	for i in ropes.size():
		ropes[i].visible = i < positions.size()
		if i < positions.size():
			var before := vec(state.position) if i == 0 else vec(positions[i-1])
			var after := vec(positions[i])
			var delta := after-before
			ropes[i].position = (before+after)/2.0 + Vector3(0,0.07,0)
			ropes[i].rotation.y = atan2(delta.x,delta.z)
			ropes[i].scale.z = delta.length()
	while ferry_nodes.size()<state.get("ferries",[]).size():
		ferry_nodes.append(prop("watercraft","ship-ocean-liner-small",moving_root,Vector3.ZERO,0.8,PI/2))
	for i in ferry_nodes.size():
		if i < state.get("ferries",[]).size():
			var new_position:=vec(state.ferries[i].pos)
			if absf(new_position.x-ferry_nodes[i].position.x)>0.001:
				ferry_nodes[i].rotation.y=PI/2 if new_position.x>ferry_nodes[i].position.x else -PI/2
			ferry_nodes[i].position = new_position
	# Wake beads travel behind the tug without simulation or collision side effects.
	var h := Vector2(0,-1)
	if heading is Array:
		h = Vector2(float(heading[0]),float(heading[1]))
	for i in wake_nodes.size():
		wake_nodes[i].visible = moved and not reduced_motion
		var shift := fmod(elapsed*2+i*0.24,2.4)
		wake_nodes[i].position = player.position-Vector3(h.x,0,h.y)*(shift+0.5)
		wake_nodes[i].position.y = 0.035
		wake_nodes[i].scale = Vector3.ONE*(0.3+shift*0.28)

func celebrate() -> void:
	burst_time = 1.8
	for i in 14:
		var particle := disc(moving_root,Vector3(0,0.4,10),0.07,Color("ffe69c"),0.07)
		effects.append({"node":particle,"dir":Vector3(cos(i*TAU/14),1.5,sin(i*TAU/14))*2.4,"life":0.0})

func _process(dt: float) -> void:
	elapsed += dt
	if harbor_ring:
		harbor_ring.scale = Vector3.ONE*(1+(0 if reduced_motion else sin(elapsed*2.4)*0.035))
	for id in docking.keys():
		docking[id].time+=dt
		var progress:float=minf(1.0,float(docking[id].time)/0.75)
		var node:Node3D=boat_nodes[id]
		node.position=docking[id].start.lerp(Vector3(0,0.15,10),progress)
		node.scale=Vector3.ONE*(1-progress*0.85)
		if progress>=1:
			node.visible=false
			docking.erase(id)
	for effect in effects:
		effect.life += dt
		effect.node.position += effect.dir*dt
		effect.dir.y -= dt*4
		effect.node.scale = Vector3.ONE*maxf(0,1-effect.life/1.4)
	for i in range(effects.size()-1,-1,-1):
		if effects[i].life>1.4:
			effects[i].node.queue_free()
			effects.remove_at(i)
