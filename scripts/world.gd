extends Node3D

const LanScript = preload("res://scripts/lan.gd")

const ArtScript = preload("res://scripts/art.gd")

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
var net: Node
var lan_button: Button
var art: ArtScript
var player: CharacterBody3D
var rng := RandomNumberGenerator.new()
var steel: StandardMaterial3D
var brass: StandardMaterial3D
var leather: StandardMaterial3D
var dark: StandardMaterial3D
var enemy_armor: StandardMaterial3D
var boss_armor: StandardMaterial3D
var red_cloth: StandardMaterial3D
var warning_mat: StandardMaterial3D
var health_mat: StandardMaterial3D
var wood := 0
var ore := 0
var gold := 0
var kills := 0
var boss_dead := false
var victory := false
var resources: Array[Dictionary] = []
var focus: Dictionary = {}
var hit_flash := 0.0
var message_time := 0.0
var rest_cooldown := 0.0
var hud: Control
var menu: PanelContainer
var menu_title: Label
var menu_copy: Label
var play_button: Button
var quest_label: Label
var inventory_label: Label
var prompt_label: Label
var notice_label: Label
var location_label: Label
var compass_label: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var health_label: Label
var stamina_label: Label
var crosshair: Label
var damage_overlay: ColorRect
var journal: PanelContainer
var paused := false
var hit_stop := 0.0
var combat_label: Label
var combat_time := 0.0
var direction_labels: Array[Label] = []
var stance_label: Label

func material(color: Color, metallic := 0.0, roughness := 0.85) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var primitive := BoxMesh.new()
	primitive.size = size
	mesh.mesh = primitive
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func cylinder(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, mat: Material, sides := 7) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var primitive := CylinderMesh.new()
	primitive.bottom_radius = bottom
	primitive.top_radius = top
	primitive.height = height
	primitive.radial_segments = sides
	mesh.mesh = primitive
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

func _ready() -> void:
	rng.seed = 7319
	setup_input()
	steel = material(Color("a0abb0"), 0.7, 0.3)
	brass = material(Color("c99f55"), 0.65, 0.4)
	leather = material(Color("39312e"))
	dark = material(Color("131e22"))
	enemy_armor = material(Color("636b69"), 0.35)
	boss_armor = material(Color("292c35"), 0.6)
	red_cloth = material(Color("854936"))
	warning_mat = material(Color("ffbc63"))
	warning_mat.emission_enabled = true
	warning_mat.emission = Color("ff9e40")
	health_mat = material(Color("d97161"))
	art = ArtScript.new(self)
	build_world()
	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 13)
	add_child(player)
	for pos in [Vector3(-6, 0.1, -9), Vector3(9, 0.1, -17), Vector3(-11, 0.1, -28), Vector3(3, 0.1, -32)]:
		var enemy := EnemyScript.new()
		enemy.position = pos
		enemy.boss = pos.z < -30
		add_child(enemy)
	build_ui()
	net = LanScript.new()
	net.name = "LAN"
	add_child(net)
	player.stats_changed.connect(update_stats)
	update_stats()
	show_menu("ASCHENMARK", "D I E   G R E N Z L A N D E\n\nDer Pass ist gefallen. Zwischen Kiefern und alten Mauern\nwacht noch immer der letzte Ritter.\n\nErkunde die Grenzlande. Verbessere deine Klinge.\nBesiege den Ruinenwächter und kehre zum Feuer zurück.", "Grenzlande betreten")

func setup_input() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "interact": KEY_E, "journal": KEY_J, "feint": KEY_Q, "direction_0": KEY_1, "direction_1": KEY_2, "direction_2": KEY_3, "direction_3": KEY_4}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)
	for action in ["attack", "block"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)

