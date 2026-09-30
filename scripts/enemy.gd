extends CharacterBody3D

const Combat = preload("res://scripts/combat.gd")

var world: Node3D
var health := 85.0
var alive := true
var boss := false
var home := Vector3.ZERO
var cooldown := 1.0
var windup := 0.0
var attacking := false
var flash := 0.0
var body: Node3D
var blade: Node3D
var marker: MeshInstance3D
var bar: MeshInstance3D
var direction_label: Label3D
var attack_direction := Combat.Direction.TOP
var guard_direction := Combat.Direction.TOP
var blocking := false
var stamina := 80.0
var guard_lock := 0.0
var reaction := 0.0
var stagger := 0.0
var swing_time := 0.0
var attack_elapsed := 0.0
var will_feint := false
var feinted := false
var feint_gap := 0.0
var ai_enabled := true
var flash_material: StandardMaterial3D
var knockback := Vector3.ZERO
var legs: Array[Node3D] = []
var rig: Dictionary = {}
var target_player: CharacterBody3D

func _ready() -> void:
	world = get_parent()
	home = position
	add_to_group("enemies")
	health = 180 if boss else 85
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	collider.shape = capsule
	collider.position.y = 0.95
	add_child(collider)
	body = Node3D.new()
	add_child(body)
	rig = world.art.knight(body,boss)
	legs.assign(rig.legs)
	blade = Node3D.new()
	blade.position = Vector3(0.47, 0.85, -0.25)
	body.add_child(blade)
	world.art.sword(blade,false)
	marker = world.box(self, Vector3(0.2, 0.2, 0.2), Vector3(0, 2.35, 0), world.warning_mat)
	marker.rotation.z = PI / 4
	marker.scale = Vector3.ONE * 0.45
	marker.visible = false
	bar = world.box(self, Vector3(0.85, 0.065, 0.025), Vector3(0, 2.1, 0), world.health_mat)
	bar.visible = false
	direction_label = Label3D.new()
	direction_label.position = Vector3(0, 2.65, 0)
	direction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	direction_label.font_size = 30
	direction_label.pixel_size = 0.0035
	direction_label.outline_size = 5
	add_child(direction_label)
	flash_material = world.material(Color("edc5a0"))
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if boss:
		body.scale = Vector3.ONE * 1.12

func _physics_process(delta: float) -> void:
	if not alive or not ai_enabled or (world.hit_stop>0 and not world.net.running):
		return
	var player: CharacterBody3D = world.player
	var nearest := INF
	for candidate in world.net.combatants():
		if candidate.alive and (candidate.active or world.net.running) and position.distance_to(candidate.position)<nearest:
			player=candidate
			nearest=position.distance_to(candidate.position)
	if nearest==INF: return
	target_player=player
	var offset := player.global_position - global_position
	var distance := offset.length()
	cooldown = maxf(0, cooldown - delta)
	stagger = maxf(0, stagger - delta)
	guard_lock = maxf(0, guard_lock - delta)
	swing_time = maxf(0, swing_time - delta)
	flash = maxf(0, flash - delta)
	stamina = minf(80, stamina + delta * 14)
	bar.visible = distance < 13
	bar.look_at(player.camera.global_position, Vector3.UP)
	for mesh in body.get_children():
		if mesh is MeshInstance3D:
			mesh.material_overlay = flash_material if flash > 0 else null
	if not is_on_floor():
		velocity.y -= delta * 22
	velocity.x = 0
	velocity.z = 0
	blocking = false
	if distance < (17 if boss else 13):
		if distance > 0.1 and not attacking and swing_time == 0:
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		if stagger > 0:
			attacking = false
		elif attacking:
			update_attack(delta, distance)
		elif swing_time > 0:
			pass
		elif guard_lock > 0 and stamina >= 15:
			blocking = true
		elif player.winding and distance < 3.8 and stamina >= 15:
			reaction += delta
			if reaction >= (0.18 if boss else 0.24):
				guard_direction = Combat.incoming(player.attack_direction) if world.rng.randf() < (0.9 if boss else 0.75) else world.rng.randi_range(0, 3)
				guard_lock = 0.8
				blocking = true
		elif distance > 2.1:
			reaction = 0
			var direction := offset.normalized()
			velocity.x = direction.x * (2.6 if boss else 2.2)
			velocity.z = direction.z * (2.6 if boss else 2.2)
		elif cooldown == 0 and stamina >= 20:
			reaction = 0
			begin_attack()
	else:
		attacking = false
		guard_lock = 0
		var offset_home := home - global_position
		if offset_home.length() > 0.7:
			velocity.x = offset_home.normalized().x * 1.5
			velocity.z = offset_home.normalized().z * 1.5
	velocity += knockback
	move_and_slide()
	knockback = knockback.move_toward(Vector3.ZERO, delta * 16)
	body.position.y = sin(Time.get_ticks_msec() * 0.008) * 0.025 if velocity.length() > 0.5 else 0.0
	for i in legs.size():
		legs[i].rotation.x = sin(Time.get_ticks_msec()*0.008+i*PI)*0.38 if velocity.length()>0.5 else lerpf(legs[i].rotation.x,0,delta*8)
	body.rotation.z = sin(flash * 15) * 0.15
	marker.visible = attacking and feint_gap == 0
	direction_label.visible = distance < 15 and (attacking or blocking)
	if attacking:
		var incoming := Combat.incoming(attack_direction)
		direction_label.text = "FINTE" if feint_gap > 0 else Combat.ARROWS[incoming] + " " + Combat.NAMES[incoming]
		direction_label.modulate = Color("efbc6d")
		blade.rotation = blade.rotation.lerp(Combat.pose(attack_direction), minf(1, delta * 14))
	elif blocking:
		direction_label.text = "BLOCK " + Combat.NAMES[Combat.incoming(guard_direction)]
		direction_label.modulate = Color("80cee3")
		blade.rotation = blade.rotation.lerp(Combat.pose(guard_direction, true), minf(1, delta * 16))
	elif swing_time > 0:
		blade.rotation = Combat.pose(attack_direction).lerp(Vector3(1.1, 0, 0.8), 1.0 - swing_time / 0.3)
		if attack_direction == Combat.Direction.THRUST:
			blade.rotation = Combat.pose(attack_direction)
	var blade_pos := Vector3(0.47, 0.85, -0.25)
	if attacking or swing_time > 0:
		blade_pos = Vector3(-0.5 if attack_direction == 0 else 0.5, 1.85 if attack_direction == 1 else 1.15, -0.25)
		if attack_direction == 1 and swing_time > 0:
			blade_pos.y -= (1.0 - swing_time / 0.3) * 0.9
	elif blocking:
		blade_pos = Vector3(-0.45 if guard_direction == 0 else (0.45 if guard_direction == 2 else 0.0), 1.95 if guard_direction == 1 else 1.15, -0.4)
	blade.position = blade.position.lerp(blade_pos, minf(1, delta * 16))
	blade.position.z = -0.25 - (sin((1.0 - swing_time / 0.3) * PI) * 0.6 if swing_time > 0 and attack_direction == Combat.Direction.THRUST else 0.0)
	if not attacking and not blocking and swing_time == 0:
		blade.rotation = blade.rotation.lerp(Vector3.ZERO, minf(1, delta * 8))

	world.art.animate_arm(rig,blade)

