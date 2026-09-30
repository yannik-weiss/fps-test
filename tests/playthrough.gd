extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	check(scene.menu.visible and not scene.player.active, "Starts in the welcome menu")
	scene.start_or_resume()
	for foe in get_nodes_in_group("enemies"):
		foe.ai_enabled = false
	check(scene.player.active and not scene.menu.visible, "Start button enters the world")
	# Interact through the same focus selection used by the E key.
	for kind in ["wood", "ore"]:
		var collected := 0
		for resource in scene.resources:
			if resource.kind != kind:
				continue
			scene.player.position = resource.pos + Vector3(0, 0.05, 2)
			scene.player.rotation = Vector3.ZERO
			scene.player.camera.rotation = Vector3.ZERO
			scene.interact()
			check(resource.used, "Collect " + kind + " through focus interaction")
			collected += 1
			if collected == 2:
				break
	check(scene.wood == 2 and scene.ore == 2, "Resources added to inventory")
	scene.player.position = Vector3(4, 0.05, 9)
	scene.interact()
	check(scene.player.weapon_level == 2 and scene.wood == 0 and scene.ore == 0, "Forge consumes resources and upgrades sword")
	scene.interact()
	check(scene.player.weapon_level == 2 and scene.wood == 0, "Upgraded sword cannot consume resources twice")
	# Frontal blocks consume stamina; rear attacks bypass them.
	scene.player.position = Vector3(0, 0.05, 12)
	scene.player.blocking = true
	scene.player.stamina = 100
	scene.player.block_age = 1
	scene.player.take_damage(17, Vector3(0, 0, 10))
	check(scene.player.health == 100 and scene.player.stamina == 85, "Frontal block prevents damage and costs stamina")
	scene.player.take_damage(17, Vector3(0, 0, 14))
	check(scene.player.health == 83, "Rear attack bypasses frontal block")
	scene.player.blocking = false
	scene.player.position = Vector3(0, 0.05, 9)
	scene.interact()
	check(scene.player.health == 100 and scene.player.stamina == 100, "Campfire restores health and stamina")
	# A closed abbey wall must occlude sword hits.
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.position = Vector3(8, 0.05, -30)
	scene.player.position = Vector3(10, 0.05, -30)
	scene.player.rotation.y = PI / 2
	scene.player.cooldown = 0
	await physics_frame
	await physics_frame
	scene.player.attack()
	await create_timer(0.42).timeout
	check(enemy.health == 85, "Sword does not hit through abbey wall")
	# Attack the guardian with real cooldown and AI updates between swings.
	var boss = get_nodes_in_group("enemies")[-1]
	scene.player.position = boss.position + Vector3(0, 0, 2.3)
	scene.player.rotation = Vector3.ZERO
	scene.player.stamina = 100
	scene.player.cooldown = 0
	await physics_frame
	var before: float = boss.health
	scene.player.attack()
	check(boss.health == before, "Windup does not deal instant damage")
	await create_timer(0.42).timeout
	check(boss.health == before - 45 and scene.player.stamina <= 80, "Aimed upgraded sword hits and costs stamina")
	var after: float = boss.health
	scene.player.attack()
	check(boss.health == after, "Cooldown prevents immediate second attack")
	for i in range(3):
		await create_timer(0.58).timeout
		scene.player.attack()
		await create_timer(0.42).timeout
	check(not boss.alive and scene.boss_dead, "Guardian can be defeated using timed sword attacks")
	var loot = scene.resources[-1]
	scene.player.position = loot.pos + Vector3(0, 0.05, 2)
	scene.player.rotation = Vector3.ZERO
	scene.interact()
	check(scene.gold == 35 and loot.used, "Guardian gold can be looted once")
	scene.player.position = Vector3(0, 0.05, 9)
	scene.interact()
	check(scene.victory and scene.menu.visible and not scene.player.active, "Return to camp completes quest and shows result")
	scene.start_or_resume()
	check(scene.player.active, "Exploration continues after victory")
	scene.player.take_damage(200, Vector3(0, 0, 14))
	check(not scene.player.alive and scene.menu.visible, "Death opens retry menu")
	await create_timer(0.3).timeout
	print("Playthrough finished: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
