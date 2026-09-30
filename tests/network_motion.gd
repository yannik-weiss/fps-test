extends SceneTree

var failures := 0
var checks := 0
var host
var client
var packets := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if ok: print("PASS: "+message)
	else:
		push_error("FAIL: "+message)
		failures+=1

func make_world(title: String):
	var viewport := SubViewport.new()
	viewport.name=title
	viewport.world_3d=World3D.new()
	root.add_child(viewport)
	set_multiplayer(SceneMultiplayer.new(),viewport.get_path())
	var world=load("res://main.tscn").instantiate()
	viewport.add_child(world)
	return world

func delayed_send(frames: Array) -> void:
	await create_timer(0.1).timeout
	if client.net.running: client.net.submit_frames.rpc_id(1,frames)

func run() -> void:
	host=make_world("Host")
	client=make_world("Client")
	await process_frame
	host.net.host_game("Host","127.0.0.1")
	client.net.join_game("127.0.0.1","Guest")
	await create_timer(0.8).timeout
	check(client.net.local_initialized,"Client receives initial authoritative spawn")
	if not client.net.local_initialized:
		quit(1)
		return
	host.player.active=false
	for e in host.net.enemies_in_world(): e.ai_enabled=false
	var actor=host.net.actors[client.player.peer_id]
	# Place both copies in open terrain and let gravity settle identically.
	client.player.position=Vector3(30,3,15)
	actor.position=client.player.position
	client.player.velocity=Vector3.ZERO
	actor.velocity=Vector3.ZERO
	await create_timer(0.7).timeout
	client.net.send_clock=-100
	var start: float=client.player.position.x
	var previous := start
	var min_step := INF
	var max_correction := 0.0
	var elapsed := 0.0
	var send_time := 0.0
	var state_before: int=host.net.state_packets
	Input.action_press("right")
	# Add 100 ms input latency, lose every fourth packet, and duplicate others.
	# Predictions must retain movement whose input is still in transit.
	while elapsed<1.5:
		await physics_frame
		var delta := 1.0/Engine.physics_ticks_per_second
		elapsed+=delta
		send_time+=delta
		if send_time>=1.0/30:
			send_time-=1.0/30
			packets+=1
			if packets%4!=0:
				var frames: Array=client.net.input_frames.duplicate()
				delayed_send(frames)
				if packets%7==0: delayed_send(frames)
		if elapsed>0.3:
			min_step=minf(min_step,client.player.position.x-previous)
			max_correction=maxf(max_correction,client.player.camera_correction.length())
		previous=client.player.position.x
	Input.action_release("right")
	client.net.send_clock=0
	await create_timer(0.5).timeout
	print("Motion metrics: distance=%.3f, minimum step=%.4f, correction=%.4f, final error=%.4f, queue=%d, ack lag=%d" % [client.player.position.x-start,min_step,max_correction,client.player.position.distance_to(actor.position),actor.input_queue.size(),client.net.input_sequence-actor.last_input_processed])
	check(client.player.position.x-start>6,"Delayed/lost packets do not slow local movement")
	check(min_step>=-0.01,"Confirmed inputs do not pull advancing client backward")
	check(max_correction<0.2,"Prediction stays stable with 100 ms latency and packet loss")
	check(client.player.position.distance_to(actor.position)<0.12,"Host and client converge after movement stops")
	check(host.net.state_packets==state_before,"Movement and stamina do not resend reliable world state")
	check(actor.input_queue.size()<5,"Input retransmission does not accumulate duplicate movement")
	check(var_to_bytes(client.net.input_frames).size()<1000,"Full repeated input window fits in one small packet")
	var ground_y: float=client.player.position.y
	Input.action_press("jump")
	await physics_frame
	await physics_frame
	Input.action_release("jump")
	await create_timer(0.15).timeout
	check(client.player.position.y>ground_y+0.5 and actor.position.y>ground_y+0.3,"Predicted jump reaches authoritative host")
	await create_timer(0.8).timeout
	check(client.player.position.distance_to(actor.position)<0.12,"Jump prediction converges after landing")
	# A stale pose must never undo the latest received movement.
	var other=client.net.actors[1]
	var old_pos: Vector3=other.position
	client.net.receive_player_motion(-1,1,Vector3(99,0,0),Vector3.ZERO,0,0,100,1,1,0,0)
	check(other.position==old_pos,"Stale movement packet cannot rewind a remote player")
	var visual_pos: Vector3=other.avatar.global_position
	var next_sequence: int=client.net.motion_sequences.get(1,0)+1
	client.net.receive_player_motion(next_sequence,1,old_pos+Vector3(0.2,0,0),Vector3.ZERO,PI/2,0,100,1,1,0,0)
	check(other.avatar.global_position.distance_to(visual_pos)<0.001,"Turning remote player preserves visual position at packet arrival")
	other._process(0.05)
	check(other.avatar.position.length()<0.2,"Remote avatar smoothly approaches latest pose")
	var enemy=client.net.enemies_in_world()[0]
	visual_pos=enemy.body.global_position
	next_sequence=client.net.enemy_sequences.get(0,0)+1
	client.net.receive_enemy_motion(next_sequence,0,enemy.position+Vector3(0.2,0,0),PI/2,1,1,0,0,Vector3(0.5,1,-0.2),Vector3.ONE)
	check(enemy.body.global_position.distance_to(visual_pos)<0.001,"Enemy movement and turning preserve visual position at packet arrival")
	enemy._process(0.05)
	check(enemy.body.position.length()<0.2 and enemy.blade.rotation.length()>0,"Enemy body and sword smoothly approach latest pose")
	# Duplicate one-shot jump commands must be consumed exactly once.
	actor.input_queue.clear()
	var sequence: int=actor.last_input_received+1
	var jump_frame := PackedFloat64Array([sequence,0,0,0,0,1,4])
	host.net.queue_frames(actor,[jump_frame,jump_frame])
	check(actor.input_queue.size()==1,"Retransmitted jump is queued once")
	host.net.queue_frames(actor,[PackedFloat64Array([sequence+1,NAN,0,0,0,1,0])])
	check(actor.input_queue.size()==1,"Invalid movement input is rejected")
	host.net.queue_frames(actor,[PackedFloat64Array([sequence+240,0,0,0,0,1,0])])
	check(actor.input_queue.size()==2,"Inputs recover after a long gap without permanent sequence rejection")
	client.net.leave_game()
	host.net.leave_game()
	await create_timer(0.2).timeout
	print("Network motion: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
