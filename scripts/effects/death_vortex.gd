extends Node3D
class_name DeathVortex

@export var duration: float = 1.4

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var shockwave2: MeshInstance3D = $Shockwave2
@onready var light: OmniLight3D = $OmniLight3D

var _timer: float = 0.0

func _ready() -> void:
	if particles:
		particles.restart()
		particles.emitting = true

func _process(delta: float) -> void:
	_timer += delta
	var progress: float = clampf(_timer / duration, 0.0, 1.0)
	
	if shockwave:
		var s: float = lerpf(0.2, 5.0, ease(progress, 0.3))
		shockwave.scale = Vector3(s, s, s)
		if shockwave.material_override is StandardMaterial3D:
			var smat: StandardMaterial3D = shockwave.material_override
			smat.albedo_color.a = (1.0 - progress) * 0.9
	
	if shockwave2:
		var s2: float = lerpf(0.1, 7.0, ease(progress, 0.2))
		shockwave2.scale = Vector3(s2, s2, s2)
		if shockwave2.material_override is StandardMaterial3D:
			var smat2: StandardMaterial3D = shockwave2.material_override
			smat2.albedo_color.a = (1.0 - progress) * 0.7

	if light:
		light.light_energy = (1.0 - progress) * 12.0
	
	if _timer >= duration:
		queue_free()
