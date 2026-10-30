extends Node3D
## Adds behavior to the existing ticket TV only. No shared screen asset is edited.
signal activated
const ADMISSION_TEXT := "GUEST NO. 001 — ADMITTED"
var has_activated: bool = false
var screen_material: StandardMaterial3D
var screen_text: Label3D
var elapsed: float = 0.0

func _ready() -> void:
	var glass: MeshInstance3D = $Glass
	var original: Material = glass.get_active_material(0)
	screen_material = original.duplicate() as StandardMaterial3D
	glass.material_override = screen_material
	screen_text = Label3D.new()
	screen_text.name = "AdmissionMessage"
	screen_text.position = Vector3(0, 0.4, 0.37)
	screen_text.text = "GUEST NO. 001\n— ADMITTED"
	screen_text.font_size = 32
	screen_text.pixel_size = 0.0012
	screen_text.modulate = Color(0.77, 0.87, 0.78)
	screen_text.outline_size = 0
	screen_text.no_depth_test = false
	screen_text.visible = false
	add_child(screen_text)
	set_process(false)

func activate() -> bool:
	if has_activated:
		return false
	has_activated = true
	screen_text.visible = true
	screen_material.emission_enabled = true
	set_process(true)
	activated.emit()
	return true

func _process(delta: float) -> void:
	elapsed += delta
	# Cheap deterministic CRT flicker, isolated to this TV's material instance.
	var brightness := 0.14 + 0.035 * sin(elapsed * 43.0) * sin(elapsed * 19.0)
	screen_material.albedo_color = Color(brightness * 0.5, brightness * 0.7, brightness * 0.6)
	screen_material.emission = Color(brightness * 0.6, brightness, brightness * 0.72)
	screen_material.emission_energy_multiplier = 0.8
	screen_text.modulate.a = 0.88 + 0.12 * absf(sin(elapsed * 37.0))
