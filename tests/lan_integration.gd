extends SceneTree

var failures := 0
var count := 0
var host_world
var client_world

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	count+=1
	if condition: print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures+=1

func make_world(title: String):
	var viewport := SubViewport.new()
	viewport.name=title
	viewport.world_3d=World3D.new()
	viewport.size=Vector2i(1440,900)
	root.add_child(viewport)
	var api := SceneMultiplayer.new()
	set_multiplayer(api,viewport.get_path())
	var scene = load("res://main.tscn").instantiate()
	viewport.add_child(scene)
	return scene

func run() -> void:
	host_world=make_world("Host")
	client_world=make_world("Client")
	await process_frame
	check(host_world.net.host_game("Host","127.0.0.1")==OK,"ENet host starts on loopback")
	client_world.net.open_lobby()
	await create_timer(0.4).timeout
	check(client_world.net.rounds.has("127.0.0.1"),"UDP discovery finds running host")
	check(client_world.net.join_game("127.0.0.1","Guest")==OK,"LAN client connection begins")
	await create_timer(0.8).timeout
	check(client_world.net.running and host_world.net.actors.size()==2,"Real ENet connection registers second player")
	if not client_world.net.running:
		quit(1)
		return
	var id: int=client_world.player.peer_id
	var remote=host_world.net.actors[id]
	check(remote.display_name=="Guest" and client_world.net.actors.has(1),"Names and player avatars replicate")
	for enemy in host_world.net.enemies_in_world(): enemy.ai_enabled=false
	remote.position=Vector3(0,0.1,-10)
	client_world.player.position=remote.position
	client_world.net.send_clock=-10
	var frames: Array=[]
	for sequence in range(remote.last_input_received+1,remote.last_input_received+9):
		frames.append(PackedFloat64Array([sequence,1,0,0,0,0,0]))
	client_world.net.submit_frames.rpc_id(1,frames)
	await create_timer(0.18).timeout
	check(remote.position.x>0.2,"Client movement is simulated by host")
	remote.position=Vector3(0,0.1,-10)
	remote.velocity=Vector3.ZERO
	remote.net_move=Vector2.ZERO
	host_world.player.position=Vector3(0,0.1,-12.3)
	host_world.player.health=100
	remote.stamina=100
	client_world.net.command("attack",1)
	client_world.net.command("release",1)
	await create_timer(0.45).timeout
	check(host_world.player.health==72,"Network attack damages another player outside camp")
	check(client_world.net.actors[1].health==72,"PvP health change replicates to client")
	# The server decides directional block outcomes, independent of client damage claims.
	host_world.player.blocking=true
	host_world.player.guard_direction=1
	host_world.player.stamina=100
	host_world.player.block_age=1
	host_world.player.rotation.y=PI
	remote.attack_direction=1
	host_world.net.resolve_attack(remote)
	check(host_world.player.health==72,"Correct PvP directional block prevents damage")
	host_world.player.guard_direction=0
	host_world.net.resolve_attack(remote)
	check(host_world.player.health==44,"Wrong PvP block direction takes damage")
	host_world.player.position=Vector3(0,0.1,10)
	remote.position=Vector3(0,0.1,12.3)
	host_world.net.resolve_attack(remote)
	check(host_world.player.health==44,"Camp safe zone prevents PvP damage")
	# Shared resource transaction via actual RPC; duplicate request cannot grant it twice.
	remote.position=Vector3(-5,0.1,3)
	remote.rotation=Vector3.ZERO
	client_world.net.command("interact")
	client_world.net.command("interact")
	await create_timer(0.2).timeout
	check(remote.wood==1 and host_world.resources[2].used,"Resource collected once by authoritative host")
	check(client_world.player.wood==1 and client_world.resources[2].used,"Inventory and depleted resource replicate")
	# PvE from a client with server-owned health and AI.
	var enemy=host_world.net.enemies_in_world()[0]
	enemy.position=Vector3(0,0.1,-14)
	enemy.health=28
	remote.position=Vector3(0,0.1,-11.7)
	remote.cooldown=0
	remote.stagger=0
	remote.winding=false
	remote.blocking=false
	remote.stamina=100
	remote.rotation=Vector3.ZERO
	client_world.player.rotation=Vector3.ZERO
	client_world.player.camera.rotation=Vector3.ZERO
	client_world.net.command("attack",2)
	client_world.net.command("release",2)
	await create_timer(0.5).timeout
	check(not enemy.alive,"Client attack defeats shared PvE enemy")
	check(not client_world.net.enemies_in_world()[0].alive,"Enemy death replicates")
	check(client_world.resources.size()==host_world.resources.size(),"Server loot exists on client")
	# Real late join receives existing deaths and resource depletion.
	var late=make_world("Late")
	late.net.join_game("127.0.0.1","Late")
	await create_timer(0.7).timeout
	check(late.net.running and not late.net.enemies_in_world()[0].alive and late.resources[2].used,"Late join restores shared world state")
	remote.health=1
	remote.blocking=false
	remote.take_damage(20,remote.position+Vector3.BACK,1)
	await create_timer(0.15).timeout
	check(not client_world.player.alive and client_world.menu.visible,"Network death shows respawn menu")
	client_world.net.command("respawn")
	await create_timer(0.2).timeout
	check(remote.alive and client_world.player.alive and remote.position.z>12,"Respawn request restores player at camp")
	late.net.leave_game()
	await create_timer(0.2).timeout
	check(host_world.net.actors.size()==2,"Leaving removes player from server")
	host_world.net.leave_game()
	await create_timer(0.2).timeout
	check(not client_world.net.running and client_world.menu.visible,"Host departure closes client session cleanly")
	check(not host_world.net.is_local_address("8.8.8.8"),"Public IP connection rejected")
	await create_timer(0.3).timeout
	print("LAN integration: %d checks, %d failures" % [count,failures])
	quit(0 if failures==0 else 1)
