extends CharacterBody3D
## Reusable first-person controller. The body origin sits at floor level.

@export_range(0.1, 15.0) var walk_speed: float = 3.2
@export_range(0.1, 20.0) var sprint_speed: float = 5.6
@export_range(1.0, 40.0) var ground_acceleration: float = 14.0
@export_range(1.0, 40.0) var ground_deceleration: float = 18.0
@export_range(0.1, 10.0) var air_acceleration: float = 2.0
@export_range(0.01, 1.0) var mouse_sensitivity: float = 0.09

@onready var camera: Camera3D = $Camera3D
@onready var hands: Node3D = $Camera3D/ScarecrowHands
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse_capture"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		pitch = clampf(pitch - deg_to_rad(event.relative.y * mouse_sensitivity), deg_to_rad(-85.0), deg_to_rad(85.0))
		camera.rotation.x = pitch


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)
	var sprinting := Input.is_action_pressed("sprint") and input_vector.length() > 0.0
	var target_speed := sprint_speed if sprinting else walk_speed
	var acceleration := ground_acceleration if direction.length_squared() > 0.0 else ground_deceleration
	if not is_on_floor():
		velocity.y -= gravity * delta
		acceleration = air_acceleration
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	hands.set_motion(horizontal_speed, sprinting, is_on_floor())
