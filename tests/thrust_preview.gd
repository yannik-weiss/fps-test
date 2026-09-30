extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var world=load("res://main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.start_or_resume()
	for e in world.net.enemies_in_world(): e.ai_enabled=false
	world.player.select_direction(3)
	world.player.attack()
	await create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/thrust.png")
	print("Thrust view saved.")
	quit()
