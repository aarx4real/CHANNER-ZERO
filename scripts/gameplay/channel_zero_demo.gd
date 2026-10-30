extends "res://scripts/gameplay/first_broadcast.gd"
## Complete demo progression. The map and controller remain independently reusable.
const CHANNELS = ["THE PAST\nMidnight Carnival, 1985. The Living Picture promised a show that would never end.", "THE FINAL NIGHT\n1987. The televisions predicted tomorrow. Then tomorrow stopped arriving.", "THE OTHER PERSPECTIVE\nSomething watched us through the glass. The owner kept the original recordings backstage."]
const RECORDS = ["1983 — The Living Picture experiment begins.", "1984 — Screens show alternate realities.", "1985 — Broadcasts predict the future.", "1986 — A Scarecrow appears in the broadcasts.", "1987 — Midnight Carnival disappears."]
var fuses: Array[int] = []
var powered := false
var channels_seen := 0
var records_order: Array[int] = []
var records_solved := false
var revealed := false
var revealing := false
var ending := -1
var targets: Dictionary = {}
var locks: Array[StaticBody3D] = []
var modal: PanelContainer
var menu: VBoxContainer
var counter: Label
var mannequin_pending := false
var sound: AudioStreamPlayer
var mirror_shadow: Node3D
@onready var map: Node3D = get_node("../HauntedCarnival")

func _ready() -> void:
	super._ready()
	sound = AudioStreamPlayer.new()
	sound.volume_db = -22
	add_child(sound)
	mirror_shadow = map.get_node("PrizeRoute/MannequinDisplay0").duplicate()
	map.get_node("MirrorRoute").add_child(mirror_shadow)
	mirror_shadow.position = Vector3(2,0,-2)
	mirror_shadow.hide()
	broadcast_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	broadcast_message.offset_left = -440
	broadcast_message.offset_right = 440
	broadcast_message.add_theme_color_override("font_shadow_color", Color.BLACK)
	counter = Label.new()
	$HUD.add_child(counter)
	counter.position = Vector2(20, 145)
	counter.add_theme_font_size_override("font_size", 20)
	for i in range(1, 4):
		var base: Node3D = map.get_node(["MirrorRoute", "PrizeRoute", "PowerShed/ChannelZeroFoundation"][i-1])
		var prop: MeshInstance3D = base.get_node("FusePlaceholder%d" % i)
		var body := StaticBody3D.new()
		base.add_child(body)
		body.position = prop.position
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.35, 0.3, 0.35)
		shape.shape = box
		body.add_child(shape)
		register(body, "Collect fuse %d" % i, "fuse", i, prop)
		base.get_node("FuseSign%d" % i).text = "FUSE %d" % i
	register(map.get_node("MainStage/StageTelevision/Housing"), "Install fuses / Restore power", "power")
	for i in range(1, 4):
		register(map.get_node("StoryQuarter/ControlRoom/Channel%dTelevision/Housing" % i), "Tune next channel", "channel")
	register(map.get_node("StoryQuarter/OwnersOffice/Desktop"), "Examine recordings", "records")
	register(map.get_node("StoryQuarter/EndingRoom/EndingTelevision/Housing"), "Choose final channel", "ending")
	add_lock("StoryQuarter/ControlRoom", Vector3(0,1.3,6), Vector3(3.2,2.6,0.22), "POWER REQUIRED")
	add_lock("StoryQuarter/ControlRoom", Vector3(-6,1.3,-2), Vector3(0.22,2.6,3.2), "VIEW THREE CHANNELS")
	add_lock("StoryQuarter/OwnersOffice", Vector3(6,1.3,-2), Vector3(0.22,2.6,3.2), "RESTORE THE RECORDINGS")
	modal = PanelContainer.new()
	$HUD.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.position = Vector2(-380,-250)
	modal.custom_minimum_size = Vector2(760, 460)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	modal.add_child(menu)
	modal.hide()
	get_node("../HUD/Controls").text = "CHANNEL ZERO — THE AUDIENCE IS STILL WATCHING.\nWASD Move   Shift Sprint   E Interact   Esc Cursor"

func register(body: Node3D, title: String, action: String, index: int = 0, prop: Node3D = null) -> void:
	targets[body] = {"title":title, "action":action, "index":index, "prop":prop}

