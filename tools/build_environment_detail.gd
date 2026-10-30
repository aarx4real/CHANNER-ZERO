extends SceneTree
## Offline authoring tool: bakes decorative primitives into material batches.
## Run manually with --headless --script res://tools/build_environment_detail.gd.
## Generated detail scenes contain no scripts, lights or collision changes.
var groups: Dictionary = {}
var scene_root: Node3D
var prefix := "res://scenes/detail/"
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	call_deferred("build")

func begin(scene_name: String) -> void:
	groups.clear()
	scene_root = Node3D.new()
	scene_root.name = scene_name

func add(mesh: Mesh, pos: Vector3, material: String, rotation := Vector3.ZERO) -> void:
	if not groups.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[material] = surface
	groups[material].append_from(mesh, 0, Transform3D(Basis.from_euler(rotation), pos))

func box(pos: Vector3, size: Vector3, material := "wood", rotation := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	add(mesh, pos, material, rotation)

func ball(pos: Vector3, radius: float, material := "wood") -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	add(mesh, pos, material)

func cylinder(pos: Vector3, radius: float, height: float, material := "rust", rotation := Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	add(mesh, pos, material, rotation)

func beam(a: Vector3, b: Vector3, radius := 0.025, material := "rope") -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	mesh.rings = 1
	var basis := Basis(Quaternion(Vector3.UP, (b-a).normalized()))
	if not groups.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[material] = surface
	groups[material].append_from(mesh, 0, Transform3D(basis, (a+b)*0.5))

func ring(pos: Vector3, radius: float, material := "rust") -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.7
	mesh.outer_radius = radius
	mesh.rings = 12
	mesh.ring_segments = 6
	add(mesh, pos, material, Vector3(PI/2,0,0))

func rag(pos: Vector3, width: float, length: float, material := "red") -> void:
	# Uneven narrow strips form a shredded silhouette with real gaps.
	for i in range(7):
		var h := length * rng.randf_range(0.5,1.0)
		box(pos+Vector3((i-3)*width/7.0,-h/2,0), Vector3(width/7.0*0.86,h,0.018),material,Vector3(0,0,rng.randf_range(-0.12,0.12)))

func puppet(pos: Vector3, scale_size := 1.0) -> void:
	ball(pos+Vector3(0,0.6,0)*scale_size,0.14*scale_size)
	box(pos+Vector3(0,0.26,0)*scale_size,Vector3(0.25,0.4,0.16)*scale_size)
	for side in [-1,1]:
		beam(pos+Vector3(side*0.14,0.42,0)*scale_size,pos+Vector3(side*0.3,0.03,0.04)*scale_size,0.045*scale_size,"wood")
		beam(pos+Vector3(side*0.075,0.05,0)*scale_size,pos+Vector3(side*0.12,-0.4,0.05)*scale_size,0.05*scale_size,"wood")
		ball(pos+Vector3(side*0.055,0.62,0.12)*scale_size,0.023*scale_size,"dark")
	beam(pos+Vector3(0,0.78,0)*scale_size,pos+Vector3(0,3,0)*scale_size,0.012,"rope")

func bear(pos: Vector3) -> void:
	ball(pos,0.17,"canvas")
	ball(pos+Vector3(0,0.22,0),0.13,"canvas")
	for side in [-1,1]:
		ball(pos+Vector3(side*0.11,0.32,0),0.06,"canvas")
		ball(pos+Vector3(side*0.17,-0.1,0.04),0.075,"canvas")
		ball(pos+Vector3(side*0.05,0.24,0.115),0.018,"dark")

func finish(file: String) -> void:
	for material_name in groups:
		var mesh: ArrayMesh = groups[material_name].commit()
		mesh.surface_set_material(0,load("res://materials/"+material_name+".tres"))
		var instance := MeshInstance3D.new()
		instance.name = material_name.capitalize()+"Batch"
		instance.mesh = mesh
		# Small dressings do not add shadow draw calls.
		if material_name in ["grass","dirt","puddle","rope"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene_root.add_child(instance)
		instance.owner = scene_root
	if file == "theatre_detail":
		var dust := CPUParticles3D.new()
		dust.name = "StageDust"
		dust.position = Vector3(0,3.4,-9)
		dust.amount = 20
		dust.lifetime = 12.0
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = Vector3(6,1.8,2)
		dust.gravity = Vector3(0,0.004,0)
		dust.initial_velocity_min = 0.015
		dust.initial_velocity_max = 0.035
		dust.fixed_fps = 12
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mote := SphereMesh.new()
		mote.radius = 0.009
		mote.height = 0.018
		mote.radial_segments = 4
		mote.rings = 2
		mote.material = load("res://materials/rope.tres")
		dust.mesh = mote
		scene_root.add_child(dust)
		dust.owner = scene_root
	var packed := PackedScene.new()
	packed.pack(scene_root)
	var error := ResourceSaver.save(packed,prefix+file+".tscn")
	assert(error == OK, "Could not save detail scene: "+file)
	scene_root.free()

func build() -> void:
	rng.seed = 7319
	stall()
	entrance()
	midway()
	interiors()
	passage()
	theatre()
	props()
	print("PHASE 3 DETAIL BAKE COMPLETE")
	quit()

func stall() -> void:
	begin("StallDetail")
	for i in range(16):
		var x := -2.25+i*0.30
		box(Vector3(x,0.87,1.075),Vector3(0.275,1.72,0.06),"red" if i%3 else "wood")
		box(Vector3(x,2.15,-1.18),Vector3(0.27,1.5,0.04),"wood")
	box(Vector3(0,1.84,0.63),Vector3(4.95,0.10,0.94),"ochre")
	for x in [-2.3,2.3]:
		beam(Vector3(x,2,0.7),Vector3(x*0.65,3.18,0.7),0.07,"wood")
		for y in [0.35,1.5,2.6]:box(Vector3(x,y,0.89),Vector3(0.21,0.12,0.04),"rust")
	for x in [-2.1,2.1]:
		box(Vector3(x,2.7,0.95),Vector3(0.07,0.62,0.055),"ochre")
	for y in [2.4,3.0]:box(Vector3(0,y,0.95),Vector3(4.5,0.055,0.045),"ochre")
	for i in range(9):
		rag(Vector3(-2.2+i*0.55,3.24,1.52),0.45,0.30+(i%3)*0.09,"red" if i%2 else "canvas")
	for x in [-1.6,-0.75,0.5,1.4]:bear(Vector3(x,2.17,-0.9))
	box(Vector3(0,2.0,-0.92),Vector3(4.3,0.10,0.55))
	for x in [-1.1,0,1.1]:cylinder(Vector3(x,1.96,0.65),0.06,0.18,"steel")
	finish("stall_detail")

func entrance() -> void:
	begin("EntranceDetail")
	for side in [-1,1]:
		var x: float = side*5.5
		for y in [0.2,1.4,4.9,5.6]:box(Vector3(x,y,0.52),Vector3(1.1,0.13,0.08),"rust")
		for dx in [-0.3,0.3]:
			for y in [1.4,4.9]:ball(Vector3(x+dx,y,0.59),0.045,"steel")
		beam(Vector3(x,5.5,0),Vector3(x*0.67,6,0),0.07,"rust")
		for i in range(9):box(Vector3(side*8-1.05+i*0.26,0.7,2.34),Vector3(0.235,1.15,0.06),"red" if i%3 else "wood")
		for dx in [-1.15,1.15]:box(Vector3(side*8+dx,2,1.45),Vector3(0.1,1.5,0.12))
		box(Vector3(side*8,1.35,2.35),Vector3(2.65,0.12,0.25),"ochre")
		rag(Vector3(side*8,2.78,2.45),2.4,0.45,"canvas")
		box(Vector3(side*3.36,0.6,1.48),Vector3(0.37,0.63,0.03),"ochre")
		ring(Vector3(side*3.36,0.66,1.51),0.11,"dark")
	for i in range(9):rag(Vector3(-4+i,4.6,0.13),0.72,0.6+(i%3)*0.14,"canvas" if i%2 else "red")
	for x in [-6,6]:
		ring(Vector3(x,6.6,0),0.38)
	box(Vector3(0,6.55,0),Vector3(12.4,0.10,0.7),"ochre")
	for y in [1.8,2.1,2.4]:beam(Vector3(-8.14,y,-3.85),Vector3(-7.86,y+0.15,-3.85),0.045)
	rag(Vector3(-8,2.4,-3.86),0.4,0.9,"canvas")
	finish("entrance_detail")

func midway() -> void:
	begin("MidwayDetail")
	# Scatter is seeded and restricted to shoulder strips; no central obstacles.
	for i in range(36):
		var x := rng.randf_range(5.3,7.3)*(-1 if i%2 else 1)
		var z := rng.randf_range(-28,14)
		cylinder(Vector3(x,0.025,z),rng.randf_range(0.25,0.65),0.025,"dirt")
		for j in range(6):
			var a := Vector3(x+rng.randf_range(-0.3,0.3),0.04,z+rng.randf_range(-0.25,0.25))
			beam(a,a+Vector3(rng.randf_range(-0.13,0.13),rng.randf_range(0.12,0.35),0.06),0.009,"grass")
		if i%3==0:box(Vector3(x,0.06,z),Vector3(0.12,0.08,0.75),"wood",Vector3(0,rng.randf_range(-2,2),0.08))
	for pos in [Vector3(-3.4,0.022,8),Vector3(3.8,0.022,-4),Vector3(-3.2,0.022,-18),Vector3(4.2,0.022,-26)]:
		for j in range(3):cylinder(pos+Vector3(j*0.28,0,j*0.2),0.6-j*0.1,0.006,"puddle")
	for side in [-1,1]:
		box(Vector3(side*6,0.14,-9),Vector3(0.09,0.18,36),"wood")
		box(Vector3(side*6,0.14,10),Vector3(0.09,0.18,3),"wood")
		for i in range(4):
			var pos := Vector3(side*7.6,0.2,-5-i*6)
			box(pos,Vector3(0.7,0.18,0.38),"rust",Vector3(0,0.4,0.17))
	finish("midway_detail")

func interiors() -> void:
	for office in [true,false]:
		begin("OfficeDetail" if office else "ShedDetail")
		var half := 3.0 if office else 3.5
		for side in [-1,1]:
			for y in [0.2,2.6]:box(Vector3(side*(half-0.15),y,0),Vector3(0.12,0.12,half*2),"wood" if office else "rust")
			box(Vector3(side*(1.3 if office else 1.5),1.3,half+0.12),Vector3(0.13,2.6,0.16),"ochre")
		for z in [-2,0,2]:box(Vector3(0,3.25 if office else 3.45,z),Vector3(half*2-0.3,0.16,0.18))
		for i in range(12):box(Vector3(-half+0.28+i*(half*2-0.5)/12,1.7,-half+0.14),Vector3(0.065,3.0,0.05),"wood" if office else "steel")
		if office:
			for i in range(5):box(Vector3(-2.5+i*0.19,1.17,-0.45),Vector3(0.13,0.12,0.22),"canvas")
			for y in [1.65,2.35]:
				for i in range(3):box(Vector3(-2.5+i*0.25,y,-2.25),Vector3(0.2,0.2,0.35),"canvas")
			# Empty TV silhouette outlined behind its pedestal, with a loose lead.
			for x in [0.95,2.35]:box(Vector3(x,1.95,-2.8),Vector3(0.045,1.1,0.04),"ochre")
			for y in [1.4,2.5]:box(Vector3(1.65,y,-2.8),Vector3(1.4,0.045,0.04),"ochre")
			beam(Vector3(2.4,1.3,-2.7),Vector3(2.6,0.2,-2.5),0.015,"dark")
		else:
			for side in [-1,1]:
				for i in range(6):cylinder(Vector3(side*2,1.6,-2.25+i*0.28),0.14,0.12,"dark")
				beam(Vector3(side*2.5,1.4,-2),Vector3(side*2.5,3.2,-2),0.075,"rust")
				for i in range(3):ring(Vector3(side*2+0.2*(i-1),1.2,-0.18),0.07,"ochre")
				beam(Vector3(side*2,0.2,-0.4),Vector3(side*0.7,0.1,-2.9),0.025,"dark")
			for x in [-0.4,0,0.4]:box(Vector3(x,2.05,-3.15),Vector3(0.15,0.12,0.05),"red_glow" if x==0 else "dark")
		box(Vector3(0,2.95 if office else 3.3,0),Vector3(0.8,0.08,0.14),"dark")
		box(Vector3(0,2.9 if office else 3.25,0),Vector3(0.6,0.025,0.08),"bulb")
		finish("office_detail" if office else "shed_detail")

func passage() -> void:
	begin("PassageDetail")
	for i in range(3):
		for side in [-1,1]:
			for j in range(5):box(Vector3(side*3.06,0.9,-i*4-1.6+j*0.65),Vector3(0.06,1.5+(j%3)*0.16,0.45),"wood",Vector3((j%3-1)*0.08,0,0))
		for j in range(5):
			beam(Vector3(-3.1+j*1.24,3.5-sin(j*PI/4)*0.6,-i*3),Vector3(-3.1+(j+1)*1.24,3.5-sin((j+1)*PI/4)*0.6,-i*3),0.018,"dark")
	puppet(Vector3(2.7,1.2,-5),0.8)
	rag(Vector3(-2.9,2.1,-7),0.6,1.3,"canvas")
	finish("passage_detail")

func theatre() -> void:
	begin("TheatreDetail")
	for side in [-1,1]:
		for i in range(11):cylinder(Vector3(side*(8.15+i*0.125),4.2,-7.18),0.12,6.2,"curtain")
		rag(Vector3(side*8.8,1.5,-7.0),1.2,0.7,"seat")
		box(Vector3(side*9.8,4.4,-7.4),Vector3(0.18,6.8,0.4),"ochre")
		beam(Vector3(side*12,7,-9),Vector3(side*12,1,-9),0.03)
		for z in [-10,-4,3]:ring(Vector3(side*11,7.05,z),0.35)
		for row in range(3):
			for col in range(4):box(Vector3(side*10-1.65+col*1.1,1.05,3-row*2.7+0.49),Vector3(0.96,0.85,0.12),"seat",Vector3(0,0,0.06 if col==0 else 0))
		box(Vector3(side*11.8,0.1,6),Vector3(1,0.08,0.45),"wood",Vector3(0,side*0.4,0.1))
		puppet(Vector3(side*6.1,3.15,-9.5),1.2)
	for i in range(14):rag(Vector3(-7.8+i*1.2,6.4,-7.12),1.1,0.7+(i%3)*0.22,"curtain")
	for i in range(15):box(Vector3(-7.4+i*1.05,0.93,-9),Vector3(1.0,0.025,4.8),"wood")
	for z in [-11.8,-8.3]:
		box(Vector3(0,6.8,z),Vector3(18,0.16,0.22),"wood")
		for x in [-7,-3,3,7]:beam(Vector3(x,6.8,z),Vector3(x+1.8,7.5,z),0.035,"rust")
	for x in [-5,0,5]:
		cylinder(Vector3(x,6,-5.5),0.22,0.5,"dark",Vector3(0.65,0,0))
		cylinder(Vector3(x,5.8,-5.65),0.16,0.025,"bulb",Vector3(0.65,0,0))
	finish("theatre_detail")

func props() -> void:
	begin("CrateDetail")
	for y in [0.12,0.42,0.72]:box(Vector3(0,y,0.48),Vector3(0.9,0.04,0.035),"dark")
	beam(Vector3(-0.36,0.1,0.5),Vector3(0.36,0.8,0.5),0.035,"wood")
	finish("crate_detail")
	begin("BarrelDetail")
	for y in [0.2,0.85]:
		for i in range(6):ball(Vector3(cos(i*TAU/6)*0.4,y,sin(i*TAU/6)*0.4),0.025,"steel")
	cylinder(Vector3(0.15,1.108,0),0.055,0.015,"dark")
	finish("barrel_detail")
	begin("LampDetail")
	for x in [-0.17,0.17]:
		for z in [-0.17,0.17]:box(Vector3(x,3.95,z),Vector3(0.04,0.5,0.04),"rust")
	for y in [3.7,4.18]:box(Vector3(0,y,0),Vector3(0.42,0.045,0.42),"rust")
	finish("lamp_detail")

