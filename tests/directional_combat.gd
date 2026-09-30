extends SceneTree

const Combat = preload("res://scripts/combat.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures+=1

func reset_actor(actor) -> void:
	actor.combat.reset()
	actor.alive=true
	actor.combat.sync_view()

func run() -> void:
	var world=load("res://main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	world.start_or_resume()
	var player=world.player
	var enemy=world.net.enemies_in_world()[0]
	for e in world.net.enemies_in_world(): e.ai_enabled=false
	player.position=Vector3(0,0.05,0)
	enemy.position=Vector3(0,0.05,-2)
	enemy.rotation.y=PI
	# Exercise the imported shared defender rules on both combat components.
	for attack in range(4):
		for guard in range(4):
			reset_actor(player)
			reset_actor(enemy)
			player.combat.start_block(Combat.to_melee(guard))
			player.combat._block_time=1
			var result: int=player.combat.receive_attack(enemy.combat,Combat.to_melee(attack),28)
			check(result==(MeleeCombat.Result.BLOCKED if guard==Combat.incoming(attack) else MeleeCombat.Result.HIT),"Player guard %d vs swing %d" % [guard,attack])
			reset_actor(player)
			reset_actor(enemy)
			enemy.combat.start_block(Combat.to_melee(guard))
			enemy.combat._block_time=1
			result=enemy.combat.receive_attack(player.combat,Combat.to_melee(attack),28)
			check(result==(MeleeCombat.Result.BLOCKED if guard==Combat.incoming(attack) else MeleeCombat.Result.HIT),"Enemy guard %d vs swing %d" % [guard,attack])
	reset_actor(player)
	reset_actor(enemy)
	player.combat.start_block(MeleeCombat.Dir.OVERHEAD)
	var result: int=player.combat.receive_attack(enemy.combat,MeleeCombat.Dir.OVERHEAD,28)
	check(result==MeleeCombat.Result.PARRIED and player.health==100,"Fresh directional guard parries without health damage")
	reset_actor(player)
	player.combat.start_block(MeleeCombat.Dir.OVERHEAD)
	player.combat._block_time=1
	player.stamina=10
	result=player.combat.receive_attack(enemy.combat,MeleeCombat.Dir.OVERHEAD,28)
	check(result==MeleeCombat.Result.GUARD_BREAK and player.health==86 and player.stamina==0,"Exhausted guard breaks with partial damage")
	reset_actor(player)
	player.combat.start_block(MeleeCombat.Dir.OVERHEAD)
	enemy.position=Vector3(0,0.05,2)
	result=player.combat.receive_attack(enemy.combat,MeleeCombat.Dir.OVERHEAD,28)
	check(result==MeleeCombat.Result.HIT,"Correct guard cannot stop a rear attack")
	reset_actor(player)
	reset_actor(enemy)
	enemy.position=Vector3(0,0.05,-2)
	player.select_direction(0)
	player.attack(true)
	check(player.winding and player.attack_direction==0,"Held attack starts selected directional windup")
	player.select_direction(2)
	check(player.feint() and player.attack_direction==2 and player.stamina==92,"Q redirects windup and spends feint stamina")
	player.combat.start_block(MeleeCombat.Dir.OVERHEAD)
	check(player.combat.state==MeleeCombat.State.BLOCK and player.stamina==84,"Raising guard cancels windup")
	player.select_direction(0)
	check(player.combat.block_dir==MeleeCombat.Dir.LEFT,"Raised guard follows selected direction")
	# Real blade sweeps, rather than the old cone/range damage decision.
	var quick_damage := 0.0
	for direction in range(4):
		reset_actor(player)
		reset_actor(enemy)
		world.hit_stop=0
		player.position=Vector3(0,0.05,0)
		player.velocity=Vector3.ZERO
		player.camera.rotation=Vector3.ZERO
		enemy.position=Vector3(0,0.05,-1.9)
		enemy.knockback=Vector3.ZERO
		player.select_direction(direction)
		await physics_frame
		player.attack()
		check(enemy.health==85,"Direction %d does not hit during windup" % direction)
		await create_timer(1.3).timeout
		print("Sweep %d health: %.2f" % [direction,enemy.health])
		check(enemy.health<85,"Direction %d lands through swept blade contact" % direction)
		if direction==1: quick_damage=85-enemy.health
	for direction in range(4):
		reset_actor(player)
		reset_actor(enemy)
		world.hit_stop=0
		player.position=Vector3(0,0.05,0)
		player.velocity=Vector3.ZERO
		enemy.position=Vector3(0,0.05,-1.9)
		enemy.rotation.y=PI
		enemy.combat.start_block(Combat.to_melee(Combat.incoming(direction)))
		enemy.combat._block_time=1
		enemy.combat._update_animation(0.2)
		player.select_direction(direction)
		player.attack()
		await create_timer(1.3).timeout
		check(enemy.health==85 and enemy.stamina<80,"Actual sweep %d stops on correct directional guard" % direction)
	reset_actor(player)
	reset_actor(enemy)
	world.hit_stop=0
	player.select_direction(1)
	player.attack(true)
	await create_timer(1.15).timeout
	check(player.winding and enemy.health==85,"Holding full charge waits for release")
	player.combat.queue_release()
	await create_timer(1.0).timeout
	check(85-enemy.health>quick_damage+3,"Fully charged overhead deals more damage than a quick strike")
	reset_actor(player)
	player.combat.resolves_contacts=false
	player.combat.queue_windup(MeleeCombat.Dir.LEFT)
	player.combat.queue_release()
	player.combat._physics_process(0.4)
	player.combat.queue_windup(MeleeCombat.Dir.THRUST)
	player.combat.queue_release()
	check(player.combat.queued==MeleeCombat.Queued.WINDUP,"Next tap is buffered while swinging")
	for i in range(140): player.combat._physics_process(1.0/60)
	check(player.combat.attack_dir==MeleeCombat.Dir.THRUST,"Buffered follow-up executes after recovery")
	reset_actor(player)
	reset_actor(enemy)
	player.combat.state=MeleeCombat.State.SWING
	player.combat.attack_dir=MeleeCombat.Dir.OVERHEAD
	enemy.combat.start_block(MeleeCombat.Dir.OVERHEAD)
	player.combat.apply_contact(enemy.combat,MeleeCombat.Result.PARRIED,true,enemy.position+Vector3.UP,28)
	check(player.combat.state==MeleeCombat.State.STAGGER,"Perfect parry staggers attacker")
	reset_actor(enemy)
	enemy.target_player=player
	enemy.begin_attack()
	var initial: int=enemy.combat.attack_dir
	enemy.will_feint=true
	enemy.hold_time=0
	enemy.think_combat(0.01,2)
	check(enemy.feinted and enemy.combat.attack_dir!=initial,"AI redirects its windup with the same combat core")
	reset_actor(player)
	reset_actor(enemy)
	world.hit_stop=0
	player.position=Vector3(10,0.05,-30)
	player.rotation.y=PI/2
	player.velocity=Vector3.ZERO
	enemy.position=Vector3(8,0.05,-30)
	var wall_contacts := [0]
	player.combat.world_hit.connect(func(_point): wall_contacts[0]+=1)
	player.select_direction(3)
	player.attack()
	await create_timer(1.3).timeout
	check(enemy.health==85,"Swept blade cannot damage through an abbey wall")
	check(wall_contacts[0]>0,"Wall contact triggers weapon bounce feedback")
	await create_timer(0.4).timeout
	world.queue_free()
	await process_frame
	await process_frame
	print("Directional combat: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
