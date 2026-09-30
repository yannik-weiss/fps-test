extends CharacterBody3D

const Combat = preload("res://scripts/combat.gd")

signal stats_changed

const Fighter = preload("res://scripts/fighter.gd")
var combat
var _health := 100.0
var _stamina := 100.0
var health: float:
	get: return combat.health if is_instance_valid(combat) else _health
	set(value):
		_health=value
		if is_instance_valid(combat): combat.health=value
var stamina: float:
	get: return combat.stamina if is_instance_valid(combat) else _stamina
	set(value):
		_stamina=value
		if is_instance_valid(combat): combat.stamina=value
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
var weapon_hand: MeshInstance3D
var weapon_forearm: MeshInstance3D
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
var input_queue: Array[PackedFloat64Array] = []
var last_input_received := 0
var last_input_processed := 0
var camera_correction := Vector3.ZERO
var motion_credit := 0.0
var pending_look := Vector2.ZERO
var aim_travel := Vector2.ZERO
var block_held := false
var net_blade_pos := Vector3(0.3,-0.35,-0.45)
var net_blade_rot := Vector3(-PI/18,0,0)
var net_pitch := 0.0
var avatar: Node3D
var avatar_sword: Node3D
var avatar_rig: Dictionary
var nameplate: Label3D

func _ready() -> void:
	world = get_parent()
	collision_layer=2
	collision_mask=3
	var shape := CollisionShape3D.new()
	shape.name="CollisionShape3D"
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
	if local_control:
		weapon_hand=world.art.ellipsoid(camera,Vector3.ZERO,Vector3(0.055,0.045,0.055),world.leather)
		weapon_forearm=world.art.limb(camera,Vector3(0.42,-0.52,0.04),Vector3(0.3,-0.35,-0.45),0.042,world.leather)
		weapon_hand.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weapon_forearm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	combat=Fighter.new()
	combat.name="MeleeCombat"
	combat.profile=preload("res://combat/sword_profile.tres")
	combat.weapon=sword
	combat.hitbox_scale=2.5
	combat.base_damage=28
	add_child(combat)
	combat.swing_started.connect(func(_dir):
		world.sword_sound()
		if local_control: recoil=0.2)
	stats_changed.emit()

func _process(delta: float) -> void:
	if local_control:
		apply_look(delta)
		if is_instance_valid(weapon_hand):
			var grip: Vector3=sword.transform*Vector3(0,-0.02,0)
			weapon_hand.position=grip
			weapon_hand.rotation=sword.rotation
			world.art.update_limb(weapon_forearm,Vector3(0.42,-0.52,0.04),grip)
		return
	if not is_instance_valid(avatar): return
	avatar.visible = alive
	avatar.position=avatar.position.lerp(Vector3.ZERO,1-exp(-delta*20))
	avatar.rotation.y=lerp_angle(avatar.rotation.y,0,1-exp(-delta*20))
	nameplate.text = display_name + (" · BLOCK " + Combat.NAMES[Combat.incoming(guard_direction)] if blocking else "")
	if world.net.running and not world.net.hosting:
		var blend := 1-exp(-delta*20)
		sword.position=sword.position.lerp(net_blade_pos,blend)
		sword.rotation=sword.rotation.lerp(net_blade_rot,blend)
		camera.rotation.x=lerpf(camera.rotation.x,net_pitch,blend)
	avatar_sword.transform=camera.transform*sword.transform
	avatar_sword.scale*=Vector3(1,combat.hitbox_scale,1)
	world.art.animate_arm(avatar_rig,avatar_sword)

func feedback(text: String, kind: String) -> void:
	if local_control: world.combat_feedback(text,kind)
	elif world.net.running and world.net.hosting: world.net.receive_feedback.rpc_id(peer_id,text,kind)

