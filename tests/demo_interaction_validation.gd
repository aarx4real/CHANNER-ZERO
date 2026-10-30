extends SceneTree
var failures := 0
var scene: Node3D
var demo: Node
var player: CharacterBody3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok: failures += 1
func aim(body: Node3D, floor_height: float = 0.0) -> void:
	player.global_position = body.global_position + body.global_basis.z * 1.65
	player.global_position.y = floor_height
	player.velocity = Vector3.ZERO
	player.camera.look_at(body.global_position)
	await physics_frame
	await physics_frame
	check(demo.ray_target() == body, "Ray reaches " + str(body.get_path()))
func use(body: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		demo.interact(body)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await physics_frame
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		Input.parse_input_event(key)
		await physics_frame
		await physics_frame
		key.pressed = false
		Input.parse_input_event(key)
func target(action: String, index: int = 0) -> Node3D:
	for body in demo.targets:
		if demo.targets[body].action == action and demo.targets[body].index == index: return body
	return null
func run() -> void:
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	demo = scene.get_node("FirstBroadcast")
	player = demo.player
	player.set_physics_process(false)
	await physics_frame
	check(not player.hands.visible, "Identity hidden at start")
	var fuse := target("fuse",1)
	demo.interact(fuse)
	check(demo.fuses.is_empty(), "Cannot collect before admission")
	demo.television.activate()
	await create_timer(2).timeout
	demo.gate.has_been_passed = true
	demo._on_gate_passed()
	for i in [3,1,2]:
		var body := target("fuse",i)
		await aim(body, 0.8 if i == 3 else 0.0)
		await use(body)
		check(i in demo.fuses, "Fuse collected with interaction " + str(i))
		demo.interact(body)
	check(demo.fuses.size() == 3, "Any order and duplicate protection")
	var power := target("power")
	await aim(power,0.7)
	await use(power)
	check(demo.powered and demo.locks[0].collision_layer == 0,"Power opens control door")
	for i in range(3):
		var tv: Node3D = scene.get_node("HauntedCarnival/StoryQuarter/ControlRoom/Channel1Television/Housing")
		await aim(tv)
		await use(tv)
	check(demo.channels_seen == 3 and demo.locks[1].collision_layer == 0,"Three channel interactions open backstage")
	var desk := target("records")
	await aim(desk)
	await use(desk)
	check(demo.modal.visible,"Archive ray opens puzzle UI")
	demo.select_record(4)
	check(demo.records_order.is_empty(),"Incorrect order recoverable")
	for i in range(5): demo.select_record(i)
	player.set_physics_process(false)
	check(demo.records_solved and demo.locks[2].collision_layer == 0,"Chronology opens final theatre")
	check(not player.hands.visible,"Hands still hidden after archive")
	demo.reveal()
	await create_timer(14.5).timeout
	player.set_physics_process(false)
	check(demo.revealed and player.hands.visible,"Timed reveal completes")
	var tv := target("ending")
	await aim(tv)
	await use(tv)
	check(demo.modal.visible,"Final television offers ending choices")
	var chosen := 1 if "--channel-one" in OS.get_cmdline_user_args() else 0
	demo.menu.get_child(chosen+1).pressed.emit()
	check(demo.ending == chosen,"Ending button selects channel " + str(chosen))
	check(not player.is_physics_processing(),"Ending freezes movement")
	demo.menu.get_child(1).pressed.emit()
	await process_frame
	await process_frame
	var fresh := current_scene.get_node("FirstBroadcast")
	check(fresh.ending == -1 and fresh.fuses.is_empty() and not fresh.television.has_activated,"Restart resets complete game")
	check(not fresh.player.hands.visible,"Restart conceals identity")
	print("DEMO INTERACTION VALIDATION: %d failures" % failures)
	quit(0 if failures == 0 else 1)
