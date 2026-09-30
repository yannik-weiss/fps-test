extends Node

const PORT := 27841
const DISCOVERY_PORT := 27842
const VERSION := "aschenmark-lan-1"
var world: Node3D
var running := false
var hosting := false
var connecting := false
var peer: ENetMultiplayerPeer
var discovery := PacketPeerUDP.new()
var rounds: Dictionary = {}
var actors: Dictionary = {}
var send_clock := 0.0
var discover_clock := 0.0
var connection_clock := 0.0
var room_name := "Aschenmark"
var player_name := "Wanderer"
var lobby: PanelContainer
var status: Label
var address: LineEdit
var nickname: LineEdit
var rooms: ItemList
var room_addresses: Array[String] = []
var pending_jump := false
var snapshot_sequence := 0
var received_sequence := -1

func _ready() -> void:
	world = get_parent()
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(on_connection_failed)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	build_lobby()

func build_lobby() -> void:
	lobby = PanelContainer.new()
	lobby.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lobby.position = Vector2(-340,-300)
	lobby.size = Vector2(680,600)
	lobby.add_theme_stylebox_override("panel",world.panel_style(Color("111e20")))
	world.menu.get_parent().add_child(lobby)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	lobby.add_child(column)
	column.add_child(world.label("GRENZLANDE · LAN PvPvE",28))
	column.add_child(world.label("Gemeinsam erkunden. Gegen Ritter und Mitspieler kämpfen.\nBis zu 8 Spieler · Lager als Schutzzone · Respawn am Lager",16))
	nickname = LineEdit.new()
	nickname.text = "Wanderer"
	nickname.placeholder_text = "Dein Name"
	column.add_child(nickname)
	var host_button := Button.new()
	host_button.text = "LAN-Runde eröffnen"
	host_button.pressed.connect(func(): host_game(nickname.text))
	column.add_child(host_button)
	rooms = ItemList.new()
	rooms.custom_minimum_size.y = 160
	rooms.item_activated.connect(func(index: int): join_game(room_addresses[index],nickname.text))
	column.add_child(rooms)
	var join_button := Button.new()
	join_button.text = "Ausgewählte Runde betreten"
	join_button.pressed.connect(func():
		var selected := rooms.get_selected_items()
		if not selected.is_empty(): join_game(room_addresses[selected[0]],nickname.text))
	column.add_child(join_button)
	address = LineEdit.new()
	address.placeholder_text = "Direkt verbinden: lokale IPv4-Adresse, z. B. 192.168.1.20"
	column.add_child(address)
	var direct_button := Button.new()
	direct_button.text = "Mit IP verbinden"
	direct_button.pressed.connect(func(): join_game(address.text.strip_edges(),nickname.text))
	column.add_child(direct_button)
	status = world.label("",15)
	column.add_child(status)
	var back := Button.new()
	back.text = "Zurück / Runde verlassen"
	back.pressed.connect(func():
		if running or connecting:
			leave_game()
			world.get_tree().reload_current_scene()
		else:
			lobby.hide()
			discovery.close()
			world.menu.show())
	column.add_child(back)
	lobby.hide()

func open_lobby() -> void:
	world.player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.menu.hide()
	world.hud.hide()
	lobby.show()
	if running:
		status.text="Runde läuft · %d/8 · %s" % [actors.size(),local_addresses() if hosting else "Verbunden"]
	if not running:
		discovery.close()
		var error := discovery.bind(0,"0.0.0.0")
		discovery.set_broadcast_enabled(true)
		status.text = "Suche nach Runden im LAN …" if error == OK else "LAN-Suche nicht verfügbar. Nutze die direkte IP."
		discover_clock = 2

func host_game(display_name: String, bind_ip := "0.0.0.0") -> Error:
	if running or connecting:
		status.text="Verlasse zuerst die aktuelle Runde."
		return ERR_ALREADY_IN_USE
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var error := peer.create_server(PORT,7)
	if error != OK:
		status.text = "Runde konnte nicht geöffnet werden: " + error_string(error)
		return error
	multiplayer.multiplayer_peer = peer
	running = true
	hosting = true
	player_name = clean_name(display_name)
	room_name = player_name + "s Grenzlande"
	world.player.wood=world.wood
	world.player.ore=world.ore
	world.player.gold=world.gold
	actors[1] = world.player
	world.player.peer_id = 1
	world.player.display_name = player_name
	discovery.close()
	if discovery.bind(DISCOVERY_PORT,bind_ip) != OK:
		world.notify("LAN-Suche nicht verfügbar; Mitspieler können per IP beitreten.",5)
	lobby.hide()
	world.start_or_resume()
	world.notify("LAN-Runde geöffnet · " + local_addresses(),5)
	return OK

