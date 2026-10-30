extends SceneTree
## Collision-based validation of the active, marker-authored carnival layout.
var failures: int = 0
var player: CharacterBody3D
var map: Node3D
var demo: Node
func use_action(action: String, index: int = 0) -> void:
	for body in demo.targets:
		var data: Dictionary = demo.targets[body]
		if data.action == action and (index == 0 or data.index == index):
			demo.interact(body)
			return
	check(false, "Missing action " + action)
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1
func walk_to(target: Vector3, label: String) -> void:
	for step in range(1200):
		await physics_frame
		var offset := target-player.position
		offset.y = 0.0
		if offset.length() < 0.18:
			check(player.is_on_floor() and absf(player.global_position.y-target.y) < 0.3,label)
			return
		player.velocity = offset.normalized()*5.6
		player.velocity.y = -1.0
		player.move_and_slide()
	check(false,label+" stopped at "+str(player.position)+" goal "+str(target))
func route(names: Array, prefix: String) -> void:
	for name in names:
		var waypoint: Marker3D = map.get_node(name+"Waypoint")
		await walk_to(waypoint.global_position,prefix+" / "+name)
func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	map = scene.get_node("HauntedCarnival")
	player = scene.get_node("ScarecrowPlayer")
	player.set_physics_process(false)
	for i in range(30):
		await physics_frame
		player.velocity = Vector3(0,-2,0)
		player.move_and_slide()
	check(player.is_on_floor(),"Entrance spawn has floor collision")
	check(not player.hands.is_visible_in_tree(),"Hands remain hidden")
	check(ProjectSettings.get_setting("application/config/name") == "CHANNEL ZERO","Project identity retained")
	await route(["EntranceGate","EntranceInside","TicketApproach","TicketInterior"],"Entrance and ticket office")
	# The layout regression now completes Phase 1 before exploring the unlocked map.
	# Dedicated first_broadcast_validation.gd tests ray occlusion and physical E input.
	var phase = scene.get_node("FirstBroadcast")
	demo = phase
	phase.television.activate()
	await create_timer(2.1).timeout
	await route(["TicketApproach","EntranceInside"],"Return to admission checkpoint")
	await walk_to(phase.gate.to_global(Vector3(0,0,2.5)),"Working gate approach")
	await walk_to(phase.gate.to_global(Vector3(0,0,-3.5)),"Cross opened admission gate")
	await route(["HubSouth"],"Enter midway after first broadcast")
	await route(["HubWest","MirrorApproach","MirrorEntry","MirrorCourt","Fuse1Standoff"],"Reach fuse one")
	use_action("fuse",1)
	await route(["MirrorExit","MirrorReturn","MirrorHubReturn","HubNorth"],"Route A loop")
	check(map.has_node("MirrorRoute/Fuse1PickupMarker"),"Fuse 1 marker retained")
	await route(["HubEast","PrizeApproach","PrizeEntry","PrizeCourt","Fuse2Standoff"],"Reach fuse two")
	use_action("fuse",2)
	await route(["PrizeExit","PrizeReturn","PrizeHubReturn","HubNorth"],"Route B loop")
	check(map.has_node("PrizeRoute/Fuse2PickupMarker"),"Fuse 2 marker retained")
	await route(["ServiceApproach","ServiceRampFoot","ServiceRampTop","ServiceDoorApproach","ServiceInterior","Fuse3Standoff"],"Route C outbound")
	use_action("fuse",3)
	check(demo.fuses.size() == 3,"Three fuses collected")
	check(player.position.y > 0.7,"Service branch has accessible elevation change")
	await route(["ServiceInterior","ServiceDoorApproach","ServiceWestYard","ServiceWestRampFoot","ServiceReturn","ServiceHubReturn","HubNorth"],"Route C return loop")
	check(map.has_node("PowerShed/ChannelZeroFoundation/Fuse3PickupMarker"),"Fuse 3 marker retained")
	await route(["StageApproach","StageRampFoot","StageDeck"],"Main stage")
	use_action("power")
	check(demo.powered,"Stage power restored")
	await create_timer(1.1).timeout
	check(player.position.y > 0.6,"Main stage ramp works")
	await route(["StageRampFoot","StageDeparture","ControlApproach","ControlInterior"],"Story quarter approach")
	use_action("channel")
	use_action("channel")
	use_action("channel")
	check(demo.channels_seen == 3,"Channels unlock backstage")
	await create_timer(1.1).timeout
	await route(["ControlWestDoor","BackstageTurn","BackstageNorth","OfficeInterior"],"Reach owner archive")
	demo.select_record(3)
	check(demo.records_order.is_empty(),"Wrong order resets safely")
	for i in range(5): demo.select_record(i)
	check(demo.records_solved,"Chronology solved")
	player.set_physics_process(false)
	await create_timer(1.1).timeout
	await route(["OfficeExit","TheatreSideEntry","TheatreAudience","TheatreRampFoot","TheatreStage"],"Focused story path")
	await create_timer(15.0).timeout
	player.set_physics_process(false)
	check(demo.revealed and player.hands.visible,"Final reveal shows hands only now")
	await route(["TheatreRampReturn","TheatreAisle","TheatreSideAisle","TheatreRearExit","EndingInterior","EndingChoice"],"Separate ending room")
	check(map.has_node("StoryQuarter/EndingRoom/EndingChoiceMarker"),"Ending room and choice marker")
	demo.finish(0)
	check(demo.ending == 0 and demo.modal.visible,"Channel zero ending")
	# A fresh state is used for the second ending assertion below.
	demo.ending = -1
	demo.finish(1)
	check(demo.ending == 1 and demo.modal.visible,"Channel one ending")
	demo.close_menu()
	player.set_physics_process(false)
	await route(["EndingInterior","TheatreRearExit","TheatreSideAisle","TheatreAisle","TheatreAudience","TheatreSideEntry","OfficeExit","OfficeInterior","BackstageNorth","BackstageTurn","ControlWestDoor","ControlInterior","ControlApproach","StageDeparture","StageApproach","HubNorth","HubWest","HubSouth","EntranceInside","EntranceGate","EntranceOutside"],"Full return route")
	# Probe a new room's solid back wall using the same capsule.
	player.global_position = map.get_node("ControlInteriorWaypoint").global_position+Vector3(0,0.1,0)
	var body_origin: Vector3 = player.global_position
	var forward: Vector3 = -map.get_node("StoryQuarter").global_basis.z
	for i in range(120):
		await physics_frame
		player.velocity = forward*5.6+Vector3(0,-1,0)
		player.move_and_slide()
	check(player.global_position.distance_to(body_origin) < 6.0,"Control room wall blocks the player")
	check(scene.get_node("WorldEnvironment").environment.sky != null,"Moon and outdoor sky preserved")
	if DisplayServer.get_name() != "headless":
		player.global_position = map.get_node("HubSouthWaypoint").global_position+Vector3(0,0.1,0)
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.action_press("move_forward")
		for i in range(60):
			await physics_frame
			player._physics_process(1.0/60.0)
		check(player.velocity.z < -3.0,"Existing WASD movement")
		Input.action_press("sprint")
		for i in range(45):
			await physics_frame
			player._physics_process(1.0/60.0)
		check(player.velocity.z < -5.5,"Existing sprint")
		Input.action_release("move_forward")
		Input.action_release("sprint")
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(40,20)
		player._unhandled_input(mouse)
		check(player.rotation.y != 0 and player.camera.rotation.x != 0,"Existing mouse look")
		var escape := InputEventAction.new()
		escape.action = "toggle_mouse_capture"
		escape.pressed = true
		player._unhandled_input(escape)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Escape releases cursor")
		player._unhandled_input(escape)
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"Escape recaptures cursor")
	print("DEMO NAVIGATION VALIDATION COMPLETE: %d failures" % failures)
	quit(0 if failures == 0 else 1)

