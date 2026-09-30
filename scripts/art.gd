extends RefCounted

var world: Node3D
var random := RandomNumberGenerator.new()
var stone_instances: Array[Transform3D] = []
var foliage_instances: Array[Transform3D] = []
var grass_instances: Array[Transform3D] = []
var bark: StandardMaterial3D
var stone: StandardMaterial3D
var leaves: ShaderMaterial
var earth: ShaderMaterial
var grass: ShaderMaterial
var armor: StandardMaterial3D

func _init(owner: Node3D) -> void:
	world = owner
	random.seed = 20741
	bark = world.material(Color("433b31"))
	stone = world.material(Color("74786d"))
	leaves = procedural_material(Color("243b29"), Color("526644"), 6.0, true)
	leaves.set_shader_parameter("leaf_cut",true)
	earth = procedural_material(Color("303d29"), Color("64704b"), 1.8)
	grass = procedural_material(Color("37462b"), Color("84916a"), 12.0, true)

func procedural_material(low: Color, high: Color, detail: float, sway := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 low_color : source_color;
uniform vec3 high_color : source_color;
uniform float detail = 2.0;
uniform bool sway = false;
uniform bool ground = false;
uniform bool leaf_cut = false;
varying vec3 wp;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; if(sway){ VERTEX.x+=sin(TIME*1.4+wp.x*0.6+wp.z)*0.035*max(VERTEX.y,0.0); } }
void fragment(){ ALPHA=1.0; ALPHA_SCISSOR_THRESHOLD=0.5; if(leaf_cut){ ALPHA=smoothstep(0.12,0.23,noise(wp.xz*18.0+wp.y*4.0)); } float n=noise(wp.xz*detail)+noise(wp.xz*detail*5.0)*0.25; ALBEDO=mix(low_color,high_color,n*0.7); ROUGHNESS=0.95; if(ground){ float path=1.0-smoothstep(1.7,2.8,abs(wp.x-sin(wp.z*0.12)*2.2)); path*=smoothstep(-41.0,-38.0,wp.z)*(1.0-smoothstep(23.0,28.0,wp.z)); ALBEDO=mix(ALBEDO,mix(vec3(0.24,0.20,0.145),vec3(0.40,0.345,0.26),n*0.8),path); } }
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("low_color", Vector3(low.r, low.g, low.b))
	mat.set_shader_parameter("high_color", Vector3(high.r, high.g, high.b))
	mat.set_shader_parameter("detail", detail)
	mat.set_shader_parameter("sway", sway)
	return mat

func mesh(parent: Node3D, geometry: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = geometry
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 20
	sphere.rings = 10
	var node := mesh(parent, sphere, pos, mat)
	node.scale = size
	return node

func limb(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var node: MeshInstance3D = world.cylinder(parent, radius, radius * 0.75, start.distance_to(end), (start + end) * 0.5, mat, 12)
	var axis := (end-start).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length() < 0.1: right = Vector3.RIGHT
	node.basis = Basis(right, axis, right.cross(axis)).orthonormalized()
	return node

func rounded_box(size: Vector3, bevel := 0.1) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := size * 0.5 - Vector3.ONE * bevel
	for face in range(6):
		var normal := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD][face] as Vector3
		var axis := Vector3.UP if absf(normal.y) < 0.5 else Vector3.RIGHT
		var tangent := normal.cross(axis)
		for a in range(4):
			for b in range(4):
				for corner in [Vector2(0,0), Vector2(0,1), Vector2(1,0), Vector2(1,0), Vector2(0,1), Vector2(1,1)]:
					var point: Vector3 = (normal + axis * ((a+corner.x)/2.0-1) + tangent * ((b+corner.y)/2.0-1)) * size * 0.5
					var closest := point.clamp(-inner,inner)
					tool.set_normal((point-closest).normalized())
					tool.add_vertex(closest+(point-closest).normalized()*bevel)
	return tool.commit()

func stone_block(pos: Vector3, size: Vector3, rotation := Vector3.ZERO) -> void:
	stone_instances.append(Transform3D(Basis.from_euler(rotation).scaled(size),pos))

func wall(pos: Vector3, size: Vector3) -> void:
	world.box(world,size,pos,stone,true).visible = false
	var along_z := size.z > size.x
	var length := size.z if along_z else size.x
	var depth := size.x if along_z else size.z
	var rows := int(ceil(size.y/0.42))
	for row in range(rows):
		var count := int(ceil(length/0.85))
		for column in range(count):
			var offset := (float(column)+0.5)/count*length-length*0.5
			var block_size := Vector3(depth, size.y/rows-0.025, length/count-0.025) if along_z else Vector3(length/count-0.025,size.y/rows-0.025,depth)
			var block_pos := pos + Vector3(0,(row+0.5)*size.y/rows-size.y/2,0)
			block_pos += Vector3(0,0,offset) if along_z else Vector3(offset,0,0)
			stone_block(block_pos, block_size, Vector3(0,random.randf_range(-0.015,0.015),0))

func terrain_height(x: float, z: float) -> float:
	var edge := smoothstep(12,35,absf(x))
	return edge*(sin(x*0.12+z*0.08)*1.4+cos(z*0.13)*0.9+1.5)

func terrain() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-55,55):
		for z in range(-55,55):
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var px: float = x+offset.x
				var pz: float = z+offset.y
				tool.set_smooth_group(0)
				tool.add_vertex(Vector3(px,terrain_height(px,pz),pz))
	tool.generate_normals()
	earth.set_shader_parameter("ground",true)
	var geometry := tool.commit()
	var ground := mesh(world,geometry,Vector3.ZERO,earth)
	ground.create_trimesh_collision()

