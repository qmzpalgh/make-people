extends Control

const Person = preload("res://character/person.gd")
const Icons = preload("res://studio/icons.gd")
const INK=Color("#302a37")
const MUTED=Color("#716b76")
const PAPER=Color("#fbf9f7")
const LINE=Color("#ded9dc")
const PLUM=Color("#624c70")
const TABS=["Appearance","Body","Face","Hair","Style","Extras"]
const SAVE_DIR="user://people"
var serif:=SystemFont.new()
var sans:=SystemFont.new()
var bold:=SystemFont.new()
var stage:=Control.new()
var inspector:=Panel.new()
var rail:=Panel.new()
var header:=Panel.new()
var fields:=VBoxContainer.new()
var person=Person.new()
var camera:=Camera3D.new()
var tab="Appearance"
var portrait=true
var yaw=-.24
var pitch=.035
var zoom=1.0
var dragging=false
var editing_slider:HSlider
var title_label:Button
var view_toggle:Button
var section_title:Label
var nav={}
var notice:=Label.new()
var current_slot=""
var undo_state={}
var undo_button:Button
var stamp=0

func _ready() -> void:
	serif.font_names=PackedStringArray(["Baskerville","Liberation Serif","Noto Serif"])
	sans.font_names=PackedStringArray(["Inter","Noto Sans","Arial"])
	bold.font_names=sans.font_names
	bold.font_weight=650
	theme=Theme.new()
	theme.default_font=sans
	theme.default_font_size=15
	make_stage()
	make_header()
	make_rail()
	make_inspector()
	refresh()
	get_window().min_size=Vector2i(920,610)
	resized.connect(layout)
	layout()