func _unhandled_input(event: InputEvent) -> void:
	if not local_control or not active or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		aim_travel+=event.relative
		if aim_travel.length()>6:
			if absf(aim_travel.y)>absf(aim_travel.x): select_direction(1 if aim_travel.y<0 else 3)
			else: select_direction(0 if aim_travel.x<0 else 2)
			aim_travel=Vector2.ZERO
		pending_look+=event.relative*0.0024
	for index in range(4):
		if event.is_action_pressed("direction_%d" % index):
			select_direction(index)
	if event.is_action_pressed("attack"):
		attack(true)
	if event.is_action_released("attack"):
		combat.queue_release()
		world.net.command("release")
	if event.is_action_pressed("feint"):
		feint()
	if event.is_action_pressed("block"):
		block_held=true
		combat.queue_block(Combat.to_melee(selected_direction))
		world.net.command("block",selected_direction)
	if event.is_action_released("block"):
		block_held=false
		combat.queue_block_release()
		world.net.command("unblock")
	if event.is_action_pressed("interact"):
		world.interact()

func select_direction(direction: int) -> void:
	selected_direction = direction
	if not blocking: guard_direction = direction
	if is_instance_valid(combat):
		combat.update_queued_dir(Combat.to_melee(direction))
		combat.aim_guard(Combat.to_melee(direction))

func _physics_process(delta: float) -> void:
	if not active or not alive:
		return
	if not local_control and not world.net.hosting: return
	var simulate_motion := true
	var frame_sequence := 0
	if not local_control:
		# Save elapsed simulation time while a packet is in transit. Catch up only
		# this earned time, so packet jitter cannot create a permanent input queue
		# and sending extra commands cannot make a player run faster.
		motion_credit=minf(0.15,motion_credit+delta)
		if last_input_received>0:
			simulate_motion=not input_queue.is_empty()
			if simulate_motion: frame_sequence=apply_input_frame(input_queue.pop_front())
	input_age += delta
	if not local_control and input_age>0.3:
		net_move=Vector2.ZERO
		net_block=false
		net_sprint=false
		combat.hold_guard(false,Combat.to_melee(selected_direction))
		block_held=false
	if world.hit_stop > 0 and local_control and not world.net.running:
		return
	stagger = maxf(0, stagger - delta)
	recoil = maxf(0, recoil - delta * 4)
	shake = maxf(0, shake - delta * 2)
	hurt_time=maxf(0,hurt_time-delta)
	combat.base_damage=28 if weapon_level==1 else 45
	if local_control:
		var held := Input.is_action_pressed("block")
		if held and not block_held: combat.queue_block(Combat.to_melee(selected_direction))
		elif not held and block_held: combat.queue_block_release()
		block_held=held
		combat.hold_guard(held,Combat.to_melee(selected_direction))
	combat.step(delta)
	var input := Input.get_vector("left", "right", "forward", "back") if local_control else net_move
	var running := (Input.is_action_pressed("sprint") if local_control else net_sprint) and input.length()>0 and stamina>4 and not blocking
	var jump := Input.is_action_just_pressed("jump") if local_control else net_jump
	if simulate_motion:
		simulate_movement(input,running,jump,delta)
		if not local_control:
			motion_credit=maxf(0,motion_credit-delta)
			if frame_sequence>0: last_input_processed=frame_sequence
			while not input_queue.is_empty() and motion_credit>=delta:
				last_input_processed=apply_input_frame(input_queue.pop_front())
				input=net_move
				running=net_sprint and input.length()>0 and stamina>4 and not blocking
				simulate_movement(input,running,net_jump,delta)
				motion_credit-=delta
	if local_control:
		world.net.record_prediction(input,jump)
	camera_correction=camera_correction.lerp(Vector3.ZERO,1-exp(-delta*18))
	step_time += delta * (11 if running else 7) * input.length()
	camera.position = Vector3(sin(Time.get_ticks_msec() * 0.07) * shake * 0.035, 1.6 + sin(step_time) * 0.035 * input.length() + cos(Time.get_ticks_msec() * 0.09) * shake * 0.025, 0)
	camera.position += basis.inverse()*camera_correction
	camera.fov = lerpf(camera.fov, 80 if running else 78, delta * 6)
	camera.rotation.z=lerpf(camera.rotation.z,deg_to_rad(combat.profile.swing_camera_roll)*( -1 if attack_direction==0 else 1) if combat.state==MeleeCombat.State.SWING else 0.0,delta*12)
	stats_changed.emit()