func add_lock(path: String, pos: Vector3, size: Vector3, title: String) -> void:
	var body := StaticBody3D.new()
	map.get_node(path).add_child(body)
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = preload("res://materials/pbr/rusty_metal_02.tres")
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	register(body, title, "locked")
	locks.append(body)

func unlock(index: int) -> void:
	var body := locks[index]
	body.collision_layer = 0
	targets.erase(body)
	var tween := create_tween()
	tween.tween_property(body, "position:y", body.position.y + 3.2, 1.0)

func ray_target() -> Node:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin-camera.global_basis.z*interaction_distance, 1, [player.get_rid()])
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider")

func _physics_process(_delta: float) -> void:
	if modal.visible or revealing or ending >= 0:
		interaction_requested = false
		prompt.hide()
		return
	var target := ray_target()
	var is_tv: bool = target == television.get_node("Housing") and not television.has_activated
	var available: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (is_tv or targets.has(target))
	prompt.visible = available
	if available:
		prompt.text = "Press E to Interact" if is_tv else "E — " + str(targets[target].title)
	if interaction_requested:
		interaction_requested = false
		if available:
			if is_tv: television.activate()
			else: interact(target)
	counter.text = "Fuses: %d/3" % fuses.size() if television.has_activated and not powered else ""
	if mannequin_pending:
		var mannequin: Node3D = map.get_node("PrizeRoute/MannequinDisplay0")
		var direction := (mannequin.global_position-camera.global_position).normalized()
		if direction.dot(-camera.global_basis.z) < 0.1:
			mannequin.position += Vector3(1.5,0,1.5)
			mannequin_pending = false
			play_noise(0.2, 95.0)
	if records_solved and not revealed and not revealing:
		var theatre: Node3D = map.get_node("StoryQuarter/FinalTheatre")
		var local := theatre.to_local(player.global_position)
		if absf(local.x) < 13 and local.z < 12 and local.z > -14:
			reveal()

func interact(target: Node) -> void:
	if not targets.has(target): return
	var data: Dictionary = targets[target]
	match data.action:
		"fuse":
			if not gate.has_been_passed:
				say("Return to the Ticket Booth and enter through the admission gate.")
				return
			var index: int = data.index
			if index in fuses: return
			fuses.append(index)
			play_noise(0.5, 65.0 if index == 3 else 160.0)
			data.prop.hide()
			target.collision_layer = 0
			targets.erase(target)
			if index == 1:
				mirror_shadow.show()
				get_tree().create_timer(1.2).timeout.connect(mirror_shadow.hide)
				say("The reflection lingers after you turn away.\nFor a moment, someone is standing behind you.")
			if index == 2:
				mannequin_pending = true
				say("You could swear that figure was facing the other way.")
			if index == 3:
				flicker_room(map.get_node("PowerShed"))
				say("The generator shudders. There is no power here.")
			if fuses.size() == 3: objective("Restore Power at the Main Stage")
		"power":
			if powered: return
			if fuses.size() < 3:
				say("Three fuses required: Mirror Alley, Prize Stalls, Power Shed.")
				return
			powered = true
			unlock(0)
			light_tv(map.get_node("MainStage/StageTelevision"), "POWER RESTORED")
			objective("Explore the Television Control Room")
			say("Power restored. Broadcast Control is open, west of the stage.")
		"channel":
			if not powered: return
			var index := channels_seen % 3
			say(CHANNELS[index])
			light_tv(target.get_parent(), ["THE PAST", "THE FINAL NIGHT", "THE OTHER PERSPECTIVE"][index])
			play_noise(0.22, 800.0)
			channels_seen += 1
			if channels_seen == 3:
				unlock(1)
				objective("Find the Carnival Owner's Office")
		"records":
			if channels_seen < 3: return
			show_records()
		"ending":
			if not revealed:
				say("The final performance has not begun. Return to the theatre.")
				return
			open_menu("THE FINAL BROADCAST\nChoose what the audience sees next.")
			button("CHANNEL 0 — END TRANSMISSION", finish.bind(0))
			button("CHANNEL 1 — CONTINUE BROADCAST", finish.bind(1))
			button("Return", close_menu)
		"locked": say(data.title)

func objective(text: String) -> void:
	current_objective = text
	objective_label.text = text

func say(text: String) -> void:
	broadcast_message.text = text
	broadcast_message.show()
	message_elapsed = -6.0