func build_world() -> void:
	var env := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_shader := Shader.new()
	sky_shader.code = """shader_type sky;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void sky(){float y=max(EYEDIR.y,0.0);vec3 base=mix(vec3(0.49,0.50,0.45),vec3(0.13,0.23,0.32),pow(y,0.45));vec2 p=EYEDIR.xz/max(0.22,y)*1.6;float clouds=n(p)+n(p*2.1)*0.45+n(p*4.2)*0.2;clouds=smoothstep(0.65,1.05,clouds)*smoothstep(0.02,0.25,y);COLOR=mix(base,vec3(0.64,0.65,0.60),clouds*0.6);}
"""
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky.sky_material = sky_mat
	atmosphere.sky = sky
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("a4bac3")
	atmosphere.ambient_light_energy = 0.28
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("7d9294")
	atmosphere.fog_density = 0.0035
	atmosphere.fog_sky_affect = 0.05
	env.environment = atmosphere
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-27, -35, 0)
	sun.light_color = Color("ffd8a0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80
	add_child(sun)
	var ground := material(Color("414b37"))
	var stone := material(Color("727969"))
	var pale_stone := material(Color("969987"))
	var bark := material(Color("514234"))
	art.terrain()
	for i in range(65):
		var pos := Vector3(art.random.randf_range(-48, 48), 0, art.random.randf_range(-48, 45))
		if absf(pos.x) < 7 or pos.distance_to(Vector3(0, 0, 8)) < 11 or pos.distance_to(Vector3(0, 0, -30)) < 14:
			continue
		art.tree(pos,art.random.randf_range(6.0,10.0))
	for i in range(65):
		var pos := Vector3(art.random.randf_range(-45,45),0,art.random.randf_range(-45,40))
		if absf(pos.x)<7: continue
		pos.y=art.terrain_height(pos.x,pos.z)+0.15
		art.rock(pos,Vector3(art.random.randf_range(0.4,1.4),art.random.randf_range(0.3,0.9),art.random.randf_range(0.5,1.3)))
	for i in range(16):
		var angle := float(i)/16*TAU
		var height := art.random.randf_range(15,29)
		var ridge := art.rock(Vector3(sin(angle)*105,height*0.2-4,cos(angle)*105),Vector3(art.random.randf_range(23,32),height*0.85,art.random.randf_range(18,27)))
		ridge.material_override = material(Color("536461"))
	# Ruined abbey, open south entrance and accessible courtyard.
	for side in [-1.0, 1.0]:
		art.wall(Vector3(side*9,1.9,-30),Vector3(1.3,3.8,14))
		art.wall(Vector3(side*6.7,1.8,-23),Vector3(5.4,3.6,1.3))
		for z in [-23.0, -30.0, -37.0]:
			art.wall(Vector3(side*9,2.6,z),Vector3(2,5.2,2))
			art.stone_block(Vector3(side*9,5.2,z),Vector3(2.3,0.25,2.3))
			for k in [-0.7, 0.7]:
				art.stone_block(Vector3(side*9+k,5.7,z),Vector3(0.55,0.75,1.8))
		for z in range(-36, -23, 3):
			art.stone_block(Vector3(side*9,4.15,z),Vector3(1.4,0.7,1.2))
	art.wall(Vector3(0,2.1,-38),Vector3(18,4.2,1.5))
	box(self, Vector3(17, 0.05, 13), Vector3(0, 0.035, -30.5), material(Color("656953")))
	for x in [-3.2, 3.2]:
		art.wall(Vector3(x,1.5,-23),Vector3(0.8,3,1.0))
	for segment in range(19):
		var angle := (segment+0.5)*PI/19
		art.stone_block(Vector3(cos(angle)*3.2,3+sin(angle)*3.2,-23),Vector3(0.54,0.75,1.1),Vector3(0,0,angle-PI/2))
	for side in [-1.0, 1.0]:
		var banner := box(self, Vector3(1, 2.2, 0.06), Vector3(side * 4.6, 3.1, -22.28), red_cloth)
		banner.rotation.z = side * 0.04
		box(self, Vector3(0.12, 0.9, 0.07), Vector3(side * 4.6, 3.2, -22.23), brass)
		box(self, Vector3(0.55, 0.12, 0.07), Vector3(side * 4.6, 3.3, -22.22), brass)
	art.wall(Vector3(0,0.35,-36),Vector3(2.2,0.65,1.2))
	for i in range(16):
		art.rock(Vector3(art.random.randf_range(-8,8),0.18,art.random.randf_range(-37,-26)),Vector3(0.5,0.25,0.4))
	# Camp with forge, fire, canvas tents and a supply bench.
	var canvas := material(Color("b4a47c"))
	for x in [-6.5,6.5]:
		var tent := cylinder(self,2.2,0.12,3.1,Vector3(x,1.55,12),canvas,24)
		art.ellipsoid(self,Vector3(x,0.65,13.9),Vector3(0.55,0.7,0.05),dark)
		art.limb(self,Vector3(x,0,12),Vector3(x,3.3,12),0.045,bark)
		for side in [-1.0,1.0]:
			art.limb(self,Vector3(x+side*1.3,1.3,13),Vector3(x+side*2.7,0,14),0.012,canvas)
	for i in range(13):
		var angle := float(i)/13*TAU
		art.rock(Vector3(cos(angle)*0.8,0.16,7+sin(angle)*0.8),Vector3(0.25,0.2,0.2))
	for angle in [0.4,-0.4]:
		var log_mesh := cylinder(self,0.12,0.1,1.3,Vector3(0,0.18,7),bark,12)
		log_mesh.rotation = Vector3(0,angle,PI/2)
	var flame := material(Color("ef9a40"))
	flame.emission_enabled = true
	flame.emission = Color("ff8a32")
	var fire_visual := Node3D.new()
	fire_visual.position = Vector3(0,0.3,7)
	add_child(fire_visual)
	for i in range(7):
		var tongue := art.ellipsoid(fire_visual,Vector3(sin(i*2)*0.18,0.2,cos(i*2)*0.18),Vector3(0.12,0.35+float(i%3)*0.07,0.1),flame)
		var flicker := tongue.create_tween().set_loops()
		flicker.tween_property(tongue,"scale:y",tongue.scale.y*0.65,0.2+float(i)*0.025)
		flicker.tween_property(tongue,"scale:y",tongue.scale.y,0.16+float(i)*0.018)
	var fire := OmniLight3D.new()
	fire.position = Vector3(0, 1.3, 7)
	fire.light_color = Color("ffac55")
	fire.light_energy = 2.2
	fire.omni_range = 9
	add_child(fire)
	resources.append({"kind": "fire", "pos": Vector3(0, 0, 7), "node": fire})
	art.wall(Vector3(4,0.35,7),Vector3(1.8,0.7,1.1))
	art.mesh(self,art.rounded_box(Vector3(1.3,0.23,0.65),0.08),Vector3(4,0.85,7),steel)
	box(self, Vector3(0.6, 0.36, 0.5), Vector3(4, 0.68, 7), steel)
	resources.append({"kind": "forge", "pos": Vector3(4, 0, 7)})
	for x in [-3.0, 3.0]:
		box(self,Vector3(1.7,0.18,0.5),Vector3(x,0.55,10),bark,true).visible=false
		art.mesh(self,art.rounded_box(Vector3(1.7,0.18,0.5),0.05),Vector3(x,0.55,10),bark)
		for leg in [-0.6, 0.6]:
			art.limb(self,Vector3(x+leg,0,10),Vector3(x+leg,0.52,10),0.07,bark)
	# Resource nodes are deliberately placed beside the approach to the ruins.
	for pos in [Vector3(-5, 0, 1), Vector3(6, 0, -4), Vector3(-7, 0, -15), Vector3(7, 0, -10)]:
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		for i in range(3):
			var log_mesh := cylinder(node, 0.18, 0.18, 1.4, Vector3(i * 0.27 - 0.27, 0.22, 0), bark)
			log_mesh.rotation.z = PI / 2
		resources.append({"kind": "wood", "pos": pos, "node": node, "used": false})
	for pos in [Vector3(6, 0, 1), Vector3(-6, 0, -6), Vector3(7, 0, -19), Vector3(-6, 0, -19)]:
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		var ore_rock := art.rock(pos+Vector3(0,0.35,0),Vector3(0.8,0.65,0.65))
		ore_rock.reparent(node,true)
		for i in range(3):
			art.ellipsoid(node,Vector3(i*0.23-0.23,0.83,0.1),Vector3(0.085,0.18,0.08),brass).rotation.z=i*0.4
		resources.append({"kind": "ore", "pos": pos, "node": node, "used": false})
	# Ivy softens the stone edges, while ferns mark the forest floor.
	for side in [-1.0,1.0]:
		for i in range(70):
			var y := art.random.randf_range(0.2,3.5)
			var x: float = side*(7.1+sin(y*2)*0.5+art.random.randf_range(-0.3,0.3))
			art.foliage_instances.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.18,0.15,0.08)),Vector3(x,y,-22.28)))
	art.finish()
	# Invisible collision barriers keep the explored area finite.
	for side in [-1.0, 1.0]:
		var boundary := box(self, Vector3(1, 15, 110), Vector3(side * 52, 7.5, 0), ground, true)
		boundary.visible = false
		boundary = box(self, Vector3(110, 15, 1), Vector3(0, 7.5, side * 52), ground, true)
		boundary.visible = false

