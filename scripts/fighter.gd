extends MeleeCombat
# Bridge the fpsgame combat core to Aschenmark's world and authoritative LAN.
const Directions = preload("res://scripts/combat.gd")
var world: Node3D

func _ready() -> void:
	super._ready()
	world=body.get_parent()
	set_physics_process(false)
	attack_resolved.connect(on_attack_resolved)
	defended.connect(on_defended)
	world_hit.connect(func(point):
		world.impact(point,true)
		if body.has_method("feedback"): report("KLINGE PRALLT AB","block"))
	contact_decided.connect(func(target,result,blade_contact,point,damage):
		if world.net.running and world.net.hosting:
			world.net.broadcast_contact(self,target,result,blade_contact,point,damage))
	world_contact_decided.connect(func(point):
		if world.net.running and world.net.hosting: world.net.receive_world_contact.rpc(world.net.fighter_id(body),point))
	died.connect(body.combat_death)

func step(delta: float) -> void:
	resolves_contacts=not world.net.running or world.net.hosting
	super._physics_process(delta)
	sync_view()

func sync_view() -> void:
	body.attack_direction=Directions.from_melee(attack_dir)
	body.guard_direction=Directions.from_melee(block_dir)
	body.blocking=state==State.BLOCK
	body.swing_time=maxf(0,_swing_end_time-_timer) if state==State.SWING else 0.0
	body.stagger=maxf(0,_state_duration-_timer) if state==State.STAGGER else 0.0
	body.cooldown=maxf(0,_state_duration-_timer) if state==State.RECOVER else 0.0
	if body.has_method("attack"):
		body.winding=state==State.WINDUP
		body.windup=_timer if body.winding else 0.0
		body.block_age=_block_time
	else:
		body.attacking=state==State.WINDUP

func _opponents() -> Array[MeleeCombat]:
	var found: Array[MeleeCombat]=[]
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as MeleeCombat
		if not other or other==self or other.body.get_parent()!=world or other.is_dead(): continue
		var player := body.has_method("attack")
		var other_player := other.body.has_method("attack")
		if not player and not other_player: continue
		if player and other_player:
			if not world.net.running or world.net.safe_zone(body.position) or world.net.safe_zone(other.body.position): continue
		found.append(other)
	return found

func _on_contact(target: MeleeCombat, blade_contact: bool, point: Vector3) -> bool:
	# Test world occlusion before a body/guard contact; the upstream sweep checks
	# geometry afterwards and would otherwise allow contact through a thin wall.
	var exclude: Array[RID]=[body.get_rid(),target.body.get_rid()]
	if not world.clear_line(weapon.get_parent().global_position,point,exclude):
		return _check_world_hit(point,point)
	return super._on_contact(target,blade_contact,point)

func _spawn_spark(point: Vector3) -> void:
	world.impact(point,true)

func on_attack_resolved(result: Result, target: MeleeCombat) -> void:
	if not body.has_method("feedback"): return
	match result:
		Result.MISS: report("VERFEHLT","miss")
		Result.HIT, Result.GUARD_BREAK:
			body.shake=profile.hit_camera_shake*8
			report("GUARD GEBROCHEN" if result==Result.GUARD_BREAK else "TREFFER · %d" % int(last_swing_damage),"hit")
		Result.BLOCKED: report("GEGNER BLOCKT · Richtungsfinte","block")
		Result.PARRIED: report("GEGNER PARIERT","block")
	if target and result in [Result.HIT,Result.GUARD_BREAK]: world.impact(target.body.position+Vector3.UP,false)

func on_defended(result: Result, attacker: MeleeCombat) -> void:
	if body.has_method("feedback"):
		body.recoil=0.8
		body.shake=0.5
		if result in [Result.HIT,Result.GUARD_BREAK]:
			body.hurt_time=0.5
			report("GUARD GEBROCHEN" if result==Result.GUARD_BREAK else "GETROFFEN","hurt")
		else: report("PERFEKTE PARADE" if result==Result.PARRIED else "BLOCK","parry" if result==Result.PARRIED else "block")
	else:
		body.flash=0.2
		if result in [Result.HIT,Result.GUARD_BREAK]:
			body.knockback=(body.position-attacker.body.position).normalized()*2
			if body.alive: body.play_hit_reaction(int(attacker.attack_dir),clampf(attacker.last_swing_damage/30,0.6,1.5))
	sync_view()

func report(text: String, kind: String) -> void:
	# The contact replay supplies client feedback; do not also send the legacy
	# feedback RPC for the same authoritative exchange.
	if body.local_control: world.combat_feedback(text,kind)

# The reference poses pull the thrust grip behind the camera, then extrapolate it
# past the opponent on a miss. Keep a short arm stroke with the same blade sweep.
func _windup_pose(amount: float) -> Array:
	if attack_dir==Dir.THRUST:
		return _mix(POSES["idle"],[Vector3(0.23,-0.10,-0.40),Vector3(-80,8,0)],amount)
	return super._windup_pose(amount)

func _swing_pose() -> Array:
	if attack_dir==Dir.THRUST: return [Vector3(0.23,-0.12,-0.58),Vector3(-88,0,0)]
	return super._swing_pose()

func _snap_to(pose: Array) -> void:
	var adjusted := pose.duplicate()
	if attack_dir==Dir.THRUST and state in [State.WINDUP,State.SWING,State.RECOVER]:
		var grip: Vector3=adjusted[0]
		grip.z=clampf(grip.z,-0.64,-0.24)
		grip.x=clampf(grip.x,0.2,0.42)
		grip.y=clampf(grip.y,-0.4,-0.08)
		adjusted[0]=grip
	super._snap_to(adjusted)

func set_block_dir(dir: Dir) -> void:
	# Re-aiming a held guard must not grant a fresh perfect-parry window.
	var age := _block_time
	super.set_block_dir(dir)
	_block_time=age

func aim_guard(direction: int) -> void:
	if state==State.BLOCK: set_block_dir(direction)
	if queued==Queued.BLOCK: queued_dir=direction
	sync_view()

func hold_guard(held: bool, direction: int) -> void:
	if held:
		aim_guard(direction)
		if state==State.IDLE and stamina>0: queue_block(direction)
	else: queue_block_release()
