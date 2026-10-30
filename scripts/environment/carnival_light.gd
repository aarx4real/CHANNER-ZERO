extends OmniLight3D
## Sparse deterministic flicker; most bulbs are emissive meshes without lights.
@export var phase: float = 0.0
var base_energy: float
var elapsed: float = 0.0
func _ready() -> void:
	base_energy = light_energy
func _process(delta: float) -> void:
	elapsed += delta
	var pulse := sin(elapsed * 2.3 + phase) * sin(elapsed * 7.1 + phase)
	light_energy = base_energy * (0.75 if pulse > 0.72 else 1.0)
