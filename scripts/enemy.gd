extends CharacterBody3D

const Combat = preload("res://scripts/combat.gd")

var world: Node3D
const Fighter = preload("res://scripts/fighter.gd")
var combat
var _health := 85.0
var health: float:
	get: return combat.health if is_instance_valid(combat) else _health
	set(value):
		_health=value
		if is_instance_valid(combat): combat.health=value
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
var _stamina := 80.0
var stamina: float:
	get: return combat.stamina if is_instance_valid(combat) else _stamina
	set(value):
		_stamina=value
		if is_instance_valid(combat): combat.stamina=value
var guard_lock := 0.0
var reaction := 0.0
var stagger := 0.0
var swing_time := 0.0
var attack_elapsed := 0.0
var will_feint := false
var feinted := false
var feint_gap := 0.0
var ai_enabled := true
var net_blade_pos := Vector3(0.47,0.85,-0.25)
var net_blade_rot := Vector3.ZERO
var flash_material: StandardMaterial3D
var knockback := Vector3.ZERO
var legs: Array[Node3D] = []
var rig: Dictionary = {}
var target_player: CharacterBody3D
var hold_time := 0.0
var reacting := false
var attack_pause := 1.0
var strafe_clock := 0.0
var strafe_sign := 1.0
var block_choice := 1
var parry_attempted := false
var weapon_pivot: Node3D
var hit_tween: Tween

func _ready() -> void:
	world = get_parent()
	home = position
	add_to_group("enemies")
	health = 180 if boss else 85
	collision_layer=2
	collision_mask=3
	var collider := CollisionShape3D.new()
	collider.name="CollisionShape3D"
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
	weapon_pivot=Node3D.new()
	weapon_pivot.position.y=1.45
	weapon_pivot.scale=Vector3.ONE*1.4
	body.add_child(weapon_pivot)
	weapon_pivot.add_child(blade)
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
	if boss: body.scale=Vector3.ONE*1.12
	combat=Fighter.new()
	combat.name="MeleeCombat"
	combat.profile=preload("res://combat/sword_profile.tres")
	combat.weapon=blade
	combat.max_health=180 if boss else 85
	combat.max_stamina=80
	combat.base_damage=30 if boss else 22
	combat.glow_on_windup=true
	add_child(combat)
	combat.swing_started.connect(func(_dir): world.sword_sound())

func _process(delta: float) -> void:
	if ai_enabled or not alive: return
	flash=maxf(0,flash-delta)
	for mesh in body.get_children():
		if mesh is MeshInstance3D: mesh.material_overlay=flash_material if flash>0 else null
	var blend := 1-exp(-delta*20)
	body.position=body.position.lerp(Vector3.ZERO,blend)
	body.rotation.y=lerp_angle(body.rotation.y,0,blend)
	blade.position=blade.position.lerp(net_blade_pos,blend)
	blade.rotation=blade.rotation.lerp(net_blade_rot,blend)
	world.art.animate_arm(rig,blade)

func _physics_process(delta: float) -> void:
	if not alive or not ai_enabled or (world.hit_stop>0 and not world.net.running): return
	combat.step(delta)
	var nearest := INF
	for candidate in world.net.combatants():
		if candidate.alive and candidate.active and position.distance_to(candidate.position)<nearest:
			target_player=candidate
			nearest=position.distance_to(candidate.position)
	if nearest==INF: return
	var offset: Vector3=target_player.position-position
	var distance := offset.length()
	var cap: float=combat.turn_cap()
	if distance>0.1: rotation.y=rotate_toward(rotation.y,atan2(-offset.x,-offset.z),(cap if cap>0 else 8.0)*delta)
	attack_pause=maxf(0,attack_pause-delta)
	if distance<(17 if boss else 13):
		think_combat(delta,distance)
	else:
		combat.stop_block()
	var direction := Vector3.ZERO
	if distance<(17 if boss else 13):
		if distance>2.0: direction=offset.normalized()
		elif distance<1.3: direction=-offset.normalized()*0.6
		else:
			strafe_clock-=delta
			if strafe_clock<=0:
				strafe_clock=world.rng.randf_range(1.2,3)
				strafe_sign=[-1.0,0.0,1.0][world.rng.randi_range(0,2)]
			direction=offset.normalized().cross(Vector3.UP)*strafe_sign*0.35
	elif position.distance_to(home)>0.7: direction=(home-position).normalized()*0.5
	var speed: float=(2.6 if boss else 2.2)*combat.move_multiplier()
	velocity.x=direction.x*speed+knockback.x
	velocity.z=direction.z*speed+knockback.z
	if not is_on_floor(): velocity.y-=22*delta
	move_and_slide()
	knockback=knockback.move_toward(Vector3.ZERO,delta*16)
	flash=maxf(0,flash-delta)
	for mesh in body.get_children():
		if mesh is MeshInstance3D: mesh.material_overlay=flash_material if flash>0 else null
	for i in legs.size(): legs[i].rotation.x=sin(Time.get_ticks_msec()*0.008+i*PI)*0.38 if direction.length()>0.1 else lerpf(legs[i].rotation.x,0,delta*8)
	combat.sync_view()
	bar.scale.x=maxf(0.01,health/combat.max_health)
	bar.visible=distance<13
	marker.visible=attacking
	direction_label.visible=distance<15 and (attacking or blocking or swing_time>0)
	direction_label.text="BLOCK "+Combat.NAMES[Combat.incoming(guard_direction)] if blocking else Combat.ARROWS[Combat.incoming(attack_direction)]
	direction_label.modulate=Color("80cee3") if blocking else Color("efbc6d")
	world.art.animate_arm(rig,blade)