func box(color:Color, radius:int=0, border:Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	if border.a>0:
		style.set_border_width_all(1)
		style.border_color=border
	return style

func panel_color(node:Panel,color:Color) -> void:
	node.add_theme_stylebox_override("panel",box(color))

func place(node:Control,x:float,y:float,w:float,h:float) -> void:
	node.position=Vector2(x,y)
	node.size=Vector2(w,h)

func label(parent:Control,caption:String,font_size:int,color:Color=INK,font:Font=null) -> Label:
	var node:=Label.new()
	node.text=caption
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.add_theme_font_override("font",font if font else sans)
	parent.add_child(node)
	return node

func decorate(b:Button,bg:Color,fg:Color,r:int=8,border:Color=Color.TRANSPARENT) -> void:
	for mode in ["normal","hover","pressed","hover_pressed"]:
		var fill=bg if mode=="normal" else (Color("#e7e0e8") if bg.a<.1 else bg.lerp(INK,.07))
		var s:=box(fill,r,border)
		s.content_margin_left=12
		s.content_margin_right=12
		b.add_theme_stylebox_override(mode,s)
		b.add_theme_color_override("font_color" if mode=="normal" else "font_"+mode+"_color",fg)
		b.add_theme_color_override("icon_normal_color" if mode=="normal" else "icon_"+mode+"_color",fg)
	b.add_theme_constant_override("icon_max_width",19)
	b.add_theme_constant_override("h_separation",8)

func button(parent:Control,caption:String,icon:String,action:Callable,bg:Color=Color.TRANSPARENT,fg:Color=INK) -> Button:
	var b:=Button.new()
	b.text=caption
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",bold)
	b.add_theme_font_size_override("font_size",14)
	if icon!="": b.icon=Icons.get_icon(icon)
	decorate(b,bg,fg)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func make_header() -> void:
	add_child(header)
	panel_color(header,Color("#342d3b"))
	var mark:=TextureRect.new()
	mark.texture=Icons.get_icon("star")
	mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mark.modulate=Color("#e7cce7")
	header.add_child(mark)
	place(mark,25,22,30,30)
	place(label(header,"The People",32,PAPER,serif),66,12,154,47)
	var rule:=ColorRect.new()
	rule.color=Color("#645969")
	header.add_child(rule)
	place(rule,231,24,1,28)
	place(label(header,"Character studio",15,Color("#e0d7df")),253,19,150,34)
	var library=button(header,"Library","library",open_library,Color("#453b4b"),PAPER)
	library.name="Library"
	var save=button(header,"Save person","save",save_person,Color("#e7cee6"),INK)
	save.name="Save"

func make_rail() -> void:
	add_child(rail)
	panel_color(rail,PAPER)
	for i in TABS.size():
		var key:String=TABS[i]
		var b:=button(rail,key,key,select_tab.bind(key))
		b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width",23)
		b.add_theme_font_size_override("font_size",11)
		b.add_theme_constant_override("v_separation",6)
		place(b,8,20+i*75,84,62)
		nav[key]=b

func make_stage() -> void:
	add_child(stage)
	stage.clip_contents=true
	var container:=SubViewportContainer.new()
	container.stretch=true
	stage.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var vp:=SubViewport.new()
	vp.transparent_bg=false
	vp.own_world_3d=true
	vp.msaa_3d=Viewport.MSAA_2X
	vp.use_taa=true
	vp.scaling_3d_scale=1.18
	container.add_child(vp)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_SKY
	world.environment.sky=Sky.new()
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=preload("res://studio/studio_sky.gdshader")
	world.environment.sky.sky_material=sky_material
	world.environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	world.environment.background_color=Color(0,0,0,0)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("#f2e5f2")
	world.environment.ambient_light_energy=.43
	world.environment.tonemap_mode=Environment.TONE_MAPPER_ACES
	vp.add_child(world)
	vp.add_child(person)
	vp.add_child(camera)
	camera.fov=27.
	camera.near=.035
	for setup in [[Vector3(-2,3.6,3),Color("#fff0db"),.96],[Vector3(2,2.2,2),Color("#e2e9ff"),.40],[Vector3(1,2.6,-1.6),Color("#ffddd1"),.85]]:
		var light:=DirectionalLight3D.new()
		vp.add_child(light)
		light.position=setup[0]
		light.look_at(Vector3(0,1.1,0))
		light.light_color=setup[1]
		light.light_energy=setup[2]
		if setup[2]==.96:
			light.shadow_enabled=true
			light.light_angular_distance=2.8
			light.shadow_bias=.018
			light.directional_shadow_max_distance=5
	var pedestal:=MeshInstance3D.new()
	var disc:=CylinderMesh.new()
	disc.top_radius=.55
	disc.bottom_radius=.55
	disc.height=.027
	disc.radial_segments=112
	pedestal.mesh=disc
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("#bbacbe")
	mat.roughness=.85
	pedestal.material_override=mat
	pedestal.position.y=-.025
	vp.add_child(pedestal)
	var input:=Control.new()
	stage.add_child(input)
	input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input.mouse_default_cursor_shape=Control.CURSOR_DRAG
	input.gui_input.connect(stage_input)
	view_toggle=button(stage,"Full body","full",toggle_view,Color("#f9f5f5df"))
	view_toggle.tooltip_text="Switch between portrait and full body"
	var reset_view=button(stage,"","rotate",reset_camera,Color("#f9f5f5df"))
	reset_view.tooltip_text="Reset camera angle and zoom"
	reset_view.name="ResetCamera"
	var rand_button=button(stage,"Randomise","dice",randomise,Color("#f9f5f5df"))
	rand_button.name="Shuffle"
	var name_plate:=Panel.new()
	name_plate.name="NamePlate"
	name_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	name_plate.add_theme_stylebox_override("panel",box(Color("#f8f4f3dc"),9))
	stage.add_child(name_plate)
	title_label=button(stage,"","edit",rename_person)
	title_label.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	title_label.add_theme_font_override("font",serif)
	title_label.add_theme_font_size_override("font_size",32)
	title_label.add_theme_constant_override("icon_max_width",15)
	title_label.tooltip_text="Rename person"
	var hint=label(stage,"Drag to rotate   ·   Scroll to zoom",12,Color("#4d4556"))
	hint.name="Hint"
	stage.add_child(notice)
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color",PAPER)
	notice.add_theme_stylebox_override("normal",box(PLUM,8))
	notice.hide()

func make_inspector() -> void:
	add_child(inspector)
	panel_color(inspector,PAPER)
	var sc:=ScrollContainer.new()
	sc.name="Scroll"
	sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	inspector.add_child(sc)
	var margin:=MarginContainer.new()
	margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,28)
	margin.add_theme_constant_override("margin_bottom",24)
	sc.add_child(margin)
	fields.add_theme_constant_override("separation",14)
	fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	margin.add_child(fields)
	section_title=label(inspector,"",42,INK,serif)
	place(section_title,26,26,310,57)
	undo_button=button(inspector,"Undo last edit","undo",undo)
	undo_button.name="Undo"
	undo_button.add_theme_stylebox_override("disabled",box(Color.TRANSPARENT,8))
	undo_button.add_theme_color_override("font_disabled_color",Color("#aaa2ab"))

