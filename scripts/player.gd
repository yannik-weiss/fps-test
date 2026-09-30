extends CharacterBody3D

const Combat = preload("res://scripts/combat.gd")

signal stats_changed

var health := 100.0
var stamina := 100.0
var weapon_level := 1
var alive := true
var active := false
var blocking := false
var cooldown := 0.0
var swing_time := 0.0
var hurt_time := 0.0
var step_time := 0.0
var camera: Camera3D
var sword: Node3D
var world: Node3D
var attack_direction := Combat.Direction.TOP
var selected_direction := Combat.Direction.TOP
var guard_direction := Combat.Direction.TOP
var winding := false
var windup := 0.0
var release_requested := false
var stagger := 0.0
var recoil := 0.0
var shake := 0.0
var block_age := 1.0
var knockback := Vector3.ZERO
var local_control := true
var peer_id := 1
var display_name := "Wanderer"
var wood := 0
var ore := 0
var gold := 0
var net_move := Vector2.ZERO
var net_block := false
var net_sprint := false
var net_jump := false
var input_age := 0.0
var avatar: Node3D
var avatar_sword: Node3D
var avatar_rig: Dictionary
var nameplate: Label3D

func _ready() -> void:
	world = get_parent()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 78
	camera.far = 260
	add_child(camera)
	sword = Node3D.new()
	camera.add_child(sword)
	sword.scale = Vector3.ONE * 0.8
	world.art.sword(sword)
	sword.position = Vector3(0.42, -0.31, -0.65)
	sword.rotation = Vector3(-0.25, 0, -0.22)
	if not local_control:
		camera.current = false
		sword.hide()
		avatar = Node3D.new()
		add_child(avatar)
		avatar_rig = world.art.knight(avatar,false)
		avatar_sword = Node3D.new()
		avatar.add_child(avatar_sword)
		world.art.sword(avatar_sword,false)
		nameplate = Label3D.new()
		nameplate.position.y = 2.4
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font_size = 26
		nameplate.pixel_size = 0.003
		add_child(nameplate)
	stats_changed.emit()

func _process(delta: float) -> void:
	if local_control or not is_instance_valid(avatar): return
	avatar.visible = alive
	avatar.position=avatar.position.lerp(Vector3.ZERO,minf(1,delta*16))
	nameplate.text = display_name + (" · BLOCK " + Combat.NAMES[Combat.incoming(guard_direction)] if blocking else "")
	avatar_sword.position = Vector3(0.43,1.9 if (winding and attack_direction==1) or (blocking and guard_direction==1) else 1.05,-0.25)
	var pose := Combat.pose(guard_direction,true) if blocking else (Combat.pose(attack_direction) if winding else Vector3.ZERO)
	if swing_time>0: pose=Combat.pose(attack_direction).lerp(Vector3(1.1,0,0.8),1-swing_time/0.3)
	avatar_sword.rotation=avatar_sword.rotation.lerp(pose,minf(1,delta*16))
	world.art.animate_arm(avatar_rig,avatar_sword)

func feedback(text: String, kind: String) -> void:
	if local_control: world.combat_feedback(text,kind)
	elif world.net.running and world.net.hosting: world.net.receive_feedback.rpc_id(peer_id,text,kind)

func _unhandled_input(event: InputEvent) -> void:
	if not local_control or not active or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.relative.length() > 3:
			if absf(event.relative.y) > absf(event.relative.x) and event.relative.y < -3:
				select_direction(Combat.Direction.TOP)
			elif event.relative.y > 3 and absf(event.relative.y) > absf(event.relative.x):
				select_direction(Combat.Direction.THRUST)
			elif absf(event.relative.x) > absf(event.relative.y):
				select_direction(Combat.Direction.LEFT if event.relative.x < 0 else Combat.Direction.RIGHT)
		var sensitivity := 0.0009 if Input.is_action_pressed("block") else 0.0024
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.25, 1.25)
	for index in range(4):
		if event.is_action_pressed("direction_%d" % index):
			select_direction(index)
	if event.is_action_pressed("attack"):
		attack(true)
	if event.is_action_released("attack"):
		release_requested = true
		world.net.command("release")
	if event.is_action_pressed("feint"):
		feint()
	if event.is_action_pressed("jump") and world.net.running and not world.net.hosting:
		world.net.pending_jump=true
	if event.is_action_pressed("interact"):
		world.interact()

func select_direction(direction: int) -> void:
	selected_direction = direction
	guard_direction = direction

