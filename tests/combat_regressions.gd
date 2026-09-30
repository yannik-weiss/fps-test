extends SceneTree
const Directions = preload("res://scripts/combat.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)
func run() -> void:
	var world=load("res://main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var p=world.player
	var enemy=world.net.enemies_in_world()[0]
	for e in world.net.enemies_in_world():
		e.ai_enabled=false
		e.position=Vector3(40,0,40)
	p.position=Vector3(0,0.05,0)
	enemy.position=Vector3(0,0.05,-1.9)
	enemy.rotation.y=PI
	p.combat.start_block(MeleeCombat.Dir.OVERHEAD)
	p.combat._block_time=0.5
	for direction in range(4):
		p.select_direction(direction)
		check(p.combat.block_dir==Directions.to_melee(direction),"Held block follows direction %d" % direction)
		check(p.combat._block_time==0.5,"Direction %d cannot refresh parry timing" % direction)
		var result: int=p.combat.decide_defense(enemy.combat,MeleeCombat.required_block(Directions.to_melee(direction)),28)
		check(result==MeleeCombat.Result.BLOCKED,"Re-aimed direction %d stops matching attack" % direction)
	p.combat._stagger(0.1)
	for i in range(15):
		p.combat.hold_guard(true,MeleeCombat.Dir.THRUST)
		p.combat.step(1.0/60)
	check(p.combat.state==MeleeCombat.State.BLOCK,"Held guard resumes after stagger")
	p.combat.hold_guard(false,MeleeCombat.Dir.THRUST)
	check(p.combat.state==MeleeCombat.State.IDLE,"Releasing button lowers restored guard")
	p.combat._set_state(MeleeCombat.State.RECOVER,0.1)
	p.combat.queue_block(MeleeCombat.Dir.OVERHEAD)
	p.select_direction(0)
	for i in range(12): p.combat.step(1.0/60)
	check(p.combat.state==MeleeCombat.State.BLOCK and p.combat.block_dir==MeleeCombat.Dir.LEFT,"Buffered guard uses latest selected direction")
	for direction in range(4):
		p.combat.reset()
		enemy.combat.reset()
		p.combat.start_block(Directions.to_melee(Directions.incoming(direction)))
		p.combat._block_time=0.5
		p.combat._update_animation(0.2)
		enemy.combat.queue_windup(Directions.to_melee(direction))
		enemy.combat.queue_release()
		for i in range(100): enemy.combat.step(1.0/60)
		check(p.health==100 and p.stamina<100,"Actual enemy swing %d is stopped by player guard" % direction)
	# Record every pose from windup through miss, follow-through and recovery.
	enemy.position=Vector3(40,0,40)
	p.combat.reset()
	p.combat.queue_windup(MeleeCombat.Dir.THRUST)
	p.combat.queue_release()
	var near := -INF
	var far := INF
	var max_step := 0.0
	var last: Vector3=p.sword.position
	for i in range(180):
		p.combat.step(1.0/60)
		near=maxf(near,p.sword.position.z)
		far=minf(far,p.sword.position.z)
		max_step=maxf(max_step,last.distance_to(p.sword.position))
		last=p.sword.position
	check(near<=-0.24 and far>=-0.6401,"Thrust grip stays in arm reach including miss follow-through")
	check(max_step<0.06,"Thrust does not jump or fly forward between frames")
	check(p.combat.state==MeleeCombat.State.IDLE,"Missed thrust returns to ready stance")
	p.combat.reset()
	enemy.combat.reset()
	enemy.position=Vector3(0,0.05,-1.9)
	p.combat.queue_windup(MeleeCombat.Dir.THRUST)
	p.combat.queue_release()
	for i in range(100): p.combat.step(1.0/60)
	check(enemy.health<85,"Short thrust animation still lands physical blade contact")
	await create_timer(0.5).timeout
	world.queue_free()
	await process_frame
	await process_frame
	print("Combat regressions: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