func layout() -> void:
	var side=clampf(size.x*.318,348,440)
	var left=100.
	var top=74.
	place(header,0,0,size.x,top)
	place(header.get_node("Library"),size.x-276,16,110,42)
	place(header.get_node("Save"),size.x-153,16,129,42)
	place(rail,0,top,left,size.y-top)
	place(stage,left,top,size.x-left-side,size.y-top)
	place(inspector,size.x-side,top,side,size.y-top)
	place(inspector.get_node("Scroll"),0,111,side,size.y-top-170)
	place(undo_button,16,inspector.size.y-51,150,36)
	place(view_toggle,20,20,118,38)
	place(stage.get_node("ResetCamera"),145,20,44,38)
	place(stage.get_node("Shuffle"),stage.size.x-146,20,126,38)
	place(stage.get_node("NamePlate"),16,stage.size.y-97,maxf(218,title_label.get_combined_minimum_size().x+12),78)
	place(title_label,20,stage.size.y-96,0,49)
	place(stage.get_node("Hint"),33,stage.size.y-48,260,22)
	place(notice,stage.size.x*.5-100,stage.size.y-49,200,32)
	update_camera()

func stage_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom*(.91 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.65,1.4)
			update_camera()
	if event is InputEventMouseMotion and dragging and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw-=event.relative.x*.009
		pitch=clampf(pitch+event.relative.y*.004,-.22,.28)
		update_camera()

func update_camera() -> void:
	if not is_instance_valid(person) or not camera.is_inside_tree():return
	var top:float=person.head_top
	var aspect=stage.size.x/maxf(stage.size.y,1.)
	var dist=(1.05 if portrait else top*2.64)*zoom*maxf(1.,.72/maxf(aspect,.1))
	var center=Vector3(0,top-(.205 if portrait else top*.49),.04)
	camera.position=center+Vector3(sin(yaw)*cos(pitch),sin(pitch+.035),cos(yaw)*cos(pitch))*dist
	camera.look_at(center)

func reset_camera() -> void:
	yaw=-.24
	pitch=.035
	zoom=1.
	update_camera()

func toggle_view() -> void:
	portrait=not portrait
	zoom=1.
	view_toggle.text="Full body" if portrait else "Portrait"
	view_toggle.icon=Icons.get_icon("full" if portrait else "portrait")
	update_camera()

func select_tab(key:String) -> void:
	tab=key
	if (key in ["Style","Body"] and portrait) or (key in ["Hair","Face","Appearance"] and not portrait):toggle_view()
	refresh()

func refresh() -> void:
	title_label.text=person.state.name
	title_label.reset_size()
	layout()
	section_title.text=tab if tab!="Extras" else "Accessories"
	for key in nav:
		decorate(nav[key],Color("#eae2ed") if tab==key else Color.TRANSPARENT,PLUM if tab==key else MUTED,10)
		nav[key].add_theme_constant_override("icon_max_width",22)
	undo_button.disabled=undo_state.is_empty()
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	inspector.get_node("Scroll").scroll_vertical=0
	match tab:
		"Appearance":
			palette("Complexion","skin",Person.SKIN,["Porcelain","Peach","Warm beige","Honey","Bronze","Umber","Espresso"])
			separate()
			palette("Eye colour","iris",Person.IRIS,["Walnut","Amber","Hazel","Slate blue","Graphite"])
			separate()
			palette("Lip tone","lip_tone",["c38e7e","b07775","a06670","8c525b","814c50"],["Bare","Rose","Mauve","Berry","Fig"])
			separate()
			slider("Freckles","freckles","Clear","Freckled")
		"Body":
			slider("Height","height","Short","Tall")
			slider("Weight","weight","Light","Heavy")
			slider("Musculature","muscle","Soft","Defined")
			slider("Frame","frame","Feminine","Masculine")
			slider("Hip width","hips","Narrow","Broad")
			slider("Leg proportion","inseam","Shorter","Longer")
		"Face":
			for item in [["Jaw width","jaw","Narrow","Broad"],["Cheekbones","cheeks","Soft","Prominent"],["Eye opening","eyes","Narrow","Open"],["Nose width","nose","Fine","Broad"],["Mouth width","lips","Narrow","Wide"]]:
				slider(item[0],item[1],item[2],item[3])
		"Hair":
			choices("Hairstyle","cut",["Layered bob","Ponytail","Short crop"])
			separate()
			palette("Hair colour","hair",Person.HAIR,["Espresso","Chestnut","Walnut","Copper","Wheat","Silver"])
			separate()
			slider("Length","length","Cropped","Grown out")
		"Style":
			choices("Top","outfit",["Crew-neck tee","Casual tee","Collared blouse"])
			separate()
			choices("Bottom","bottom",["Slim trousers","Casual skirt","Tailored skirt"])
			separate()
			palette("Colourway","fabric",Person.FABRIC,["Sage","Mulberry","Denim","Clay","Oat","Charcoal"])
			separate()
			choices("Fabric pattern","pattern",["Plain weave","Pinstripe","Windowpane"])
		"Extras":
			choices("Accessory","accessory",["None","Gold hoops","Felt fedora"])

