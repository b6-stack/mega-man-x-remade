extends Node3D
class_name DeflectSparks

@export var duration: float = 0.38

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var ping_flash: MeshInstance3D = $PingFlash
@onready var light: OmniLight3D = $OmniLight3D

var _timer: float = 0.0

func _ready() -> void:
	_face_camera()
	if particles:
		particles.restart()
		particles.emitting = true

func setup(_hit_normal: Vector3 = Vector3.UP) -> void:
	_face_camera()

func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if not cam and get_tree().current_scene:
		cam = get_tree().current_scene.find_child("XRCamera3D", true, false) as Camera3D
	
	if cam:
		var to_cam := cam.global_position - global_position
		if to_cam.length_squared() > 0.001:
			var target_look := global_position - to_cam
			var up_axis := Vector3.UP if abs(to_cam.normalized().y) < 0.9 else Vector3.FORWARD
			look_at(target_look, up_axis)

func _process(delta: float) -> void:
	_timer += delta
	var progress: float = clampf(_timer / duration, 0.0, 1.0)
	
	if ping_flash:
		var s: float = (1.0 - progress) * 0.35
		ping_flash.scale = Vector3(s, s, s)
		ping_flash.rotate_z(delta * 18.0)
	
	if light:
		light.light_energy = (1.0 - progress) * 5.5
	
	if _timer >= duration:
		queue_free()
