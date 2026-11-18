extends SceneTree

func _initialize() -> void:
	var staging := OS.get_cmdline_user_args()[0]
	for file in DirAccess.get_files_at(staging):
		if not file.ends_with(".bin"):
			continue
		var source := FileAccess.open(staging.path_join(file), FileAccess.READ)
		var count := source.get_32()
		var indices := source.get_32()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = source.get_buffer(count*12).to_vector3_array()
		arrays[Mesh.ARRAY_NORMAL] = source.get_buffer(count*12).to_vector3_array()
		arrays[Mesh.ARRAY_TEX_UV] = source.get_buffer(count*8).to_vector2_array()
		arrays[Mesh.ARRAY_COLOR] = source.get_buffer(count*16).to_color_array()
		arrays[Mesh.ARRAY_INDEX] = source.get_buffer(indices*4).to_int32_array()
		var mesh := ArrayMesh.new()
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		var blends: Array[Array] = []
		for key in JSON.parse_string(FileAccess.get_file_as_string(staging.path_join(file.get_basename()+".json"))):
			mesh.add_blend_shape(key)
			var shape := []
			shape.resize(Mesh.ARRAY_MAX)
			var positions := source.get_buffer(count*12).to_vector3_array()
			var normals := source.get_buffer(count*12).to_vector3_array()
			var base_positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var base_normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for j in count:
				positions[j]+=base_positions[j]
				normals[j]=(normals[j]+base_normals[j]).normalized()
			shape[Mesh.ARRAY_VERTEX]=positions
			shape[Mesh.ARRAY_NORMAL]=normals
			blends.append(shape)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,blends)
		assert(ResourceSaver.save(mesh,"res://art/"+file.get_basename()+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	quit()