func join_game(ip: String, display_name: String) -> Error:
	if running or connecting:
		status.text="Verlasse zuerst die aktuelle Runde oder warte auf die Verbindung."
		return ERR_ALREADY_IN_USE
	if not is_local_address(ip):
		status.text = "Bitte eine lokale IPv4-Adresse eingeben."
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(ip,PORT)
	if error != OK:
		status.text = "Verbindung nicht möglich: " + error_string(error)
		return error
	player_name = clean_name(display_name)
	multiplayer.multiplayer_peer = peer
	connecting = true
	connection_clock = 0
	status.text = "Verbinde mit " + ip + " …"
	return OK

static func is_local_address(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size()!=4: return false
	for part in parts:
		if not part.is_valid_int() or int(part)<0 or int(part)>255: return false
	return int(parts[0])==10 or int(parts[0])==127 or (int(parts[0])==192 and int(parts[1])==168) or (int(parts[0])==172 and int(parts[1])>=16 and int(parts[1])<=31) or (int(parts[0])==169 and int(parts[1])==254)

func clean_name(value: String) -> String:
	return value.strip_edges().left(24) if not value.strip_edges().is_empty() else "Wanderer"

func local_addresses() -> String:
	var found := PackedStringArray()
	for ip in IP.get_local_addresses():
		if is_local_address(ip) and not ip.begins_with("127."): found.append(ip)
	return ", ".join(found)

func _process(delta: float) -> void:
	poll_discovery(delta)
	if connecting:
		connection_clock += delta
		if connection_clock>8: on_connection_failed()
	if not running: return
	send_clock += delta
	if send_clock<0.05: return
	send_clock = 0
	if hosting:
		broadcast_snapshot()
	else:
		var p = world.player
		var move := Input.get_vector("left","right","forward","back") if p.active and p.alive else Vector2.ZERO
		submit_input.rpc_id(1,move,p.rotation.y,p.camera.rotation.x,p.selected_direction,p.active and Input.is_action_pressed("block"),p.active and Input.is_action_pressed("sprint"),pending_jump)
		pending_jump = false

func poll_discovery(delta: float) -> void:
	if not discovery.is_bound(): return
	var limit := 32
	while discovery.get_available_packet_count()>0 and limit>0:
		limit -= 1
		var packet := discovery.get_packet()
		var ip := discovery.get_packet_ip()
		var port := discovery.get_packet_port()
		if packet.size()>512 or not is_local_address(ip): continue
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if not data is Dictionary or data.get("version","")!=VERSION: continue
		if hosting and data.get("kind","")=="search":
			discovery.set_dest_address(ip,port)
			discovery.put_packet(JSON.stringify({"version":VERSION,"kind":"room","name":room_name,"players":actors.size()}).to_utf8_buffer())
		elif not hosting and data.get("kind","")=="room":
			rounds[ip] = {"name":str(data.get("name","Runde")).left(40),"players":clampi(int(data.get("players",0)),0,8),"seen":Time.get_ticks_msec()}
			refresh_rooms()
	if hosting or not lobby.visible: return
	discover_clock += delta
	if discover_clock>=2:
		discover_clock=0
		for target in ["255.255.255.255","127.0.0.1"]:
			discovery.set_dest_address(target,DISCOVERY_PORT)
			discovery.put_packet(JSON.stringify({"version":VERSION,"kind":"search"}).to_utf8_buffer())
		for ip in rounds.keys():
			if Time.get_ticks_msec()-rounds[ip].seen>6000: rounds.erase(ip)
		refresh_rooms()

func refresh_rooms() -> void:
	var selected_address := ""
	var selected := rooms.get_selected_items()
	if not selected.is_empty() and selected[0]<room_addresses.size(): selected_address=room_addresses[selected[0]]
	rooms.clear()
	room_addresses.clear()
	for ip in rounds:
		room_addresses.append(ip)
		rooms.add_item("%s · %d/8 · %s" % [rounds[ip].name,rounds[ip].players,ip])
		if ip==selected_address: rooms.select(rooms.item_count-1)

func on_peer_connected(id: int) -> void:
	if hosting:
		if not is_local_address(peer.get_peer(id).get_remote_address()):
			peer.disconnect_peer(id)
			return
		spawn_actor(id,"Wanderer")

func spawn_actor(id: int, display_name: String) -> void:
	if actors.has(id): return
	var actor = world.PlayerScript.new()
	actor.name = "Peer_%d" % id
	actor.local_control = false
	actor.peer_id = id
	actor.display_name = display_name
	actor.position = Vector3((actors.size()%4)*1.3-2,0.1,15)
	world.add_child(actor)
	actor.active = true
	actors[id] = actor

func on_connected() -> void:
	connecting=false
	running=true
	hosting=false
	world.player.peer_id=multiplayer.get_unique_id()
	world.player.display_name=player_name
	actors[world.player.peer_id]=world.player
	for enemy in enemies_in_world(): enemy.ai_enabled=false
	register_name.rpc_id(1,player_name,VERSION)
	lobby.hide()
	discovery.close()
	world.start_or_resume()
	world.notify("LAN verbunden · PvPvE außerhalb des Lagers",4)

@rpc("any_peer","call_remote","reliable")
func register_name(value: String, version: String) -> void:
	if not hosting: return
	var id := multiplayer.get_remote_sender_id()
	if not actors.has(id): return
	if version!=VERSION:
		peer.disconnect_peer(id)
		return
	actors[id].display_name=clean_name(value)

func on_peer_disconnected(id: int) -> void:
	if actors.has(id):
		actors[id].queue_free()
		actors.erase(id)
	if running: world.notify("Ein Mitspieler hat die Runde verlassen.")

func on_connection_failed() -> void:
	leave_game()
	status.text="Keine Verbindung. IP, gleiche Spielversion und Firewall prüfen."
	lobby.show()

func on_server_disconnected() -> void:
	leave_game()
	world.show_menu("VERBINDUNG GETRENNT","Der Gastgeber hat die LAN-Runde verlassen.\nKehre zur LAN-Liste zurück oder starte ein Einzelspiel.","Einzelspiel neu starten")
	world.player.alive=false

func leave_game() -> void:
	running=false
	connecting=false
	hosting=false
	discovery.close()
	if peer: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for id in actors:
		if actors[id]!=world.player: actors[id].queue_free()
	actors.clear()

func _exit_tree() -> void:
	discovery.close()
	if peer: peer.close()

@rpc("any_peer","call_remote","unreliable_ordered",1)
func submit_input(move: Vector2, yaw: float, pitch: float, direction: int, block: bool, sprint: bool, jump: bool) -> void:
	if not hosting: return
	var id := multiplayer.get_remote_sender_id()
	if not actors.has(id) or not move.is_finite() or not is_finite(yaw) or not is_finite(pitch): return
	var actor = actors[id]
	actor.net_move=move.limit_length(1)
	actor.rotation.y=wrapf(yaw,-PI,PI)
	actor.camera.rotation.x=clampf(pitch,-1.25,1.25)
	actor.select_direction(clampi(direction,0,3))
	actor.net_block=block
	actor.net_sprint=sprint
	actor.net_jump=actor.net_jump or jump
	actor.input_age=0

func command(action: String, direction := 1) -> void:
	if running and not hosting: request_action.rpc_id(1,action,direction,world.player.rotation.y,world.player.camera.rotation.x)

@rpc("any_peer","call_remote","reliable",2)
func request_action(action: String, direction: int, yaw: float, pitch: float) -> void:
	if not hosting: return
	var id := multiplayer.get_remote_sender_id()
	if not actors.has(id): return
	if not is_finite(yaw) or not is_finite(pitch): return
	var actor = actors[id]
	actor.rotation.y=wrapf(yaw,-PI,PI)
	actor.camera.rotation.x=clampf(pitch,-1.25,1.25)
	match action:
		"attack":
			actor.select_direction(clampi(direction,0,3))
			actor.attack(true)
		"release": actor.release_requested=true
		"feint": actor.feint()
		"interact": interact_as(actor)
		"respawn": respawn(actor)

func respawn(actor: Node3D) -> void:
	if actor.alive: return
	actor.health=100
	actor.stamina=100
	actor.collision_layer=1
	actor.collision_mask=1
	actor.alive=true
	actor.active=true
	actor.position=Vector3(0,0.1,13)
	actor.velocity=Vector3.ZERO
	actor.knockback=Vector3.ZERO
	actor.winding=false
	actor.blocking=false
	actor.cooldown=0.5

func safe_zone(pos: Vector3) -> bool:
	return Vector2(pos.x,pos.z-10).length()<10

func combatants() -> Array:
	return actors.values() if running else [world.player]

func resolve_attack(attacker: Node3D) -> void:
	var candidates: Array = enemies_in_world()
	candidates.append_array(actors.values())
	var target: Node3D = null
	var nearest := 3.5 if attacker.attack_direction==3 else 3.1
	var origin: Vector3=attacker.camera.global_position
	var forward: Vector3=-attacker.camera.global_transform.basis.z
	for candidate in candidates:
		if candidate==attacker or not candidate.alive: continue
		if candidate in actors.values() and (safe_zone(candidate.position) or safe_zone(attacker.position)): continue
		var offset: Vector3=candidate.position+Vector3.UP-origin
		if offset.length()<nearest and forward.dot(offset.normalized())>(0.86 if attacker.attack_direction==3 else 0.64) and world.clear_line(origin,candidate.position+Vector3.UP,[attacker.get_rid(),candidate.get_rid()]):
			nearest=offset.length()
			target=candidate
	if target:
		var old_health: float=target.health
		if target in actors.values(): target.take_damage(28 if attacker.weapon_level==1 else 45,attacker.position,world.PlayerScript.Combat.incoming(attacker.attack_direction))
		else: target.receive_attack(28 if attacker.weapon_level==1 else 45,attacker.attack_direction,attacker.position,attacker)
		if target in actors.values():
			attacker.feedback("TREFFER" if target.health<old_health else "GEGNER BLOCKT","hit" if target.health<old_health else "block")
	else: attacker.feedback("VERFEHLT","miss")

func interact_as(actor: Node3D) -> void:
	if not actor.alive: return
	var original = world.player
	var old_focus: Dictionary = world.focus
	world.player=actor
	world.find_focus()
	var item: Dictionary=world.focus
	world.player=original
	world.focus=old_focus
	if item.is_empty(): return
	match item.kind:
		"wood", "ore", "loot":
			if item.get("used",false): return
			item.used=true
			item.node.hide()
			if item.kind=="wood": actor.wood+=1
			elif item.kind=="ore": actor.ore+=1
			else: actor.gold+=item.amount
			actor.feedback("BEUTE · "+str(item.kind),"feint")
		"forge":
			if actor.weapon_level==1 and actor.wood>=2 and actor.ore>=2:
				actor.wood-=2
				actor.ore-=2
				actor.weapon_level=2
				actor.feedback("KLINGE VERSTÄRKT","parry")
			else: actor.feedback("Schmiede: 2 Holz + 2 Erz; Verbesserung nur einmal.","miss")
		"fire":
			for enemy in enemies_in_world():
				if enemy.alive and enemy.position.distance_to(actor.position)<12: return
			actor.health=100
			actor.stamina=100
			if world.boss_dead:
				world.victory=true
				actor.feedback("DER PASS IST FREI · Siegel abgegeben","parry")
			else: actor.feedback("AM FEUER ERHOLT","parry")
	world.wood=original.wood
	world.ore=original.ore
	world.gold=original.gold
	world.update_stats()

func broadcast_snapshot() -> void:
	snapshot_sequence+=1
	var players: Dictionary={}
	for id in actors:
		var p=actors[id]
		players[id]={"pos":p.position,"yaw":p.rotation.y,"hp":p.health,"stamina":p.stamina,"alive":p.alive,"weapon":p.weapon_level,"name":p.display_name,"wood":p.wood,"ore":p.ore,"gold":p.gold,"guard":p.guard_direction,"attack":p.attack_direction,"block":p.blocking,"winding":p.winding,"swing":p.swing_time}
	var enemies: Array=[]
	for enemy in enemies_in_world():
		enemies.append({"pos":enemy.position,"yaw":enemy.rotation.y,"hp":enemy.health,"alive":enemy.alive,"stamina":enemy.stamina,"attack":enemy.attack_direction,"block":enemy.blocking,"guard":enemy.guard_direction,"winding":enemy.attacking,"swing":enemy.swing_time,"blade_pos":enemy.blade.position,"blade_rot":enemy.blade.rotation})
	var items: Array=[]
	for resource in world.resources:
		items.append({"kind":resource.kind,"pos":resource.pos,"used":resource.get("used",false),"amount":resource.get("amount",0)})
	receive_snapshot.rpc(snapshot_sequence,players,enemies,items,world.boss_dead,world.kills,world.victory)

@rpc("authority","call_remote","reliable",3)
func receive_snapshot(sequence: int, players: Dictionary, enemies: Array, items: Array, boss_dead: bool, kills: int, victory: bool) -> void:
	if hosting or sequence<=received_sequence: return
	received_sequence=sequence
	var my_id := multiplayer.get_unique_id()
	for id in players:
		if not actors.has(id): spawn_actor(id,players[id].name)
		var p=actors[id]
		var data: Dictionary=players[id]
		if id!=my_id:
			var old_position: Vector3=p.position
			p.position=data.pos
			if is_instance_valid(p.avatar): p.avatar.position += old_position-data.pos
			p.rotation.y=data.yaw
			p.blocking=data.block
			p.guard_direction=data.guard
			p.attack_direction=data.attack
			p.winding=data.winding
			p.swing_time=data.swing
		elif p.position.distance_to(data.pos)>0.3:
			p.position=p.position.lerp(data.pos,0.6)
		var was_alive: bool=p.alive
		p.health=data.hp
		p.stamina=data.stamina
		p.alive=data.alive
		p.collision_layer=1 if p.alive else 0
		p.collision_mask=1 if p.alive else 0
		p.weapon_level=data.weapon
		p.display_name=data.name
		p.wood=data.wood
		p.ore=data.ore
		p.gold=data.gold
		if id==my_id and was_alive and not p.alive: world.on_death()
		if id==my_id and not was_alive and p.alive:
			p.position=data.pos
			world.start_or_resume()
	for id in actors.keys():
		if not players.has(id):
			actors[id].queue_free()
			actors.erase(id)
	var nodes := enemies_in_world()
	for i in mini(enemies.size(),nodes.size()):
		var e=nodes[i]
		var d: Dictionary=enemies[i]
		if not e.alive and d.alive:
			e.collision_layer=1
			e.collision_mask=1
			e.body.rotation=Vector3.ZERO
			e.body.position=Vector3.ZERO
		if e.alive and not d.alive:
			e.health=1
			e.take_damage(2)
		e.position=d.pos
		e.rotation.y=d.yaw
		e.health=d.hp
		e.alive=d.alive
		e.blocking=d.block
		e.guard_direction=d.guard
		e.attack_direction=d.attack
		e.attacking=d.winding
		e.swing_time=d.swing
		e.blade.position=d.blade_pos
		e.blade.rotation=d.blade_rot
		e.bar.scale.x=maxf(0.01,e.health/(180.0 if e.boss else 85.0))
		e.bar.visible=e.alive and e.position.distance_to(world.player.position)<13
		e.direction_label.visible=e.alive and (e.blocking or e.attacking)
		e.direction_label.text=("BLOCK "+world.PlayerScript.Combat.NAMES[world.PlayerScript.Combat.incoming(e.guard_direction)]) if e.blocking else world.PlayerScript.Combat.ARROWS[world.PlayerScript.Combat.incoming(e.attack_direction)]
		world.art.animate_arm(e.rig,e.blade)
	while world.resources.size()>items.size():
		var stale: Dictionary=world.resources.pop_back()
		if stale.kind=="loot": stale.node.queue_free()
	# Append server-ordered loot explicitly, including for late joiners.
	while world.resources.size()<items.size():
		var item: Dictionary=items[world.resources.size()]
		var bag: MeshInstance3D=world.cylinder(world,0.25,0.17,0.3,item.pos+Vector3(0,0.18,0),world.brass)
		world.resources.append({"kind":item.kind,"pos":item.pos,"node":bag,"used":item.used,"amount":item.amount})
	for i in mini(items.size(),world.resources.size()):
		world.resources[i]["used"]=items[i].used
		if world.resources[i].has("node") and items[i].kind not in ["fire"]:
			world.resources[i].node.visible=not items[i].used
	world.victory=victory
	world.boss_dead=boss_dead
	world.kills=kills
	world.wood=world.player.wood
	world.ore=world.player.ore
	world.gold=world.player.gold
	world.update_stats()

@rpc("authority","call_remote","reliable",4)
func receive_feedback(text: String, kind: String) -> void:
	world.combat_feedback(text,kind)
	if kind=="hurt":
		world.player.winding=false
		world.player.stagger=0.18
		world.player.cooldown=maxf(world.player.cooldown,0.3)
		world.player.hurt_time=0.5
		world.player.shake=1
	elif kind in ["block","parry","hit"]:
		if kind in ["block","parry"]: world.impact(world.player.camera.global_position-world.player.camera.global_transform.basis.z*0.7,true)
		world.player.recoil=0.8
		world.player.shake=0.4

func enemies_in_world() -> Array:
	var found: Array=[]
	for node in world.get_tree().get_nodes_in_group("enemies"):
		if node.get_parent()==world: found.append(node)
	return found
