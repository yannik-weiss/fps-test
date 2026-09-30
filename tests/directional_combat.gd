extends SceneTree

const Combat = preload("res://scripts/combat.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func run() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.start_or_resume()
	var player = world.player
	var enemy = get_nodes_in_group("enemies")[0]
	for foe in get_nodes_in_group("enemies"):
		foe.ai_enabled = false
	player.position = Vector3(0, 0.05, 0)
	enemy.position = Vector3(0, 0.05, -2.3)
	enemy.rotation.y = PI
	# Every attack/guard combination for both participants, including thrust.
	for attack in range(4):
		for guard in range(4):
			player.health = 100
			player.stamina = 100
			player.blocking = true
			player.block_age = 1
			player.guard_direction = guard
			player.take_damage(17, enemy.position, attack)
			check(player.health == (100 if guard == attack else 83), "Player guard %d vs incoming %d" % [guard, attack])
			enemy.health = 1000
			enemy.stamina = 80
			enemy.blocking = true
			enemy.guard_direction = guard
			enemy.receive_attack(28, attack, player.position)
			check(enemy.health == (1000 if guard == Combat.incoming(attack) else 972), "Enemy guard %d vs swing %d" % [guard, attack])
	player.health = 100
	player.stamina = 14
	player.blocking = true
	player.guard_direction = 1
	player.take_damage(17, enemy.position, 1)
	check(player.health == 83, "Insufficient stamina cannot block")
	player.health = 100
	player.stamina = 100
	player.block_age = 0.1
	player.take_damage(17, enemy.position, 1)
	check(player.health == 100 and player.stamina == 92, "Fresh correct guard is a cheaper perfect parry")
	player.health = 100
	player.stamina = 100
	player.take_damage(17, Vector3(0, 0, 2), 1)
	check(player.health == 83, "Matching directional guard cannot stop rear attacks")
	player.blocking = false
	player.stagger = 0
	player.cooldown = 0
	player.stamina = 100
	player.select_direction(0)
	player.attack(true)
	check(player.winding and player.attack_direction == 0, "Holding attack starts chosen windup")
	var before: float = enemy.health
	check(player.feint(), "Q can cancel during windup")
	await create_timer(0.45).timeout
	check(enemy.health == before and not player.winding, "Cancelled windup never deals delayed damage")
	check(not player.feint(), "No feint after windup ends")
	# A feint draws a real AI guard. Its committed guard cannot track the follow-up instantly.
	world.hit_stop = 0
	player.health = 100
	player.stamina = 100
	player.stagger = 0
	player.cooldown = 0
	enemy.stamina = 80
	enemy.stagger = 0
	enemy.cooldown = 2
	enemy.guard_lock = 0
	enemy.reaction = 0
	enemy.knockback = Vector3.ZERO
	enemy.health = 1000
	enemy.ai_enabled = true
	player.position = Vector3(0, 0.05, 0)
	enemy.position = Vector3(0, 0.05, -2.3)
	player.select_direction(0)
	player.attack(true)
	await create_timer(0.29).timeout
	check(enemy.blocking and enemy.guard_lock > 0, "AI raises a directional guard in response to windup")
	var committed: int = enemy.guard_direction
	player.feint()
	await create_timer(0.2).timeout
	player.select_direction((Combat.incoming(committed) + 1) % 4)
	player.attack()
	before = enemy.health
	await create_timer(0.42).timeout
	check(enemy.health < before, "Feint and changed direction defeat committed AI guard")
	# AI direction selection and feint must also execute, not just display.
	enemy.ai_enabled = false
	var observed: Dictionary = {}
	for i in range(40):
		enemy.stamina = 80
		enemy.begin_attack()
		observed[enemy.attack_direction] = true
	check(observed.size() == 4, "AI uses all four attack directions")
	enemy.attack_direction = 0
	enemy.will_feint = true
	enemy.feinted = false
	enemy.attack_elapsed = 0
	enemy.windup = 0.9
	enemy.feint_gap = 0
	enemy.update_attack(0.31, 2.3)
	check(enemy.feinted and enemy.attack_direction != 0 and enemy.feint_gap > 0, "AI feint cancels its initial direction and changes attack")
	player.health = 100
	player.blocking = true
	player.swing_time = 0
	player.stagger = 0
	player.winding = false
	player.knockback = Vector3.ZERO
	world.hit_stop = 0
	player.select_direction(Combat.incoming(enemy.attack_direction))
	Input.action_press("block")
	player.block_age = 1
	player.stamina = 100
	enemy.rotation.y = PI
	enemy.position = Vector3(0, 0.05, -2.3)
	player.position = Vector3(0, 0.05, 0)
	await physics_frame
	await physics_frame
	player.block_age = 1
	enemy.update_attack(0.2, 2.3)
	enemy.update_attack(0.6, 2.3)
	check(player.health == 100 and player.stamina == 85, "Changed AI attack can be blocked on its actual new side")
	Input.action_release("block")
	# Thrust has extra reach but a narrower aim cone.
	enemy.attacking = false
	enemy.blocking = false
	enemy.health = 1000
	enemy.position = Vector3(0, 0.05, -3.25)
	enemy.knockback = Vector3.ZERO
	player.position = Vector3(0, 0.05, 0)
	player.knockback = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.blocking = false
	player.stagger = 0
	player.cooldown = 0
	player.winding = false
	player.stamina = 100
	player.select_direction(3)
	player.attack()
	await create_timer(0.42).timeout
	check(enemy.health == 972, "Aimed thrust hits at extended reach")
	player.cooldown = 0
	player.select_direction(1)
	player.attack()
	await create_timer(0.42).timeout
	check(enemy.health == 972, "Overhead swing cannot reach the same distant target")
	await create_timer(0.3).timeout
	print("Directional combat: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)