func separate() -> void:
	var rule:=ColorRect.new()
	rule.color=LINE
	rule.custom_minimum_size.y=1
	fields.add_child(rule)

func field_title(caption:String,detail:String="") -> HBoxContainer:
	var row:=HBoxContainer.new()
	fields.add_child(row)
	var l=label(row,caption,16,INK,bold)
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if detail!="": label(row,detail,12,MUTED)
	return row

func palette(caption:String,key:String,colors:Array,names:Array) -> void:
	field_title(caption,names[person.state[key]])
	var row:=HFlowContainer.new()
	row.add_theme_constant_override("h_separation",8)
	row.add_theme_constant_override("v_separation",6)
	fields.add_child(row)
	for i in colors.size():
		var b:=Button.new()
		var chosen:bool=i==person.state[key]
		b.tooltip_text=names[i]
		b.accessibility_name=names[i]
		b.custom_minimum_size=Vector2(33,33)
		b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var style=box(Color(colors[i]),18,INK if chosen else Color("#00000018"))
		if chosen:style.set_border_width_all(2)
		for mode in ["normal","hover","pressed"]:
			b.add_theme_stylebox_override(mode,style)
		if chosen:
			b.icon=Icons.get_icon("check")
			b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width",15)
			b.add_theme_color_override("icon_normal_color",INK if Color(colors[i]).get_luminance()>.47 else Color.WHITE)
		b.pressed.connect(choose.bind(key,i))
		row.add_child(b)
	var pad:=Control.new()
	pad.custom_minimum_size.y=3
	fields.add_child(pad)

func choices(caption:String,key:String,options:Array) -> void:
	field_title(caption)
	for i in options.size():
		var selected:bool=person.state[key]==i
		var b=button(fields,options[i],"check" if selected else "",choose.bind(key,i))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y=42
		decorate(b,Color("#ede7ef") if selected else PAPER,PLUM if selected else INK,7,PLUM if selected else LINE)

func slider(caption:String,key:String,low:String,high:String) -> void:
	var row=field_title(caption)
	var val=label(row,"%d%%"%roundi(person.state[key]*100),12,MUTED)
	var s:=HSlider.new()
	s.min_value=0
	s.max_value=1
	s.step=.01
	s.value=person.state[key]
	s.accessibility_name=caption
	var track=box(Color("#ddd5df"),3)
	track.content_margin_top=2
	track.content_margin_bottom=2
	s.add_theme_stylebox_override("slider",track)
	var filled=box(PLUM,3)
	filled.content_margin_top=2
	filled.content_margin_bottom=2
	s.add_theme_stylebox_override("grabber_area",filled)
	s.add_theme_stylebox_override("grabber_area_highlight",box(PLUM,3))
	var knob:=GradientTexture2D.new()
	knob.width=16
	knob.height=16
	knob.fill=GradientTexture2D.FILL_RADIAL
	knob.fill_from=Vector2(.5,.5)
	knob.fill_to=Vector2(1,.5)
	knob.gradient=Gradient.new()
	knob.gradient.offsets=PackedFloat32Array([0,.57,.62,.88,1])
	knob.gradient.colors=PackedColorArray([PAPER,PAPER,PLUM,PLUM,Color(PLUM,0)])
	s.add_theme_icon_override("grabber",knob)
	s.add_theme_icon_override("grabber_highlight",knob)
	s.drag_started.connect(func():
		editing_slider=s
		remember())
	s.drag_ended.connect(func(_changed): editing_slider=null)
	s.value_changed.connect(func(value):
		if editing_slider!=s:remember()
		person.state[key]=value
		val.text="%d%%"%roundi(value*100)
		person.apply()
		update_camera())
	fields.add_child(s)
	var ends:=HBoxContainer.new()
	fields.add_child(ends)
	label(ends,low,11,MUTED).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(ends,high,11,MUTED)

