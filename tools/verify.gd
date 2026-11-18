extends SceneTree
## Run with an isolated XDG_DATA_HOME. Optional user argument is a screenshot directory.

var studio
var display:=SubViewport.new()
var output:=""
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(condition:bool,message:String) -> void:
	if not condition:
		failures+=1
		push_error(message)

func capture(file:String) -> void:
	if output.is_empty():return
	for i in 26:await process_frame
	await RenderingServer.frame_post_draw
	var result=display.get_texture().get_image().save_png(output.path_join(file+".png"))
	check(result==OK,"Could not capture "+file)

func run() -> void:
	seed(4722)
	var args=OS.get_cmdline_user_args()
	if args.size():output=args[0]
	display.size=Vector2i(1360,840)
	display.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(display)
	studio=load("res://studio/studio.tscn").instantiate()
	display.add_child(studio)
	await process_frame
	var person=studio.person
	person.set_process(false)
	var original:Dictionary=person.state.duplicate()
	await capture("character-studio")
	for section in studio.TABS:
		studio.nav[section].pressed.emit()
		check(studio.tab==section,"Navigation failed for "+section)
	studio.select_tab("Body")
	var slider:Slider
	for control in studio.fields.get_children():
		if control is HSlider:
			slider=control
			break
	slider.value=.91
	check(is_equal_approx(person.state.height,.91) and person.scale.y>1.07,"Height slider did not update the mesh")
	studio.undo()
	check(is_equal_approx(person.state.height,original.height),"Undo failed")
	studio.choose("weight",1)
	studio.choose("outfit",0)
	studio.choose("accessory",2)
	studio.choose("frame",1)
	check(person.pieces.body0.get_blend_shape_value(person.pieces.body0.find_blend_shape_by_name("weight"))>.7,"Body shape did not reach its GPU target")
	await capture("full-body")
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	motion.relative=Vector2(75,10)
	studio.dragging=true
	var yaw:float=studio.yaw
	studio.stage_input(motion)
	check(studio.yaw!=yaw,"Camera did not orbit")
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	studio.stage_input(wheel)
	check(studio.zoom<1.0,"Camera did not zoom")
	studio.reset_camera()
	studio.randomise()
	check(person.state!=original,"Randomisation failed")
	studio.choose("cut",2)
	studio.choose("skin",5)
	studio.choose("outfit",2)
	studio.choose("bottom",1)
	studio.choose("pattern",2)
	studio.choose("accessory",0)
	studio.select_tab("Hair")
	await capture("alternate")
	# A fresh slot ensures this test never overwrites an existing character.
	person.state.name="Studio verification"
	studio.current_slot=""
	studio.save_person()
	var slot:String=studio.current_slot
	var path:String=studio.SAVE_DIR.path_join(slot+".json")
	check(not slot.is_empty() and FileAccess.file_exists(path),"Save failed")
	var expected:Dictionary=person.state.duplicate()
	studio.randomise()
	studio.open_library()
	var library=studio.get_child(-1)
	var match_button:Button
	for candidate in library.find_children("*","Button",true,false):
		if candidate.text==expected.name:match_button=candidate
	if match_button:
		match_button.pressed.emit()
		for key in expected:
			if typeof(expected[key])==TYPE_FLOAT:
				check(is_equal_approx(expected[key],person.state[key]),"Library changed "+key)
			else:check(expected[key]==person.state[key],"Library changed "+key)
		check(studio.current_slot==slot,"Library did not restore the saved state")
	else:check(false,"Saved person missing from library")
	if not slot.is_empty():DirAccess.remove_absolute(path)
	print("Studio verification: ",failures," failure(s)")
	quit(1 if failures else 0)
