extends SceneTree
var failures := 0
var scene: Node3D
var player: CharacterBody3D
var phase: Node
var tv: Node3D
var gate: Node3D
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:failures += 1
func pose(local_position: Vector3, target: Vector3) -> void:
	var booth: Node3D = scene.get_node("HauntedCarnival/TicketBooth")
	player.global_position = booth.to_global(local_position)
	player.velocity = Vector3.ZERO
	player.camera.look_at(target)
	await physics_frame
	await physics_frame
func push_gate(frames: int) -> void:
	for i in range(frames):
		await physics_frame
		player.velocity = -gate.global_basis.z*3.2+Vector3(0,-1,0)
		player.move_and_slide()
func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	player = scene.get_node("ScarecrowPlayer")
	player.set_physics_process(false)
	phase = scene.get_node("FirstBroadcast")
	tv = phase.television
	gate = phase.gate
	check(phase.current_objective == "Investigate the Ticket Booth","Initial objective")
	check(not tv.has_activated and not gate.is_open,"TV unplayed and gate locked at launch")
	check(InputMap.action_get_events("interact")[0].physical_keycode == KEY_E,"Physical E binding")
	check(not player.hands.is_visible_in_tree(),"Scarecrow identity remains hidden")
	player.global_position = gate.to_global(Vector3(0,0.05,2))
	await push_gate(90)
	check(gate.to_local(player.global_position).z > 0.35,"Closed gate physically blocks forward movement")
	check(phase.current_objective == "Investigate the Ticket Booth","Gate approach does not skip the TV")
	var screen_target: Vector3 = tv.to_global(Vector3(0,0.4,0.35))
	await pose(Vector3(1.65,0,2.7),screen_target)
	check(not phase.looking_at_television(),"TV requires close range")
	await pose(Vector3(3.35,0,-1.4),screen_target)
	check(not phase.looking_at_television(),"Booth wall occludes the ray")
	await pose(Vector3(1.65,0,0.4),screen_target)
	check(phase.looking_at_television(),"Looking at nearby TV is interactable")
	player.camera.look_at(player.camera.global_position+Vector3(0,0,3))
	await physics_frame
	check(not phase.looking_at_television(),"Looking away rejects interaction")
	await pose(Vector3(1.65,0,0.4),screen_target)
	var events: Array = []
	tv.activated.connect(func(): events.append(true))
	var booth_light: Light3D = scene.get_node("HauntedCarnival/TicketBooth/Interior")
	var initial_energy: float = booth_light.light_energy
	if DisplayServer.get_name() == "headless":
		# Dummy DisplayServer cannot capture a mouse; test the exact activation endpoint.
		check(tv.activate(),"First TV activation accepted")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await physics_frame
		await physics_frame
		check(phase.prompt.visible,"Press E prompt appears while aimed at TV")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		Input.parse_input_event(key)
		await physics_frame
		await physics_frame
		check(tv.has_activated,"Physical E input activates aimed-at TV")
	check(phase.current_objective == "Enter the Carnival","Admission advances objective")
	check(phase.broadcast_message.text == "GUEST NO. 001 — ADMITTED","Correct broadcast message")
	check(tv.screen_text.visible,"Admission appears on the TV")
	check(gate.is_opening and not gate.is_open,"Gate opening is animated")
	check(phase.flicker_elapsed >= 0.0 and not booth_light.is_processing(),"Brief local light event started")
	check(not tv.activate() and events.size() == 1,"TV event fires exactly once")
	await create_timer(2.1).timeout
	check(gate.is_open and not gate.is_opening,"Gate finishes opening")
	check(phase.flicker_elapsed < 0.0 and is_equal_approx(booth_light.light_energy,initial_energy),"Nearby lights restored")
	check(absf(gate.leaves[0].rotation.y-PI/2) < 0.01,"Left gate leaf reaches open pose")
	check(absf(gate.leaves[1].rotation.y+PI/2) < 0.01,"Right gate leaf reaches open pose")
	check(phase.current_objective == "Enter the Carnival","TV activation alone does not count as entering")
	check(not phase.looking_at_television(),"Used TV no longer offers interaction")
	player.global_position = gate.to_global(Vector3(0,0.05,2))
	await push_gate(120)
	check(gate.to_local(player.global_position).z < -3.0,"Open gate allows travel through its center")
	check(phase.current_objective == "Restore Power to the Carnival","Crossing gate advances final Phase 1 objective")
	check(gate.has_been_passed,"Crossing is latched once")
	check(not player.hands.is_visible_in_tree(),"No Scarecrow reveal triggered")
	print("FIRST BROADCAST VALIDATION COMPLETE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