func think_combat(delta: float, distance: float) -> void:
	var threat: bool=target_player.combat.is_attacking() and distance<4
	if threat:
		if not reacting:
			reacting=true
			parry_attempted=false
			reaction=0.2 if boss else 0.35
			block_choice=Combat.incoming(target_player.attack_direction) if world.rng.randf()<(0.8 if boss else 0.4) else world.rng.randi_range(0,3)
			guard_lock=world.rng.randf_range(0.4,0.8)
		reaction-=delta
		if reaction<=0 and combat.state in [MeleeCombat.State.IDLE,MeleeCombat.State.WINDUP]:
			combat.start_block(Combat.to_melee(block_choice))
		if not parry_attempted and target_player.combat.state==MeleeCombat.State.SWING and target_player.combat.blade_distance_to(combat)<0.7:
			parry_attempted=true
			if combat.state==MeleeCombat.State.BLOCK and world.rng.randf()<(0.4 if boss else 0.08): combat.refresh_block()
	elif reacting:
		reacting=false
		guard_lock=0.2
	if not reacting and guard_lock>0:
		guard_lock-=delta
		if guard_lock<=0: combat.stop_block()
	if combat.state==MeleeCombat.State.WINDUP:
		hold_time-=delta
		if hold_time<=0:
			if will_feint:
				will_feint=false
				feinted=true
				combat.feint_to(MeleeCombat.next_dir(combat.attack_dir))
				hold_time=0.45
			else: combat.release_attack()
	elif combat.state==MeleeCombat.State.IDLE and attack_pause==0 and distance<2.5 and not reacting:
		var active_attackers := 0
		for other in world.net.enemies_in_world():
			if other!=self and other.combat.is_attacking(): active_attackers+=1
		if active_attackers<2: begin_attack()

func begin_attack() -> void:
	var direction: int = world.rng.randi_range(0,3)
	if is_instance_valid(target_player) and target_player.blocking and world.rng.randf()<(0.75 if boss else 0.3):
		while Combat.incoming(direction)==target_player.guard_direction: direction=world.rng.randi_range(0,3)
	if combat.start_windup(Combat.to_melee(direction)):
		hold_time=world.rng.randf_range(0.4,1.1)
		will_feint=world.rng.randf()<(0.3 if boss else 0.08)
		feinted=false
		attack_pause=hold_time+world.rng.randf_range(0.8,1.8)
		combat.sync_view()

func receive_attack(amount: float, direction: int, _source: Vector3, attacker: Node3D = null) -> bool:
	if attacker==null: attacker=world.player
	var result: int=combat.receive_attack(attacker.combat,Combat.to_melee(direction),amount)
	combat.sync_view()
	return result in [MeleeCombat.Result.HIT,MeleeCombat.Result.GUARD_BREAK]

func take_damage(amount: float) -> void:
	if not alive:
		return
	combat._take_damage(amount)
	if alive: combat._stagger(combat.profile.flinch_time)
	flash=0.2
	bar.scale.x=maxf(0.01,health/combat.max_health)

func play_hit_reaction(direction: int, strength: float) -> void:
	if hit_tween: hit_tween.kill()
	var base_scale := Vector3.ONE*(1.12 if boss else 1.0)
	var tilt := -0.15 if direction==MeleeCombat.Dir.OVERHEAD else (0.18 if direction==MeleeCombat.Dir.THRUST else 0.0)
	var roll := 0.15 if direction==MeleeCombat.Dir.LEFT else (-0.15 if direction==MeleeCombat.Dir.RIGHT else 0.0)
	hit_tween=create_tween().set_parallel()
	hit_tween.tween_property(body,"rotation:x",tilt*strength,0.05)
	hit_tween.tween_property(body,"rotation:z",roll*strength,0.05)
	hit_tween.tween_property(body,"scale",base_scale*Vector3(1.03,0.94,1.03),0.05)
	hit_tween.chain().tween_property(body,"rotation:x",0.0,0.4)
	hit_tween.parallel().tween_property(body,"rotation:z",0.0,0.4)
	hit_tween.parallel().tween_property(body,"scale",base_scale,0.4)

func combat_death() -> void:
	if alive:
		if hit_tween: hit_tween.kill()
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
