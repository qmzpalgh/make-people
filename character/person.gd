extends Node3D

const SURFACE = preload("res://character/surface.gdshader")
const SKIN = ["f0c7af","deac90","c88e71","a97458","86553e","603c30","422b24"]
const IRIS = ["59402c","976d37","686d4a","59727d","464947"]
const HAIR = ["302523","54382f","825840","ad7655","c8ab78","b5aaa4"]
const FABRIC = ["728778","926a79","4e667f","b17c61","d3bd9c","47434e"]
const CUTS = ["bob01","swept","short02"]
const OUTFITS = ["female_casualsuit01","female_casualsuit02","female_elegantsuit01"]
const DEFAULT = {"name":"Mira Ellis","height":0.5,"frame":0.0,"weight":0.32,"muscle":0.32,"hips":0.5,"inseam":0.5,"jaw":0.48,"cheeks":0.56,"nose":0.46,"lips":0.54,"eyes":0.55,"skin":2,"iris":0,"hair":1,"cut":1,"length":0.5,"outfit":2,"bottom":0,"fabric":2,"pattern":0,"lip_tone":1,"accessory":1,"freckles":0.43}
var state := DEFAULT.duplicate()
var pieces := {}
var materials := {}
var jewelry := Node3D.new()
var head_top := 1.65
var blink_time := 0.0
var blink_interval := 3.8

func surface(kind:int, tone:String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("surface",kind)
	m.set_shader_parameter("dye",Color(tone))
	return m

func _ready() -> void:
	materials = {"skin":surface(0,SKIN[2]),"eye":surface(1,IRIS[2]),"hair":surface(2,HAIR[1]),"cloth":surface(3,FABRIC[0]),"shoe":surface(5,"493c39"),"teeth":surface(5,"817169"),"hat":surface(3,"9e805f")}
	for entry in [["brow","49382f"],["lash","352723"]]:
		var m:=ShaderMaterial.new()
		m.shader=preload("res://character/fibers.gdshader")
		m.set_shader_parameter("dye",Color(entry[1]))
		m.set_shader_parameter("strands",load("res://art/%s.png"%entry[0]))
		materials[entry[0]]=m
	for i in 3:
		add_part("body"+str(i),"skin")
		add_part(OUTFITS[i],"cloth")
		add_part(CUTS[i],"hair")
		pieces["body"+str(i)].material_override=materials.skin.duplicate()
		pieces[OUTFITS[i]].material_override=materials.cloth.duplicate()
	pieces.swept.material_override=surface(7,HAIR[1])
	for entry in [["high-poly","eye"],["eyebrow001","brow"],["eyelashes01","lash"],["shoes01","shoe"],["teeth_base","teeth"],["fedora01","hat"]]:
		add_part(entry[0],entry[1])
	add_child(jewelry)
	for side in [-1,1]:
		var hoop := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius=.0065
		ring.outer_radius=.0077
		ring.rings=32
		ring.ring_segments=8
		hoop.mesh=ring
		var gold := StandardMaterial3D.new()
		gold.albedo_color=Color("dcb57a")
		gold.metallic=.82
		gold.roughness=.23
		hoop.material_override=gold
		hoop.rotation=Vector3(PI/2,.75*side,0)
		jewelry.add_child(hoop)
	apply()

func add_part(part:String, material_key:String) -> void:
	var node := MeshInstance3D.new()
	node.mesh=load("res://art/%s.res"%part)
	node.material_override=materials[material_key]
	node.name=part
	add_child(node)
	pieces[part]=node

func _process(dt:float) -> void:
	blink_time+=dt
	if blink_time>blink_interval+.22:
		blink_time=0.
		blink_interval=randf_range(3.2,6.2)
	if blink_time<blink_interval and blink_time>dt:return
	var progress=clampf((blink_time-blink_interval)/.22,0,1)
	var amount=sin(progress*PI)
	for key in ["body"+str(state.outfit),"eyelashes01"]:
		var node:MeshInstance3D=pieces[key]
		var index=node.find_blend_shape_by_name("blink")
		if index>=0:node.set_blend_shape_value(index,amount)

func apply() -> void:
	if pieces.is_empty(): return
	for i in 3:
		var coverage:=0
		if i==state.outfit:coverage+=1
		if i==state.bottom:coverage+=2
		pieces["body"+str(i)].visible=coverage>0
		pieces[OUTFITS[i]].visible=coverage>0
		pieces["body"+str(i)].material_override.set_shader_parameter("coverage",coverage)
		pieces[OUTFITS[i]].material_override.set_shader_parameter("coverage",coverage)
		pieces[CUTS[i]].visible=i==state.cut
	pieces.fedora01.visible=state.accessory==2
	pieces.fedora01.scale=Vector3(1.17,1.0,1.19)
	pieces.fedora01.position=Vector3(0,.033,-.010)
	materials.shoe.set_shader_parameter("trousers",state.bottom==0)
	jewelry.visible=state.accessory==1
	for node:MeshInstance3D in pieces.values():
		if not node.visible: continue
		for i in node.get_blend_shape_count():
			var key:String=node.mesh.get_blend_shape_name(i)
			if key=="blink":continue
			var value:float=state[key]
			if key in ["weight","muscle"]: value=(value-.32)*1.25
			elif key!="frame": value=(value-.5)*1.7
			node.set_blend_shape_value(i,value)
	scale.y=lerpf(.91,1.09,state.height)
	var hair:MeshInstance3D=pieces[CUTS[state.cut]]
	hair.scale.y=1.0 if state.cut==1 else lerpf(.94,1.07,state.length)
	hair.position.y=(1.-hair.scale.y)*1.62

	head_top=(1.616+.087*state.frame)*scale.y
	for i in 2:
		jewelry.get_child(i).position=Vector3((i*2-1)*(.072+.0039*state.frame),1.445+.117*state.frame,.0495+.0048*state.frame)
	for item in [["skin","skin",SKIN],["eye","iris",IRIS],["hair","hair",HAIR]]:
		materials[item[0]].set_shader_parameter("dye",Color(item[2][state[item[1]]]))
	materials.skin.set_shader_parameter("freckles",state.freckles)
	materials.skin.set_shader_parameter("lip_tone",Color(["c38e7e","b07775","a06670","8c525b","814c50"][state.lip_tone]))
	pieces.swept.material_override.set_shader_parameter("dye",Color(HAIR[state.hair]))
	for i in 3:
		var body_material:ShaderMaterial=pieces["body"+str(i)].material_override
		for param in ["dye","lip_tone","freckles"]:
			body_material.set_shader_parameter(param,materials.skin.get_shader_parameter(param))
		var cloth_material:ShaderMaterial=pieces[OUTFITS[i]].material_override
		cloth_material.set_shader_parameter("dye",Color(FABRIC[state.fabric]))
		cloth_material.set_shader_parameter("secondary",Color(["37434a","51414c","39475c","4b4243","554d4a","32323b"][state.fabric]))
		cloth_material.set_shader_parameter("pattern",state.pattern)
	materials.brow.set_shader_parameter("dye",Color(HAIR[state.hair]).darkened(.22))
