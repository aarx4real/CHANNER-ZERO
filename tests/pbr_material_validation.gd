extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:failures += 1
func run() -> void:
	var count := 0
	for name in DirAccess.get_files_at("res://materials/pbr"):
		if not name.ends_with(".tres"):continue
		var material = load("res://materials/pbr/"+name)
		check(material is StandardMaterial3D,"Standard PBR: "+name)
		if not material is StandardMaterial3D:continue
		count += 1
		check(material.albedo_texture != null and material.albedo_texture.get_width() <= 2048,"Albedo/resolution: "+name)
		check(material.normal_enabled and material.normal_texture != null and material.normal_texture.get_width() <= 1024,"GL normal/resolution: "+name)
		check(not material.heightmap_enabled,"No displacement/height shortcut: "+name)
		check(material.roughness_texture != null or material.roughness >= 0.9,"Roughness or matte fallback: "+name)
		check(material.uv1_triplanar and (material.uv1_world_triplanar or name == "hessian_burlap_local.tres"),"Physical-scale projection: "+name)
	check(count == 25,"All 23 sets and two variants load")
	var report: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/pbr_preparation_report.json"))
	for item in report:
		for kind in item.maps:
			var entry: Dictionary = item.maps[kind]
			check(ResourceLoader.exists(entry.output),"Imported texture: "+str(item.name)+" / "+str(kind))
			var options := ConfigFile.new()
			options.load(entry.output+".import")
			check(options.get_value("params","compress/mode") == 2 and options.get_value("params","mipmaps/generate") == true,"VRAM/mipmaps: "+str(item.name)+" / "+str(kind))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var map = scene.get_node("HauntedCarnival")
	var required := {
		"Terrain/IrregularFairgroundFloor/Soil":"brown_mud_03",
		"Terrain/LowLandscapeBanks/RoundedBanks":"forest_leaves_02",
		"StoryQuarter/ControlRoom/Floor/Mesh":"dirty_tiles",
		"StoryQuarter/OwnersOffice/NorthWall0/Mesh":"decrepit_wallpaper",
		"StoryQuarter/FinalTheatre/Floor/Mesh":"old_wood_floor",
		"PowerShed/Roof/Mesh":"worn_corrugated_iron"}
	for path in required:
		var mesh: MeshInstance3D = map.get_node(path)
		check(mesh.material_override != null and mesh.material_override.resource_path.ends_with(required[path]+".tres"),"Scene assignment: "+path)
	check(not scene.get_node("ScarecrowPlayer").hands.is_visible_in_tree(),"Identity-safe hidden viewmodel")
	print("PBR VALIDATION COMPLETE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
