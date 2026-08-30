extends Node3D
class_name DeflectSparks

@export var duration: float = 0.45

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var ping_flash: MeshInstance3D = $PingFlash
@onready var light: OmniLight3D = $OmniLight3D

var _timer: float = 0.0

func _ready() -> void:
	if particles:
		particles.restart()
		particles.emitting = true

func setup(hit_normal: Vector3 = Vector3.UP) -> void:
	if hit_normal != Vector3.ZERO:
		var up_axis := Vector3.UP if abs(hit_normal.y) < 0.9 else Vector3.FORWARD
		look_at(global_position + hit_normal, up_axis)

func _process(delta: float) -> void:
	_timer += delta
	var progress: float = clampf(_timer / duration, 0.0, 1.0)
	
	if ping_flash:
		var s: float = (1.0 - progress) * 0.7
		ping_flash.scale = Vector3(s, s, s)
		ping_flash.rotate_z(delta * 18.0)
	
	if light:
		light.light_energy = (1.0 - progress) * 9.0
	
	if _timer >= duration:
		queue_free()