func apply_look(delta: float) -> void:
	var look := pending_look
	pending_look=Vector2.ZERO
	var cap: float = combat.turn_cap() if is_instance_valid(combat) else 0.0
	if cap>0: look=look.clamp(Vector2.ONE*-cap*delta,Vector2.ONE*cap*delta)
	rotate_y(-look.x)
	camera.rotation.x=clampf(camera.rotation.x-look.y,-1.25,1.25)

func apply_input_frame(frame: PackedFloat64Array) -> int:
	net_move=Vector2(frame[1],frame[2]).limit_length(1)
	var cap: float = combat.turn_cap()
	rotation.y=rotate_toward(rotation.y,wrapf(frame[3],-PI,PI),cap/Engine.physics_ticks_per_second) if cap>0 else wrapf(frame[3],-PI,PI)
	var target_pitch := clampf(frame[4],-1.25,1.25)
	camera.rotation.x=rotate_toward(camera.rotation.x,target_pitch,cap/Engine.physics_ticks_per_second) if cap>0 else target_pitch
	select_direction(clampi(int(frame[5]),0,3))
	var flags := int(frame[6])
	net_block=bool(flags&1)
	if net_block and not block_held: combat.queue_block(Combat.to_melee(selected_direction))
	elif not net_block and block_held: combat.queue_block_release()
	block_held=net_block
	combat.hold_guard(net_block,Combat.to_melee(selected_direction))
	net_sprint=bool(flags&2)
	net_jump=bool(flags&4)
	return int(frame[0])

func simulate_movement(input: Vector2, running: bool, jump: bool, delta: float) -> void:
	var direction := (transform.basis*Vector3(input.x,0,input.y)).normalized()
	var speed: float = (7.5 if running and combat.state==MeleeCombat.State.IDLE else 4.4)*combat.move_multiplier()
	velocity.x=move_toward(velocity.x,direction.x*speed+knockback.x,delta*30)
	velocity.z=move_toward(velocity.z,direction.z*speed+knockback.z,delta*30)
	if not is_on_floor(): velocity.y-=22*delta
	elif jump and stamina>=12:
		velocity.y=7
		stamina-=12
	net_jump=false
	if running: stamina=maxf(0,stamina-17*delta)
	move_and_slide()
	knockback=knockback.move_toward(Vector3.ZERO,delta*18)

func attack(held := false) -> void:
	if not active or not alive: return
	if local_control: world.net.command("attack",selected_direction)
	combat.queue_windup(Combat.to_melee(selected_direction))
	if not held: combat.queue_release()
	combat.sync_view()

func feint() -> bool:
	var direction := Combat.to_melee(selected_direction)
	if direction==combat.feint_base_dir(): direction=MeleeCombat.next_dir(direction)
	var changed: bool = combat.feint_or_redirect(direction)
	if changed:
		if local_control: world.net.command("feint",Combat.from_melee(direction))
		feedback("RICHTUNGSFINTE","feint")
		combat.sync_view()
	return changed

func take_damage(amount: float, source: Vector3, incoming_direction := Combat.Direction.TOP) -> void:
	# Environmental/debug damage; sword attacks go through the shared combat core.
	if not alive: return
	var toward := (source-position).normalized()
	if blocking and (-basis.z).dot(toward)>0.2 and guard_direction==incoming_direction:
		if block_age<combat.profile.parry_window:
			feedback("PERFEKTE PARADE","parry")
			return
		var cost: float = amount*combat.profile.block_cost_ratio
		stamina=maxf(0,stamina-cost)
		if stamina>0:
			feedback("BLOCK","block")
			return
		amount*=0.5
	combat._take_damage(amount)
	if alive: combat._stagger(combat.profile.flinch_time)
	hurt_time=0.5
	feedback("GETROFFEN","hurt")
	combat.sync_view()

func combat_death() -> void:
	if not alive: return
	alive=false
	collision_layer=0
	collision_mask=0
	if local_control: world.on_death()