func _physics_process(delta: float) -> void:
	if not active or not alive:
		return
	if not local_control and not world.net.hosting: return
	input_age += delta
	if not local_control and input_age>0.3:
		net_move=Vector2.ZERO
		net_block=false
		net_sprint=false
	if world.hit_stop > 0 and local_control and not world.net.running:
		return
	stagger = maxf(0, stagger - delta)
	recoil = maxf(0, recoil - delta * 4)
	shake = maxf(0, shake - delta * 2)
	if winding:
		windup += delta
		if (release_requested and windup >= 0.34) or windup >= 0.8:
			commit_attack()
	cooldown = maxf(0, cooldown - delta)
	swing_time = maxf(0, swing_time - delta)
	hurt_time = maxf(0, hurt_time - delta)
	var was_blocking := blocking
	blocking = (Input.is_action_pressed("block") if local_control else net_block) and not winding and swing_time == 0 and stamina >= 15 and stagger == 0
	block_age = block_age + delta if blocking and was_blocking else 0.0
	var input := Input.get_vector("left", "right", "forward", "back") if local_control else net_move
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var running := (Input.is_action_pressed("sprint") if local_control else net_sprint) and input.length() > 0 and stamina > 4 and not blocking
	var speed := 7.5 if running else 4.4
	if blocking:
		speed = 2.2
	velocity.x = move_toward(velocity.x, direction.x * speed + knockback.x, delta * 30)
	velocity.z = move_toward(velocity.z, direction.z * speed + knockback.z, delta * 30)
	if not is_on_floor():
		velocity.y -= 22 * delta
	elif (Input.is_action_just_pressed("jump") if local_control else net_jump) and stamina >= 12:
		velocity.y = 7
		stamina -= 12
	net_jump=false
	if running:
		stamina = maxf(0, stamina - 17 * delta)
	elif cooldown == 0 and not winding:
		stamina = minf(100, stamina + (10 if blocking else 23) * delta)
	move_and_slide()
	knockback = knockback.move_toward(Vector3.ZERO, delta * 18)
	step_time += delta * (11 if running else 7) * input.length()
	camera.position = Vector3(sin(Time.get_ticks_msec() * 0.07) * shake * 0.035, 1.6 + sin(step_time) * 0.035 * input.length() + cos(Time.get_ticks_msec() * 0.09) * shake * 0.025, 0)
	camera.fov = lerpf(camera.fov, 80 if running else 78, delta * 6)
	var target_pos := Vector3(0.42, -0.31, -0.65)
	var target_rot := Vector3(-0.25, 0, -0.22)
	if blocking:
		target_pos = Vector3(-0.2 if guard_direction == 0 else (0.2 if guard_direction == 2 else 0.0), 0.18 if guard_direction == 1 else -0.1, -0.5 + recoil * 0.12)
		target_rot = Combat.pose(guard_direction, true)
	elif winding:
		target_pos = Vector3(-0.25 if attack_direction == 0 else 0.4, 0.42 if attack_direction == 1 else -0.1, -0.55)
		target_rot = Combat.pose(attack_direction)
	elif swing_time > 0:
		var progress := 1.0 - swing_time / 0.3
		target_rot = Combat.pose(attack_direction).lerp(Vector3(1.1, 0, 0.9 if attack_direction == 2 else -0.9), progress)
		target_pos = Vector3(lerpf(-0.25 if attack_direction == 0 else 0.4, 0.4 if attack_direction == 0 else -0.25, progress), -0.2, -0.8)
		if attack_direction == Combat.Direction.THRUST:
			target_rot = Combat.pose(attack_direction)
			target_pos = Vector3(0.1, -0.17, -0.5 - sin(progress * PI) * 0.65)
	target_rot.x += recoil * 0.4
	sword.position = sword.position.lerp(target_pos, minf(1, delta * 18))
	sword.rotation = sword.rotation.lerp(target_rot, minf(1, delta * 20))
	stats_changed.emit()

func attack(held := false) -> void:
	if not active or not alive or cooldown > 0 or stamina < 20 or blocking or winding or stagger > 0:
		return
	if local_control: world.net.command("attack",selected_direction)
	stamina -= 20
	attack_direction = selected_direction
	winding = true
	windup = 0.0
	release_requested = not held
	stats_changed.emit()

func feint() -> bool:
	if not winding or windup >= 0.65 or stamina < 8:
		return false
	if local_control: world.net.command("feint")
	winding = false
	stamina -= 8
	cooldown = 0.16
	recoil = 0.4
	feedback("FINTE · Richtung wechseln", "feint")
	return true

func commit_attack() -> void:
	winding = false
	cooldown = 0.48
	swing_time = 0.3
	if local_control: world.sword_sound()
	if world.net.running:
		if world.net.hosting: world.net.resolve_attack(self)
		return
	var forward := -camera.global_transform.basis.z
	var target: Node3D = null
	var nearest := 3.5 if attack_direction == Combat.Direction.THRUST else 3.1
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.alive:
			continue
		var offset: Vector3 = enemy.global_position + Vector3(0, 1.0, 0) - camera.global_position
		var distance := offset.length()
		if distance < nearest and forward.dot(offset.normalized()) > (0.86 if attack_direction == Combat.Direction.THRUST else 0.64) and world.clear_line(camera.global_position, enemy.global_position + Vector3.UP, [get_rid(), enemy.get_rid()]):
			nearest = distance
			target = enemy
	if target:
		target.receive_attack(28.0 if weapon_level == 1 else 45.0, attack_direction, global_position)
	else:
		feedback("VERFEHLT", "miss")
	stats_changed.emit()

func take_damage(amount: float, source: Vector3, incoming_direction := Combat.Direction.TOP) -> void:
	if not alive:
		return
	var toward := (source - global_position).normalized()
	var frontal := (-global_transform.basis.z).dot(toward) > 0.2
	if blocking and frontal and guard_direction == incoming_direction and stamina >= 15:
		var parry := block_age < 0.2
		stamina -= 8 if parry else 15
		recoil = 1.0
		shake = 0.45
		feedback("PERFEKTE PARADE" if parry else "BLOCK · " + Combat.NAMES[incoming_direction], "parry" if parry else "block")
		world.impact(camera.global_position - camera.global_transform.basis.z * 0.7, true)
		stats_changed.emit()
		return
	health = maxf(0, health - amount)
	hurt_time = 0.5
	shake = 1.0
	recoil = 0.8
	knockback = -toward * 2
	stagger = 0.18
	winding = false
	cooldown = maxf(cooldown, 0.3)
	feedback(("FALSCHE BLOCKRICHTUNG" if blocking and frontal else "GETROFFEN") + " · −%d" % int(amount), "hurt")
	if health <= 0:
		alive = false
		collision_layer=0
		collision_mask=0
		if local_control: world.on_death()
	stats_changed.emit()