func begin_attack() -> void:
	attacking = true
	stamina -= 20
	attack_direction = world.rng.randi_range(0, 3)
	windup = 0.72 if boss else 0.9
	attack_elapsed = 0
	feinted = false
	feint_gap = 0
	will_feint = stamina >= 8 and world.rng.randf() < (0.4 if boss else 0.2)

func update_attack(delta: float, distance: float) -> void:
	attack_elapsed += delta
	if feint_gap > 0:
		feint_gap = maxf(0, feint_gap - delta)
		return
	windup -= delta
	if will_feint and not feinted and attack_elapsed >= 0.3:
		feinted = true
		stamina -= 8
		attack_direction = (attack_direction + world.rng.randi_range(1, 3)) % 4
		windup = 0.52
		feint_gap = 0.16
		return
	if windup <= 0:
		attacking = false
		swing_time = 0.3
		cooldown = 1.1 if boss else 1.45
		world.sword_sound()
		var facing := -global_transform.basis.z
		var offset: Vector3 = (target_player if is_instance_valid(target_player) else world.player).global_position - global_position
		if distance < 2.8 and facing.dot(offset.normalized()) > 0.45 and world.clear_line(global_position + Vector3.UP, (target_player if is_instance_valid(target_player) else world.player).global_position + Vector3.UP, [get_rid(), (target_player if is_instance_valid(target_player) else world.player).get_rid()]):
			(target_player if is_instance_valid(target_player) else world.player).take_damage(26 if boss else 17, global_position, Combat.incoming(attack_direction))

func receive_attack(amount: float, direction: int, source: Vector3, attacker: Node3D = null) -> bool:
	if attacker==null: attacker=world.player
	if not alive:
		return false
	var toward := (source - global_position).normalized()
	if blocking and guard_direction == Combat.incoming(direction) and stamina >= 15 and (-global_transform.basis.z).dot(toward) > 0.2:
		stamina -= 15
		attacker.recoil = 1.0
		attacker.shake = 0.4
		attacker.cooldown = maxf(attacker.cooldown, 0.58)
		attacker.feedback("GEGNER BLOCKT · Finte + Richtungswechsel", "block")
		world.impact(global_position + Vector3(0, 1.3, 0), true)
		return false
	take_damage(amount)
	knockback = -toward * 2.5
	attacker.shake = 0.35
	attacker.feedback("TREFFER · %d" % int(amount), "hit")
	world.impact(global_position + Vector3(0, 1.2, 0), false)
	return true

func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	flash = 0.2
	stagger = 0.3
	attacking = false
	blocking = false
	guard_lock = 0
	cooldown = maxf(cooldown, 0.5)
	bar.scale.x = maxf(0.01, health / (180.0 if boss else 85.0))
	if health <= 0:
		alive = false
		for mesh in body.get_children():
			if mesh is MeshInstance3D:
				mesh.material_overlay = null
		marker.visible = false
		direction_label.visible = false
		bar.visible = false
		collision_layer = 0
		collision_mask = 0
		var tween := create_tween()
		tween.tween_property(body, "rotation:x", -PI / 2, 0.35)
		tween.parallel().tween_property(body, "position:y", 0.15, 0.35)
		world.enemy_defeated(self)