func panel_style(color: Color, border := Color("60594b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func label(text: String, size: int, color := Color("e4dfcf")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.7, 0.08, 0.03, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(damage_overlay)
	var bottom_shade := ColorRect.new()
	bottom_shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_shade.offset_top = -172
	bottom_shade.color = Color(0.035, 0.055, 0.055, 0.84)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom_shade)
	var compass_shade := ColorRect.new()
	compass_shade.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass_shade.position = Vector2(-160, 18)
	compass_shade.size = Vector2(320, 36)
	compass_shade.color = Color(0.035, 0.055, 0.055, 0.84)
	compass_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(compass_shade)
	location_label = label("ASCHENMARK  /  GRENZLANDE", 17, Color("d7bd86"))
	location_label.add_theme_constant_override("outline_size", 6)
	location_label.add_theme_color_override("font_outline_color", Color("182523"))
	location_label.position = Vector2(32, 26)
	hud.add_child(location_label)
	var quest_panel := PanelContainer.new()
	quest_panel.position = Vector2(32, 68)
	quest_panel.custom_minimum_size = Vector2(325, 0)
	quest_panel.add_theme_stylebox_override("panel", panel_style(Color(0.06, 0.09, 0.09, 0.88)))
	hud.add_child(quest_panel)
	var quest_box := VBoxContainer.new()
	quest_box.add_theme_constant_override("separation", 9)
	quest_panel.add_child(quest_box)
	quest_box.add_child(label("DER LETZTE WÄCHTER", 14, Color("d7bd86")))
	quest_label = label("", 18)
	quest_box.add_child(quest_label)
	quest_box.add_child(label("J  ·  Reisetagebuch", 13, Color("9da79d")))
	compass_label = label("", 16)
	compass_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass_label.position = Vector2(-160, 26)
	compass_label.size.x = 320
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(compass_label)
	var stats := VBoxContainer.new()
	stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stats.position = Vector2(32, -158)
	stats.size = Vector2(310, 126)
	stats.add_theme_constant_override("separation", 6)
	hud.add_child(stats)
	health_label = label("", 14)
	stats.add_child(health_label)
	health_bar = make_bar(Color("b75d4f"))
	stats.add_child(health_bar)
	stamina_label = label("", 14)
	stats.add_child(stamina_label)
	stamina_bar = make_bar(Color("afaa70"))
	stats.add_child(stamina_bar)
	inventory_label = label("", 15, Color("d7bd86"))
	inventory_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	inventory_label.position = Vector2(-420, -64)
	inventory_label.size.x = 388
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(inventory_label)
	var controls := label("WASD  Bewegen   ·   Shift  Sprint   ·   Leertaste  Springen\nMaus / 1–4  Richtung   ·   LMB halten / lösen  Angriff   ·   RMB  Block   ·   Q  Finte", 13, Color("bbc0af"))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.position = Vector2(-590, -112)
	controls.size.x = 558
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(controls)
	crosshair = label("+", 24, Color("e4dfcf"))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-9, -17)
	hud.add_child(crosshair)
	var positions := [Vector2(-78, -17), Vector2(-12, -70), Vector2(58, -17), Vector2(-12, 28)]
	for index in range(4):
		var indicator := label(PlayerScript.Combat.ARROWS[index], 26)
		indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		indicator.position = positions[index]
		indicator.add_theme_constant_override("outline_size", 6)
		indicator.add_theme_color_override("font_outline_color", Color("162322"))
		hud.add_child(indicator)
		direction_labels.append(indicator)
	stance_label = label("", 15)
	stance_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stance_label.position = Vector2(-220, 64)
	stance_label.size.x = 440
	stance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stance_label.add_theme_constant_override("outline_size", 5)
	stance_label.add_theme_color_override("font_outline_color", Color("162322"))
	hud.add_child(stance_label)
	combat_label = label("", 23)
	combat_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	combat_label.position = Vector2(-360, -130)
	combat_label.size.x = 720
	combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_label.add_theme_constant_override("outline_size", 7)
	combat_label.add_theme_color_override("font_outline_color", Color("162322"))
	hud.add_child(combat_label)
	prompt_label = label("", 20)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-350, 75)
	prompt_label.size.x = 700
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt_label)
	notice_label = label("", 22, Color("edd099"))
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notice_label.position = Vector2(-400, 138)
	notice_label.size.x = 800
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(notice_label)
	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-345, -310)
	menu.size = Vector2(690, 620)
	menu.add_theme_stylebox_override("panel", panel_style(Color(0.045, 0.07, 0.075, 0.98), Color("95815a")))
	layer.add_child(menu)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 22)
	menu.add_child(menu_box)
	var badge := label("E I N   F A N T A S Y - P R O T O T Y P", 13, Color("d7bd86"))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(badge)
	menu_title = label("", 48, Color("e9d7ae"))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(menu_title)
	menu_copy = label("", 19)
	menu_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(menu_copy)
	play_button = Button.new()
	play_button.custom_minimum_size.y = 55
	play_button.add_theme_font_size_override("font_size", 20)
	play_button.add_theme_stylebox_override("normal", panel_style(Color("655539"), Color("b19b70")))
	play_button.add_theme_stylebox_override("hover", panel_style(Color("89734b"), Color("dcc491")))
	play_button.pressed.connect(start_or_resume)
	menu_box.add_child(play_button)
	lan_button = Button.new()
	lan_button.text = "LAN · Runde eröffnen / beitreten"
	lan_button.pressed.connect(func(): net.open_lobby())
	menu_box.add_child(lan_button)
	var help := label("WASD · Bewegung     Maus · Blick     E · Interaktion\nMaus / 1–4 · Links / Oben / Rechts / Stich\nLinksklick halten / lösen · Angriff   Rechts halten · Block\nQ · Richtungsfinte während des Ausholens\nShift · Sprint     Leertaste · Sprung     J · Tagebuch\n\nEinzelspieler oder LAN PvPvE · ohne Speicherstand", 14, Color("a7b0a5"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(help)
	journal = PanelContainer.new()
	journal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	journal.position = Vector2(-320, -330)
	journal.size = Vector2(640, 460)
	journal.add_theme_stylebox_override("panel", panel_style(Color(0.06, 0.09, 0.09, 0.97)))
	layer.add_child(journal)
	var journal_text := label("REISETAGEBUCH\n\nDer letzte Wächter\n\nFolge dem Pfad nach Norden zur alten Abtei.\nIhre Besatzer tragen Gold; ihr Wächter trägt das Siegel.\nBringe es zum Lagerfeuer zurück.\n\nEine bessere Klinge\n\nSammle zweimal Holz und zweimal Erz am Wegesrand.\nAn der Schmiede neben dem Feuer kannst du deine\nKlinge verstärken. Das Lagerfeuer heilt dich.\n\nIm Kampf\n\nGoldener Pfeil: gegnerische Angriffsrichtung.\nBlocke auf der angezeigten Seite (inklusive Stich).\nMaus / 1–4: Links, Oben, Rechts, Stich.\nLinksklick halten / lösen: Ausholen und Zuschlagen.\nQ beim Ausholen: in neue Richtung fintieren.\nBlau: Gegner blockt. Finten täuschen seinen Block.\nFrische Parade: Gegner taumelt. Deckung kostet Ausdauer.\n\nJ / Esc · Tagebuch schließen", 18)
	journal.add_child(journal_text)
	journal.visible = false

func make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(310, 12)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("26312d")
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func update_stats() -> void:
	health_bar.value = player.health
	stamina_bar.value = player.stamina
	health_label.text = "LEBEN  %d / 100" % int(player.health)
	stamina_label.text = "AUSDAUER  %d / 100" % int(player.stamina)
	inventory_label.text = "Holz %d   ·   Erz %d   ·   Gold %d   ·   Klinge +%d" % [wood, ore, gold, player.weapon_level - 1]
	if victory:
		quest_label.text="✓ Der Pass ist frei.\nErkunde die Grenzlande weiter."
	elif boss_dead:
		quest_label.text = "✓ Siegel des Wächters geborgen\nKehre zum Lagerfeuer zurück."
	else:
		quest_label.text = "Besiege den Ruinenwächter.\nKlinge verbessern: %s" % ("✓" if player.weapon_level > 1 else "%d/2 Holz · %d/2 Erz" % [mini(wood, 2), mini(ore, 2)])

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hud):
		return
	if player.active:
		hit_stop = maxf(0, hit_stop - delta)
		combat_time = maxf(0, combat_time - delta)
	combat_label.visible = combat_time > 0
	for index in range(4):
		direction_labels[index].modulate = (Color("82dcf1") if player.blocking else Color("efbd6f")) if index == player.selected_direction else Color(0.8, 0.85, 0.8, 0.55)
	stance_label.text = ("BLOCK " if player.blocking else ("AUFLADEN %d%% " % int(player.combat.charge()*100) if player.winding else ("ERHOLUNG " if player.cooldown>0 else "RICHTUNG "))) + PlayerScript.Combat.NAMES[player.guard_direction if player.blocking else (player.attack_direction if player.winding else player.selected_direction)]
	hit_flash = maxf(0, hit_flash - delta)
	crosshair.modulate = Color("e8b978") if hit_flash > 0 else Color.WHITE
	damage_overlay.color.a = player.hurt_time * 0.65
	if not player.active:
		return
	rest_cooldown = maxf(0, rest_cooldown - delta)
	message_time = maxf(0, message_time - delta)
	notice_label.visible = message_time > 0
	find_focus()
	var destination := Vector3(0, 0, 7) if boss_dead else Vector3(3, 0, -32)
	var offset := destination - player.position
	var angle := rad_to_deg(wrapf(atan2(-offset.x, -offset.z) - player.rotation.y, -PI, PI))
	var heading := "↑" if absf(angle) < 25 else ("←" if angle > 0 else "→")
	if absf(angle) > 145:
		heading = "↓"
	compass_label.text = "%s  %s  ·  %d m" % [heading, "Lager" if boss_dead else "Ruinen", int(offset.length())]
	location_label.text = "ASCHENMARK  /  " + ("ALTE ABTEI" if player.position.z < -22 else ("WALDPFAD" if player.position.z < 2 else "WANDERERLAGER"))
	if net.running:
		location_label.text += "  ·  LAN %d/8  ·  %s" % [net.actors.size(),"SCHUTZZONE" if net.safe_zone(player.position) else "PvPvE"]

func find_focus() -> void:
	focus = {}
	var nearest := 3.5
	var forward: Vector3 = -player.camera.global_transform.basis.z
	for resource in resources:
		if resource.get("used", false):
			continue
		var distance: float = player.position.distance_to(resource.pos)
		var offset: Vector3 = resource.pos + Vector3(0, 0.6, 0) - player.camera.global_position
		if distance < nearest and forward.dot(offset.normalized()) > 0.48:
			focus = resource
			nearest = distance
	if focus.is_empty():
		prompt_label.text = ""
		return
	match focus.kind:
		"wood": prompt_label.text = "[E]  Holz sammeln  +1"
		"ore": prompt_label.text = "[E]  Erz abbauen  +1"
		"forge": prompt_label.text = "[E]  Klinge verstärken  ·  2 Holz + 2 Erz" if player.weapon_level == 1 else "Klinge bereits verstärkt"
		"fire": prompt_label.text = "[E]  Siegel abgeben" if boss_dead and not victory else "[E]  Am Feuer ausruhen"
		"loot": prompt_label.text = "[E]  Beute bergen  +%d Gold" % focus.amount

func interact() -> void:
	if net.running:
		if net.hosting: net.interact_as(player)
		else: net.command("interact")
		return
	interact_local()

func interact_local() -> void:
	find_focus()
	if focus.is_empty():
		return
	match focus.kind:
		"wood", "ore":
			if focus.kind == "wood": wood += 1
			else: ore += 1
			focus.used = true
			focus.node.visible = false
			notify("+1 Holz" if focus.kind == "wood" else "+1 Erz")
			play_tone(460, 0.08, 0.12)
		"forge":
			if player.weapon_level > 1:
				notify("Deine Klinge ist bereits verstärkt.")
			elif wood >= 2 and ore >= 2:
				wood -= 2
				ore -= 2
				player.weapon_level = 2
				notify("Klinge verstärkt · 45 statt 28 Schaden", 3)
				play_tone(660, 0.2, 0.15)
			else:
				notify("Du brauchst 2 Holz und 2 Erz. Suche am Wegesrand.")
		"fire":
			if boss_dead and not victory:
				victory = true
				show_menu("DER PASS IST FREI", "Das Siegel liegt wieder am Feuer.\nDie Grenzlande gehören den Wanderern.\n\nBesiegte Gegner: %d / 4   ·   Geborgenes Gold: %d\n\nDu kannst weiter erkunden oder mit F5 neu starten." % [kills, gold], "Weiter erkunden")
			elif rest_cooldown > 0:
				notify("Das Feuer wärmt dich. Warte einen Augenblick.")
			else:
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if enemy.alive and enemy.position.distance_to(player.position) < 12:
						notify("Du kannst dich im Kampf nicht ausruhen.")
						return
				player.health = 100
				player.stamina = 100
				rest_cooldown = 8
				notify("Am Feuer erholt · Leben und Ausdauer aufgefüllt")
		"loot":
			gold += focus.amount
			focus.used = true
			focus.node.visible = false
			notify("+%d Gold" % focus.amount)
			play_tone(720, 0.12, 0.12)
	update_stats()
	find_focus()

func enemy_defeated(enemy: Node3D) -> void:
	if is_instance_valid(net) and net.running and not net.hosting: return
	kills += 1
	var bag := cylinder(self, 0.25, 0.17, 0.3, enemy.position + Vector3(0.6, 0.18, 0), brass)
	resources.append({"kind": "loot", "pos": enemy.position + Vector3(0.6, 0, 0), "node": bag, "used": false, "amount": 35 if enemy.boss else 12})
	if enemy.boss:
		boss_dead = true
		notify("Ruinenwächter besiegt · Siegel geborgen! Zurück zum Feuer.", 5)
	else:
		notify("Besatzer besiegt · [E] Beute bergen")
	update_stats()

func notify(text: String, duration := 2.3) -> void:
	notice_label.text = text
	notice_label.visible = true
	message_time = duration

func show_menu(title: String, copy: String, button: String) -> void:
	player.active = false
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_title.text = title
	menu_copy.text = copy
	play_button.text = button
	menu.visible = true
	hud.visible = false
	play_button.grab_focus()

func start_or_resume() -> void:
	if not player.alive:
		if net.running:
			if net.hosting: net.respawn(player)
			else:
				net.command("respawn")
				return
		else:
			get_tree().reload_current_scene()
			return
	menu.visible = false
	journal.visible = false
	hud.visible = true
	paused = false
	player.active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func on_death() -> void:
	if net.running:
		show_menu("IM KAMPF GEFALLEN","Die LAN-Runde läuft weiter.
Du kannst am Lager neu einsteigen.
Deine Ausrüstung und Rohstoffe bleiben erhalten.","Am Lager neu einsteigen")
		return
	show_menu("IM STAUB GEFALLEN", "Die Grenzlande vergeben keine Unachtsamkeit.\n\nBlocke, wenn der Gegner zum Schlag ausholt.\nAm Lagerfeuer kannst du dich erholen.\nEine verstärkte Klinge macht den Unterschied.", "Neuer Versuch")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			if not net.running: get_tree().reload_current_scene()
			else: notify("LAN: Zum Verlassen die LAN-Liste öffnen.")
		elif event.keycode == KEY_ESCAPE:
			if journal.visible:
				start_or_resume()
			elif player.active:
				show_menu("RAST", "Die Grenzlande warten.\n\nErkunde den Wald, sammle Vorräte\nund stelle dich dem Wächter der alten Abtei.", "Zurück ins Spiel")
			elif player.alive:
				start_or_resume()
		elif event.is_action_pressed("journal") and player.alive and not menu.visible:
			journal.visible = not journal.visible
			player.active = not journal.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if journal.visible else Input.MOUSE_MODE_CAPTURED

func clear_line(from: Vector3, to: Vector3, exclude: Array) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var excluded_rids: Array[RID] = []
	excluded_rids.assign(exclude)
	query.exclude = excluded_rids
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func sword_sound() -> void:
	combat_sound("whoosh")

func play_tone(frequency: float, duration: float, volume: float) -> void:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var count := int(duration * sound.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var envelope := sin(PI * float(i) / count) * (1.0 - float(i) / count)
		var value := int(sin(TAU * frequency * i / sound.mix_rate) * envelope * volume * 32767)
		bytes.encode_s16(i * 2, value)
	sound.data = bytes
	var audio := AudioStreamPlayer.new()
	audio.stream = sound
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func combat_feedback(text: String, kind: String) -> void:
	combat_label.text = text
	combat_time = 1.0
	var color := Color("d7cbb0")
	if kind in ["block", "parry"]:
		color = Color("82dcf1")
		hit_stop = 0.055
		combat_sound("metal")
	elif kind == "hit":
		color = Color("f3b06f")
		hit_flash = 0.24
		hit_stop = 0.045
		combat_sound("hit")
	elif kind == "hurt":
		color = Color("ff8270")
		hit_stop = 0.045
		combat_sound("hurt")
	elif kind == "feint":
		combat_sound("feint")
	combat_label.modulate = color

func impact(pos: Vector3, metal: bool) -> void:
	var mat := material(Color("ffcf6f") if metal else Color("c96345"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(9):
		var spark := box(self, Vector3(0.025, 0.025, 0.12) if metal else Vector3.ONE * 0.05, pos, mat)
		var direction := Vector3(sin(i * 2.4), 0.3 + cos(i * 1.2), cos(i * 2.4))
		var tween := spark.create_tween()
		tween.tween_property(spark, "position", pos + direction * 0.6, 0.22)
		tween.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.22)
		tween.tween_callback(spark.queue_free)

func combat_sound(kind: String) -> void:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var duration := 0.23 if kind == "metal" else 0.14
	var count := int(duration * sound.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / sound.mix_rate
		var noise := fmod(sin(float(i) * 78.233) * 43758.5453, 1.0)
		var value := noise * exp(-t * 38) * 0.3
		if kind == "metal":
			value += (sin(t * TAU * 1230) + sin(t * TAU * 2173) * 0.5) * exp(-t * 18) * 0.22
		elif kind in ["hit", "hurt"]:
			value += sin(t * TAU * (110 - t * 250)) * exp(-t * 25) * 0.45
		else:
			value *= 0.8 if kind == "whoosh" else 0.25
		bytes.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	sound.data = bytes
	var audio := AudioStreamPlayer.new()
	audio.stream = sound
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
