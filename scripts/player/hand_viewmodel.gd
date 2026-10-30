extends Node3D
## Temporary mesh placeholders. Replace PlaceholderArms with a rigged GLB later;
## keep this camera-relative root and set_motion() animation interface.

@onready var placeholder_arms: Node3D = $PlaceholderArms
var motion_speed: float = 0.0
var sprinting: bool = false
var grounded: bool = false
var elapsed: float = 0.0
var gait_phase: float = 0.0
var movement_blend: float = 0.0
var sprint_blend: float = 0.0


func _ready() -> void:
	var wood := _material(Color(0.105, 0.073, 0.047), 0.95)
	var straw := _material(Color(0.30, 0.24, 0.12), 1.0)
	var cloth: Material = preload("res://materials/pbr/hessian_burlap_local.tres")
	var claw := _material(Color(0.055, 0.042, 0.029), 0.85)
	_build_arm(-1.0, wood, straw, cloth, claw)
	_build_arm(1.0, wood, straw, cloth, claw)


func set_motion(speed: float, is_sprinting: bool, is_grounded: bool) -> void:
	motion_speed = speed
	sprinting = is_sprinting
	grounded = is_grounded


func _process(delta: float) -> void:
	elapsed += delta
	var target_blend := clampf(motion_speed / 3.2, 0.0, 1.0) if grounded else 0.0
	movement_blend = lerpf(movement_blend, target_blend, 1.0 - exp(-8.0 * delta))
	sprint_blend = lerpf(sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-6.0 * delta))
	gait_phase += delta * lerpf(7.5, 10.5, sprint_blend) * movement_blend
	var amplitude := lerpf(0.008, 0.014, sprint_blend) * movement_blend
	position = Vector3(sin(gait_phase) * amplitude, sin(elapsed * 1.5) * 0.003 + cos(gait_phase * 2.0) * amplitude * 0.5, sprint_blend * 0.025)
	rotation = Vector3(sin(elapsed * 1.5) * 0.004, 0.0, sin(gait_phase) * amplitude * 0.5)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _build_arm(side: float, wood: Material, straw: Material, cloth: Material, claw: Material) -> void:
	var arm := Node3D.new()
	arm.name = "LeftArm" if side < 0.0 else "RightArm"
	placeholder_arms.add_child(arm)
	var elbow := Vector3(side * 0.48, -0.68, -0.12)
	var wrist := Vector3(side * 0.34, -0.34, -0.69)
	var palm := Vector3(side * 0.32, -0.285, -0.79)
	_segment(arm, "WoodForearm", elbow, wrist, 0.037, 0.025, wood)
	_segment(arm, "WoodPalm", wrist, palm, 0.027, 0.040, wood)
	# Narrow uneven bindings and three hanging strips suggest worn burlap.
	for index in range(5):
		var start := elbow.lerp(wrist, 0.48 + index * 0.047)
		_segment(arm, "StrawBinding%d" % index, start, start + (wrist - elbow).normalized() * 0.018, 0.040, 0.038, straw)
	for index in range(3):
		var start := elbow.lerp(wrist, 0.32) + Vector3(side * (index - 1) * 0.017, -0.016, 0.0)
		_segment(arm, "TornFabric%d" % index, start, start + Vector3(side * 0.012, -0.10 - index * 0.016, 0.035), 0.018, 0.003, cloth)
	# Four elongated fingers curl toward the center, leaving the aiming area open.
	for index in range(4):
		var spread := float(index) - 1.5
		var base := palm + Vector3(side * spread * 0.020, 0.0, -0.008)
		var knuckle := base + Vector3(side * spread * 0.012, 0.035, -0.073 - (1.5 - absf(spread)) * 0.015)
		var tip := knuckle + Vector3(-side * 0.008, -0.025, -0.055)
		_segment(arm, "Finger%d" % index, base, knuckle, 0.010, 0.007, wood)
		_segment(arm, "Claw%d" % index, knuckle, tip, 0.008, 0.001, claw)
	var thumb_base := wrist + Vector3(-side * 0.024, 0.016, -0.025)
	var thumb_joint := thumb_base + Vector3(-side * 0.065, 0.025, -0.035)
	_segment(arm, "Thumb", thumb_base, thumb_joint, 0.013, 0.009, wood)
	_segment(arm, "ThumbClaw", thumb_joint, thumb_joint + Vector3(-side * 0.012, -0.008, -0.060), 0.009, 0.001, claw)
	for index in range(6):
		var start := elbow.lerp(wrist, 0.65) + Vector3(side * (index - 2.5) * 0.010, 0.022, 0.0)
		_segment(arm, "LooseStraw%d" % index, start, start + Vector3(side * (index - 2.5) * 0.009, 0.035, -0.075), 0.0025, 0.0006, straw)


func _segment(parent: Node3D, segment_name: String, start: Vector3, end: Vector3, bottom_radius: float, top_radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 7
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = segment_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.position = (start + end) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
