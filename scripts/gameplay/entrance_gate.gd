extends Node3D
## Two physics-synchronized gate leaves built from the existing fence mesh.
signal opened
signal passed
@export var player_path: NodePath = NodePath("../../ScarecrowPlayer")
@export_range(0.1, 5.0) var opening_duration: float = 1.8
var is_open: bool = false
var is_opening: bool = false
var has_been_passed: bool = false
var leaves: Array[AnimatableBody3D] = []
var passage: Area3D
@onready var player: CharacterBody3D = get_node(player_path)

func _ready() -> void:
	var source := preload("res://scenes/props/fence.tscn").instantiate()
	var source_mesh: BoxMesh = source.get_node("Barrier/Mesh").mesh
	var panel: BoxMesh = source_mesh.duplicate()
	panel.size.x = 5.0
	source.free()
	for side in [-1.0, 1.0]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "LeftLeaf" if side < 0 else "RightLeaf"
		leaf.position.x = side * 5.0
		leaf.sync_to_physics = true
		add_child(leaf)
		var mesh := MeshInstance3D.new()
		mesh.mesh = panel
		mesh.position = Vector3(-side * 2.5, 0.85, 0)
		leaf.add_child(mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = panel.size
		collision.shape = shape
		collision.position = mesh.position
		leaf.add_child(collision)
		leaves.append(leaf)
	passage = Area3D.new()
	passage.name = "CarnivalThreshold"
	passage.position = Vector3(0, 1.5, -2.0)
	passage.collision_layer = 0
	passage.collision_mask = 1
	add_child(passage)
	var trigger := CollisionShape3D.new()
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(10, 3, 2.4)
	trigger.shape = trigger_shape
	passage.add_child(trigger)
	passage.body_entered.connect(_on_body_entered)

func open() -> void:
	if is_open or is_opening:
		return
	is_opening = true
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(leaves[0], "rotation:y", PI * 0.5, opening_duration)
	tween.tween_property(leaves[1], "rotation:y", -PI * 0.5, opening_duration)
	tween.chain().tween_callback(_finish_opening)

func _finish_opening() -> void:
	is_open = true
	is_opening = false
	opened.emit()
	# Covers a player who entered the trigger while the panels were opening.
	if passage.get_overlapping_bodies().has(player):
		_on_body_entered(player)

func _on_body_entered(body: Node3D) -> void:
	if body != player or not is_open or has_been_passed:
		return
	has_been_passed = true
	passed.emit()