func remember() -> void:
	undo_state=person.state.duplicate()
	undo_button.disabled=false

func choose(key:String,value:int) -> void:
	remember()
	person.state[key]=value
	person.apply()
	refresh()

func undo() -> void:
	if undo_state.is_empty():return
	person.state=undo_state
	undo_state={}
	person.apply()
	refresh()
	update_camera()

func randomise() -> void:
	remember()
	for key in Person.DEFAULT:
		if typeof(Person.DEFAULT[key])==TYPE_FLOAT:
			person.state[key]=randf_range(.13,.87)
	for entry in [["skin",7],["iris",5],["hair",6],["fabric",6],["pattern",3],["lip_tone",5],["cut",3],["outfit",3],["bottom",3],["accessory",3]]:
		person.state[entry[0]]=randi()%entry[1]
	person.apply()
	refresh()
	update_camera()

func toast(message:String) -> void:
	stamp+=1
	var ticket=stamp
	notice.text=message
	notice.show()
	await get_tree().create_timer(2.4).timeout
	if stamp==ticket:notice.hide()

func make_dialog(caption:String) -> AcceptDialog:
	var d:=AcceptDialog.new()
	d.title=caption
	d.add_theme_stylebox_override("panel",box(PAPER,8))
	d.get_ok_button().add_theme_font_override("font",bold)
	decorate(d.get_ok_button(),PLUM,PAPER)
	d.exclusive=true
	d.min_size=Vector2i(360,140)
	add_child(d)
	d.close_requested.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.confirmed.connect(d.queue_free)
	return d

func rename_person() -> void:
	var d=make_dialog("Rename person")
	var edit:=LineEdit.new()
	edit.text=person.state.name
	edit.add_theme_stylebox_override("normal",box(Color.WHITE,5,LINE))
	edit.add_theme_color_override("font_color",INK)
	edit.max_length=38
	edit.select_all()
	d.add_child(edit)
	d.register_text_enter(edit)
	d.confirmed.connect(func():
		if not edit.text.strip_edges().is_empty():
			remember()
			person.state.name=edit.text.strip_edges()
			refresh())
	d.popup_centered()
	edit.grab_focus()

func save_person() -> void:
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR)!=OK:
		toast("Library unavailable")
		return
	var id=current_slot
	if id=="":id="person_%s_%s"%[int(Time.get_unix_time_from_system()),randi()]
	var path=SAVE_DIR.path_join(id+".json")
	var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not f:
		toast("Could not save person")
		return
	f.store_string(JSON.stringify({"version":1,"person":person.state},"  ",true,true))
	f.flush()
	var error=f.get_error()
	f.close()
	if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:
		toast("Could not save person")
		return
	current_slot=id
	toast("Saved to your library")

func read_person(path:String) -> Dictionary:
	var doc=JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(doc)!=TYPE_DICTIONARY or doc.get("version")!=1 or typeof(doc.get("person"))!=TYPE_DICTIONARY:return {}
	var result=Person.DEFAULT.duplicate()
	var limits={"skin":6,"iris":4,"hair":5,"cut":2,"pattern":2,"lip_tone":4,"outfit":2,"bottom":2,"fabric":5,"accessory":2}
	for key in result:
		var v=doc.person.get(key,result[key])
		if key=="name":
			if typeof(v)==TYPE_STRING and not v.strip_edges().is_empty():result[key]=v.strip_edges().left(38)
		elif typeof(v) in [TYPE_INT,TYPE_FLOAT]:
			result[key]=clampi(int(v),0,limits[key]) if limits.has(key) else clampf(v,0,1)
	return result

func open_library() -> void:
	var d=make_dialog("People library")
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(350,200)
	d.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var files:=PackedStringArray()
	if DirAccess.dir_exists_absolute(SAVE_DIR):files=DirAccess.get_files_at(SAVE_DIR)
	for file in files:
		if not file.ends_with(".json"):continue
		var record=read_person(SAVE_DIR.path_join(file))
		if record.is_empty():continue
		button(list,record.name,"portrait",func():
			undo_state={}
			person.state=record
			current_slot=file.get_basename()
			person.apply()
			refresh()
			update_camera()
			d.queue_free()
			toast("Person loaded"))
	if list.get_child_count()==0:label(list,"Your saved people will appear here.",14,MUTED)
	button(list,"Create a new person","Appearance",func():
		current_slot=""
		undo_state={}
		person.state=Person.DEFAULT.duplicate()
		person.apply()
		refresh()
		update_camera()
		d.queue_free())
	d.popup_centered()
