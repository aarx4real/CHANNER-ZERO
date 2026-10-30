extends SceneTree
## Offline texture preparation. Originals are read only; runtime PNGs are separate.
## EXR normals are linear OpenGL tangent data, never sRGB color or displacement.
func _initialize() -> void:
	call_deferred("prepare")
func prepare() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/pbr_texture_catalog.json"))
	var report: Array = []
	for item in catalog.sets:
		var folder: String = "res://assets/textures/pbr_ready/"+item.name
		DirAccess.make_dir_recursive_absolute(folder)
		var result := {"name":item.name,"maps":{},"missing":[]}
		for kind in ["albedo","normal","roughness","metallic","ao"]:
			if not item.maps.has(kind):
				if kind in ["albedo","normal","roughness"]:result.missing.append(kind)
				continue
			# Cloth metal masks do not represent metallic fabric in this game.
			if kind == "metallic" and item.name != "rusty_metal_04":continue
			var input_path: String = item.maps[kind]
			if input_path.ends_with(".exr"):
				input_path = "res://.godot/pbr_exr_zip/"+item.name+"_"+kind+".exr"
			var image := Image.load_from_file(input_path)
			if image == null or image.is_empty():
				push_error("Unreadable image. Run transcode_pbr_exr.py first for EXR sources: "+str(item.maps[kind]))
				quit(1)
				return
			var original_format := image.get_format()
			var original_size := image.get_size()
			var center := image.get_pixel(image.get_width()/2,image.get_height()/2)
			# No sRGB conversion on normal/scalar data. Quantize linear EXR channels
			# to standard PNG data for RGTC/BCn import; no green-channel flip for GL.
			image.convert(Image.FORMAT_RGB8 if kind in ["albedo","normal"] else Image.FORMAT_R8)
			var limit: int = catalog.albedo_limit if kind == "albedo" else catalog.data_limit
			if image.get_width() > limit or image.get_height() > limit:
				var scale := float(limit)/maxi(image.get_width(),image.get_height())
				image.resize(maxi(1,int(image.get_width()*scale)),maxi(1,int(image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
			var output: String = folder+"/"+kind+".png"
			assert(image.save_png(output) == OK,"Could not write "+output)
			result.maps[kind] = {"source":item.maps[kind],"output":output,"width":image.get_width(),"height":image.get_height(),"source_format":original_format,"source_size":[original_size.x,original_size.y],"sample":[center.r,center.g,center.b]}
		report.append(result)
		print("PREPARED: "+str(item.name))
	var file := FileAccess.open("res://tools/pbr_preparation_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("PBR PREPARATION COMPLETE: %d packs" % report.size())
	quit()