func rock(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 14
	sphere.rings = 9
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var v := vertices[i]
		vertices[i] = v * (1.0+sin(v.x*5+v.y*7)*cos(v.z*6)*0.13)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var result := mesh(world,geometry,pos,stone)
	result.scale = size
	return result

func tree(pos: Vector3, height: float) -> void:
	pos.y = terrain_height(pos.x,pos.z)
	limb(world,pos,pos+Vector3(0.15,height*0.85,0.05),0.22,bark)
	for tier in range(6):
		var y := height*(0.35+float(tier)*0.105)
		var reach := height*(0.28-float(tier)*0.032)
		for side in range(5):
			var angle := side*TAU/5+tier*0.8
			var end := pos+Vector3(cos(angle)*reach,y+0.3,sin(angle)*reach)
			if tier % 2 == 0:
				limb(world,pos+Vector3(0,y,0),end,0.045,bark)
			var size := Vector3(reach*0.7,0.30,reach*0.4)
			foliage_instances.append(Transform3D(Basis.from_euler(Vector3(0,-angle,0)).scaled(size),end))
	foliage_instances.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.45,0.8,0.45)),pos+Vector3(0,height,0)))
	var collision := StaticBody3D.new()
	collision.position = pos+Vector3(0,1.5,0)
	var shape := CollisionShape3D.new()
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.24
	trunk.height = 3
	shape.shape = trunk
	collision.add_child(shape)
	world.add_child(collision)

