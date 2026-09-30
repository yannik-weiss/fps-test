extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	root.get_texture().get_image().save_png("res://screenshots/start.png")
	world.start_or_resume()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/camp.png")
	world.player.position = Vector3(1, 0.05, -15)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation.x = -0.04
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/ruins.png")
	var enemy = get_nodes_in_group("enemies")[0]
	for foe in get_nodes_in_group("enemies"):
		foe.ai_enabled = false
	enemy.ai_enabled = true
	enemy.position = Vector3(0, 0.05, -17)
	enemy.rotation.y = PI
	enemy.begin_attack()
	enemy.attack_direction = 1
	enemy.will_feint = false
	world.player.position = Vector3(0, 0.05, -14.5)
	world.player.select_direction(1)
	Input.action_press("block")
	await create_timer(0.3).timeout
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3(-0.04, 0, 0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/combat.png")
	Input.action_release("block")
	world.player.active = false
	world.journal.visible = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/journal.png")
	world.journal.hide()
	world.net.open_lobby()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/lan.png")
	print("Six rendered screenshots saved.")
	quit()
