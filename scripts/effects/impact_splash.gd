extends Node3D
class_name ImpactSplash

@export var charge_level: int = 1
@export var duration: float = 0.48

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var shockwave_ring: MeshInstance3D = $ShockwaveRing
@onready var star_flare: MeshInstance3D = $StarFlare
@onready var light: OmniLight3D = $OmniLight3D

var _timer: float = 0.0

func _ready() -> void:
	_face_camera()
	_setup_effect()

func setup(level: int, _hit_normal: Vector3 = Vector3.UP) -> void:
	charge_level = clampi(level, 1, 3)
	_face_camera()
	if is_node_ready():
		_setup_effect()

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

func _setup_effect() -> void:
	var col: Color = Color(1.0, 0.92, 0.15)
	var scale_mult: float = 0.6
	var part_count: int = 26
	var light_range: float = 3.0
	
	match charge_level:
		1:
			col = Color(1.0, 0.92, 0.12)
			scale_mult = 0.6
			part_count = 24
			light_range = 3.0
		2:
			col = Color(0.15, 1.0, 0.4)
			scale_mult = 0.95
			part_count = 38
			light_range = 4.2
		3:
			col = Color(0.1, 0.8, 1.0)
			scale_mult = 1.55
			part_count = 58
			light_range = 6.0

	if light:
		light.light_color = col
		light.omni_range = light_range
		light.light_energy = 6.0 * (scale_mult / 0.6)

	if particles:
		particles.amount = part_count
		var p_mat := ParticleProcessMaterial.new()
		p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p_mat.emission_sphere_radius = 0.06 * scale_mult
		p_mat.direction = Vector3(0, 0, 1)
		p_mat.spread = 75.0
		p_mat.initial_velocity_min = 2.8 * scale_mult
		p_mat.initial_velocity_max = 6.5 * scale_mult
		p_mat.gravity = Vector3(0, -4.5, 0)
		p_mat.scale_min = 0.10 * scale_mult
		p_mat.scale_max = 0.20 * scale_mult
		p_mat.damping_min = 3.0
		p_mat.damping_max = 6.0
		particles.process_material = p_mat

		# Really chunky glowing plasma spheres
		var draw_mesh := SphereMesh.new()
		draw_mesh.radius = 0.06 * scale_mult
		draw_mesh.height = 0.12 * scale_mult
		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = col
		draw_mat.emission_enabled = true
		draw_mat.emission = col
		draw_mat.emission_energy_multiplier = 8.0
		draw_mesh.material = draw_mat
		particles.draw_pass_1 = draw_mesh

		particles.restart()
		particles.emitting = true

	if shockwave_ring:
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(col.r, col.g, col.b, 0.95)
		ring_mat.emission_enabled = true
		ring_mat.emission = col
		ring_mat.emission_energy_multiplier = 6.0
		shockwave_ring.material_override = ring_mat
		shockwave_ring.scale = Vector3(0.12, 0.12, 0.12) * scale_mult

	if star_flare:
		var flare_mat := StandardMaterial3D.new()
		flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flare_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		flare_mat.emission_enabled = true
		flare_mat.emission = col
		flare_mat.emission_energy_multiplier = 9.0
		star_flare.material_override = flare_mat
		star_flare.scale = Vector3(0.35, 0.35, 0.35) * scale_mult

func _process(delta: float) -> void:
	_timer += delta
	var progress: float = clampf(_timer / duration, 0.0, 1.0)
	
	if shockwave_ring:
		var target_scale: float = 0.75
		if charge_level == 2: target_scale = 1.25
		elif charge_level == 3: target_scale = 2.1
		var s: float = lerpf(0.12, target_scale, ease(progress, 0.4))
		shockwave_ring.scale = Vector3(s, s, 0.06)
		if shockwave_ring.material_override is StandardMaterial3D:
			var rmat: StandardMaterial3D = shockwave_ring.material_override
			rmat.albedo_color.a = (1.0 - progress) * 0.9

	if star_flare:
		var s: float = (1.0 - progress) * (0.5 if charge_level == 1 else (0.85 if charge_level == 2 else 1.5))
		star_flare.scale = Vector3(s, s, s)
		star_flare.rotate_z(delta * 12.0)
	
	if light:
		light.light_energy = (1.0 - progress) * 6.0
	
	if _timer >= duration:
		queue_free()
