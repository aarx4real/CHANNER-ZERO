extends Node
## Phase 1 only: ray-based interaction, admission, gate and three objectives.
const INVESTIGATE := "Investigate the Ticket Booth"
const ENTER := "Enter the Carnival"
const RESTORE := "Restore Power to the Carnival"
@export_range(0.5, 5.0) var interaction_distance: float = 2.4
@export var player_path: NodePath = NodePath("../ScarecrowPlayer")
@export var television_path: NodePath = NodePath("../HauntedCarnival/TicketBooth/ChannelZeroFoundation/FirstHauntedTelevision")
@export var flicker_light_paths: Array[NodePath] = [
	NodePath("../HauntedCarnival/TicketBooth/Interior"),
	NodePath("../HauntedCarnival/Entrance/Lamp-5.5/Pool"),
	NodePath("../HauntedCarnival/Entrance/Lamp5.5/Pool")]
@onready var player: CharacterBody3D = get_node(player_path)
@onready var camera: Camera3D = player.get_node("Camera3D")
@onready var television: Node3D = get_node(television_path)
@onready var gate: Node3D = $Gate
@onready var objective_label: Label = $HUD/Objective
@onready var prompt: Label = $HUD/InteractionPrompt
@onready var broadcast_message: Label = $HUD/BroadcastMessage
var current_objective: String = INVESTIGATE
var interaction_requested: bool = false
var flicker_elapsed: float = -1.0
var flicker_lights: Array[Dictionary] = []
var message_elapsed: float = 0.0

func _ready() -> void:
	objective_label.text = current_objective
	prompt.hide()
	broadcast_message.hide()
	television.activated.connect(_on_television_activated)
	gate.passed.connect(_on_gate_passed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		interaction_requested = true
		get_viewport().set_input_as_handled()

func looking_at_television() -> bool:
	if television.has_activated:
		return false
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * interaction_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [player.get_rid()])
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == television.get_node("Housing")

func _physics_process(_delta: float) -> void:
	var available := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and looking_at_television()
	prompt.visible = available
	if interaction_requested:
		interaction_requested = false
		if available:
			television.activate()

func _on_television_activated() -> void:
	current_objective = ENTER
	objective_label.text = current_objective
	prompt.hide()
	broadcast_message.text = television.ADMISSION_TEXT
	broadcast_message.show()
	message_elapsed = 0.0
	gate.open()
	flicker_elapsed = 0.0
	for path in flicker_light_paths:
		var light := get_node_or_null(path) as Light3D
		if light == null:
			continue
		flicker_lights.append({"light":light,"energy":light.light_energy,"processing":light.is_processing()})
		# Temporarily suspend the existing idle flicker so it cannot overwrite this event.
		light.set_process(false)

func _process(delta: float) -> void:
	if broadcast_message.visible:
		message_elapsed += delta
		if message_elapsed >= 4.0:
			broadcast_message.hide()
	if flicker_elapsed < 0.0:
		return
	flicker_elapsed += delta
	if flicker_elapsed >= 1.1:
		_restore_lights()
		return
	var dimmed := sin(flicker_elapsed * 38.0) > -0.1
	for entry in flicker_lights:
		entry.light.light_energy = entry.energy * (0.15 if dimmed else 1.0)

func _restore_lights() -> void:
	for entry in flicker_lights:
		if is_instance_valid(entry.light):
			entry.light.light_energy = entry.energy
			entry.light.set_process(entry.processing)
	flicker_lights.clear()
	flicker_elapsed = -1.0

func _on_gate_passed() -> void:
	if not television.has_activated:
		return
	current_objective = RESTORE
	objective_label.text = current_objective

func _exit_tree() -> void:
	_restore_lights()