func instances(geometry: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = geometry
	multimesh.instance_count = transforms.size()
	for i in transforms.size(): multimesh.set_instance_transform(i,transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = mat
	world.add_child(node)

func finish() -> void:
	instances(rounded_box(Vector3.ONE,0.07),stone_instances,stone)
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 12
	sphere.rings = 6
	instances(sphere,foliage_instances,leaves)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,0.7,1.4,2.1,2.8]:
		var points := [Vector3(-0.035,0,0),Vector3(0.06,0.4,0.06),Vector3(0.035,0,0),Vector3(0.035,0,0),Vector3(0.06,0.4,0.06),Vector3(0.10,0.4,0.06),Vector3(0.06,0.4,0.06),Vector3(0.14,0.8,0.15),Vector3(0.10,0.4,0.06)]
		for point in points:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(point.rotated(Vector3.UP,angle))
	for i in range(8500):
		var x := random.randf_range(-48,48)
		var z := random.randf_range(-48,44)
		if absf(x-sin(z*0.12)*2.2) < 2.9 or (absf(x)<10 and z < -22) or Vector2(x,z-9).length()<8:
			continue
		grass_instances.append(Transform3D(Basis.from_euler(Vector3(0,random.randf()*TAU,0)).scaled(Vector3.ONE*random.randf_range(0.25,0.7)),Vector3(x,terrain_height(x,z),z)))
	instances(tool.commit(),grass_instances,grass)

func sword(parent: Node3D, centered := true) -> void:
	var offset := 0.0 if centered else 0.38
	# A diamond cross-section gives the steel blade a ridge and two actual cutting edges.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := [-0.35,0.24,0.40]
	var widths := [0.044,0.034,0.0]
	for segment in range(2):
		for face in range(4):
			var ring := [Vector2(-1,0),Vector2(0,0.28),Vector2(1,0),Vector2(0,-0.28)]
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var level: int = segment+corner.y
				var p: Vector2 = ring[(face+corner.x)%4]*widths[level]
				tool.add_vertex(Vector3(p.x,levels[level]+offset,p.y))
	tool.generate_normals()
	mesh(parent,tool.commit(),Vector3.ZERO,world.steel)
	var guard: MeshInstance3D = world.cylinder(parent,0.022,0.016,0.26,Vector3(0,-0.37+offset,0),world.brass,12)
	guard.rotation.z = PI/2
	world.cylinder(parent,0.028,0.023,0.21,Vector3(0,-0.49+offset,0),world.leather,12)
	for i in range(8):
		world.cylinder(parent,0.029,0.029,0.007,Vector3(0,-0.4-i*0.023+offset,0),world.dark,12)
	ellipsoid(parent,Vector3(0,-0.63+offset,0),Vector3(0.043,0.04,0.028),world.brass)

func knight(parent: Node3D, boss: bool) -> Dictionary:
	var metal: Material = world.boss_armor if boss else world.enemy_armor
	ellipsoid(parent,Vector3(0,1.16,0),Vector3(0.29,0.37,0.18),metal)
	ellipsoid(parent,Vector3(0,0.85,0),Vector3(0.25,0.16,0.16),world.leather)
	ellipsoid(parent,Vector3(0,1.72,0),Vector3(0.2,0.26,0.2),world.steel)
	mesh(parent,rounded_box(Vector3(0.28,0.027,0.024),0.008),Vector3(0,1.75,-0.193),world.dark)
	limb(parent,Vector3(0,1.54,-0.15),Vector3(0,1.77,-0.2),0.02,metal)
	var legs: Array[Node3D] = []
	var rig: Dictionary = {}
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side*0.15,0.8,0)
		parent.add_child(leg)
		limb(leg,Vector3.ZERO,Vector3(0,-0.36,0),0.095,world.leather)
		ellipsoid(leg,Vector3(0,-0.37,-0.015),Vector3(0.105,0.1,0.1),metal)
		limb(leg,Vector3(0,-0.42,0),Vector3(0,-0.68,0),0.08,metal)
		ellipsoid(leg,Vector3(0,-0.72,-0.065),Vector3(0.09,0.075,0.16),world.leather)
		legs.append(leg)
		ellipsoid(parent,Vector3(side*0.34,1.4,0),Vector3(0.17,0.13,0.19),metal)
		var upper := limb(parent,Vector3(side*0.35,1.32,0),Vector3(side*0.43,1.06,0),0.085,world.leather)
		var lower := limb(parent,Vector3(side*0.43,1.06,0),Vector3(side*0.43,0.83,-0.13),0.073,metal)
		var hand := ellipsoid(parent,Vector3(side*0.43,0.81,-0.16),Vector3(0.075,0.09,0.07),world.leather)
		if side>0:
			rig = {"upper":upper,"lower":lower,"hand":hand}
	for i in range(6):
		world.cylinder(parent,0.008,0.008,0.018,Vector3(-0.2+i*0.08,1.2,-0.18),world.brass,8).rotation.x = PI/2
	var cape := mesh(parent,rounded_box(Vector3(0.43,0.75,0.03),0.012),Vector3(0,1.13,0.18),world.red_cloth)
	cape.rotation.x = -0.15
	rig["legs"] = legs
	return rig

func update_limb(node: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	node.position = (start+end)*0.5
	(node.mesh as CylinderMesh).height = start.distance_to(end)
	var axis := (end-start).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length()<0.01: right = Vector3.RIGHT
	node.basis = Basis(right,axis,right.cross(axis)).orthonormalized()

func animate_arm(rig: Dictionary, weapon: Node3D) -> void:
	var hand: Vector3 = weapon.position + weapon.basis*Vector3(0,-0.11,0)
	var shoulder := Vector3(0.35,1.32,0)
	var elbow := shoulder.lerp(hand,0.52)+Vector3(0.17,0,0.12)
	update_limb(rig.upper,shoulder,elbow)
	update_limb(rig.lower,elbow,hand)
	rig.hand.position = hand