func light_tv(tv: Node3D, text: String) -> void:
	var glass: MeshInstance3D = tv.get_node("Glass")
	var material := glass.get_active_material(0).duplicate() as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color(0.2,0.5,0.35)
	glass.material_override = material
	var label := tv.get_node_or_null("StoryText") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "StoryText"
		tv.add_child(label)
		label.position = Vector3(0,0.4,0.37)
		label.pixel_size = 0.001
		label.font_size = 28
	label.text = text

func flicker_room(room: Node) -> void:
	for node in room.find_children("*", "Light3D", true, false):
		var energy: float = node.light_energy
		var tween := create_tween()
		for i in range(5):
			tween.tween_property(node, "light_energy", 0.05, 0.08)
			tween.tween_property(node, "light_energy", energy, 0.12)

func open_menu(title: String) -> void:
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 740
	label.add_theme_font_size_override("font_size", 22)
	menu.add_child(label)
	modal.show()
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func button(text: String, action: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.pressed.connect(action)
	menu.add_child(item)

func close_menu() -> void:
	modal.hide()
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_records() -> void:
	open_menu("OWNER'S ARCHIVE — THE LIVING PICTURE\nSelect the recordings from earliest to latest.\nSelected: %d/5" % records_order.size())
	for index in [3,1,4,0,2]:
		button(("✓ " if index in records_order else "") + RECORDS[index], select_record.bind(index))
	button("Reset order", reset_records)
	button("Return to room", close_menu)

func select_record(index: int) -> void:
	if records_solved or index in records_order: return
	if index != records_order.size():
		records_order.clear()
		show_records()
		menu.get_child(0).text += "\nOut of sequence. Rewind — try the earliest year."
		return
	records_order.append(index)
	if records_order.size() == 5:
		records_solved = true
		unlock(2)
		close_menu()
		objective("Enter the Final Theatre")
		say("The final recording is your own voice. The theatre door opens.")
	else: show_records()

func reset_records() -> void:
	if records_solved: return
	records_order.clear()
	show_records()

func reveal() -> void:
	revealing = true
	play_noise(1.5, 45.0)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var tv: Node3D = map.get_node("StoryQuarter/FinalTheatre/FinalRevealFoundation/EndingTelevision")
	light_tv(tv, "THE HOLLOW HARVESTER")
	for line in ["YOU WERE NEVER THE INVESTIGATOR.", "YOU WERE THE THING THEY WERE WATCHING.", "YOU WEREN'T TRYING TO SURVIVE THE SHOW.", "YOU WERE REHEARSING FOR IT."]:
		say(line)
		await get_tree().create_timer(3.5).timeout
	player.get_node("Camera3D/ScarecrowHands").show()
	revealed = true
	revealing = false
	player.set_physics_process(true)
	objective("Choose a channel in the Final Television Room")
	say("The Hollow Harvester remembers.\nFollow the theatre's rear exit to the final television.")

func finish(channel: int) -> void:
	if not revealed or ending >= 0: return
	ending = channel
	if channel == 0:
		for light in map.get_node("StoryQuarter").find_children("*", "Light3D", true, false):
			light.set_process(false)
			light.light_energy = 0
	var text := "THANK YOU FOR WATCHING." if channel == 0 else "WE HAVE ANOTHER AUDIENCE MEMBER.\nBeyond the glass, a stranger watches you watching them."
	open_menu("CHANNEL %d\n\n%s\n\nTHE AUDIENCE IS STILL WATCHING." % [channel,text])
	button("Restart", restart)
	button("Quit", get_tree().quit)
	objective_label.hide()
	broadcast_message.hide()
	counter.hide()

func restart() -> void:
	get_tree().reload_current_scene()


func play_noise(duration: float, frequency: float) -> void:
	# Small generated electrical cue; no downloaded audio or ongoing generator cost.
	var samples := PackedByteArray()
	var count := int(22050 * duration)
	samples.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 1987
	for i in range(count):
		var t := float(i) / 22050.0
		var envelope := sin(PI * float(i) / count)
		var value := (sin(TAU * frequency * t) * 0.35 + random.randf_range(-0.3,0.3)) * envelope
		samples.encode_s16(i * 2, int(value * 22000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = samples
	sound.stream = stream
	sound.play()
