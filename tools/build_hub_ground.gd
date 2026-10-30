extends SceneTree
## Offline baker for an irregular fairground floor and broad curved path ribbons.
## Run --headless --script res://tools/build_hub_ground.gd after editing the JSON.
func _initialize() -> void:
	call_deferred("bake")
func vertex(surface: SurfaceTool, point: Vector3) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(point.x,point.z)*0.12)
	surface.add_vertex(point)
func bake() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/hub_layout_ground.json"))
	var outline := PackedVector2Array()
	for point in data.outline:
		outline.append(Vector2(point[0],point[1]))
	var indices := Geometry2D.triangulate_polygon(outline)
	assert(not indices.is_empty(), "Fairground outline could not be triangulated")
	var floor_surface := SurfaceTool.new()
	floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for index in indices:
		var p := Vector3(outline[index].x,0,outline[index].y)
		vertex(floor_surface,p)
		faces.append(p)
	var floor_mesh := floor_surface.commit()
	floor_mesh.surface_set_material(0,load("res://materials/pbr/brown_mud_03.tres"))
	var root := Node3D.new()
	root.name = "HubGround"
	var body := StaticBody3D.new()
	body.name = "IrregularFairgroundFloor"
	root.add_child(body)
	body.owner = root
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Soil"
	mesh_node.mesh = floor_mesh
	body.add_child(mesh_node)
	mesh_node.owner = root
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.name = "FloorCollision"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = root
	for path_index in range(data.paths.size()):
		var path: Array = data.paths[path_index]
		var curve := Curve3D.new()
		for i in range(path[2].size()):
			var point: Array = path[2][i]
			var p := Vector3(point[0],0.02+path_index*0.004,point[1])
			var closed: bool = path[2][0] == path[2][-1]
			var previous: Array = path[2][-2] if closed and i == 0 else path[2][maxi(i-1,0)]
			var following: Array = path[2][1] if closed and i == path[2].size()-1 else path[2][mini(i+1,path[2].size()-1)]
			var tangent := Vector3(following[0]-previous[0],0,following[1]-previous[1])*0.17
			curve.add_point(p,-tangent,tangent)
		var points := curve.tessellate_even_length(5,0.8)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var left := PackedVector3Array()
		var right := PackedVector3Array()
		for i in range(points.size()):
			var closed: bool = path[2][0] == path[2][-1]
			var before := points[-2] if closed and i == 0 else points[maxi(i-1,0)]
			var after := points[1] if closed and i == points.size()-1 else points[mini(i+1,points.size()-1)]
			var direction := (after-before).normalized()
			var across := Vector3(-direction.z,0,direction.x)*float(path[1])*0.5
			left.append(points[i]-across)
			right.append(points[i]+across)
		for i in range(points.size()-1):
			for p in [left[i],left[i+1],right[i],right[i],left[i+1],right[i+1]]:
				vertex(surface,p)
		var mesh := surface.commit()
		mesh.surface_set_material(0,load("res://materials/pbr/asphalt_02.tres"))
		var node := MeshInstance3D.new()
		node.name = path[0]
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		node.owner = root
	# Low, rounded terrain forms separate route loops without walling in the hub.
	var banks := SurfaceTool.new()
	banks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank_faces := PackedVector3Array()
	for mound in data.mounds:
		for ring in range(6):
			for sector in range(24):
				var quad := PackedVector3Array()
				for corner in [Vector2(ring,sector),Vector2(ring+1,sector),Vector2(ring,sector+1),Vector2(ring+1,sector+1)]:
					var radius: float = corner.x/6.0
					var angle: float = corner.y*TAU/24.0
					quad.append(Vector3(mound[0]+cos(angle)*radius*mound[2],(0.5+0.5*cos(radius*PI))*mound[4]+0.003,mound[1]+sin(angle)*radius*mound[3]))
				for index in [0,2,1,1,2,3]:
					banks.add_vertex(quad[index])
					bank_faces.append(quad[index])
	banks.generate_normals()
	var bank_mesh := banks.commit()
	bank_mesh.surface_set_material(0,load("res://materials/pbr/forest_leaves_02.tres"))
	var bank_body := StaticBody3D.new()
	bank_body.name = "LowLandscapeBanks"
	root.add_child(bank_body)
	bank_body.owner = root
	var bank_instance := MeshInstance3D.new()
	bank_instance.name = "RoundedBanks"
	bank_instance.mesh = bank_mesh
	bank_body.add_child(bank_instance)
	bank_instance.owner = root
	var bank_shape := ConcavePolygonShape3D.new()
	bank_shape.backface_collision = true
	bank_shape.set_faces(bank_faces)
	var bank_collision := CollisionShape3D.new()
	bank_collision.name = "BankCollision"
	bank_collision.shape = bank_shape
	bank_body.add_child(bank_collision)
	bank_collision.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	assert(ResourceSaver.save(packed,"res://scenes/maps/hub_ground.tscn") == OK)
	root.free()
	print("HUB GROUND BAKE COMPLETE")
	quit()

