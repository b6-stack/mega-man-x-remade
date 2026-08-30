extends Node3D
class_name ImpactSplash

@export var charge_level: int = 1
@export var duration: float = 0.55

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var shockwave_ring: MeshInstance3D = $ShockwaveRing
@onready var star_flare: MeshInstance3D = $StarFlare
@onready var light: OmniLight3D = $OmniLight3D

var _timer: float = 0.0

func _ready() -> void:
	_setup_effect()

func setup(level: int, hit_normal: Vector3 = Vector3.UP) -> void:
	charge_level = clampi(level, 1, 3)
	if hit_normal != Vector3.ZERO:
		var up_axis := Vector3.UP if abs(hit_normal.y) < 0.9 else Vector3.FORWARD
		look_at(global_position + hit_normal, up_axis)
	if is_node_ready():
		_setup_effect()

func _setup_effect() -> void:
	var col: Color = Color(1.0, 0.92, 0.15)
	var scale_mult: float = 1.0
	var part_count: int = 32
	var light_range: float = 4.0
	
	match charge_level:
		1:
			col = Color(1.0, 0.92, 0.12)
			scale_mult = 1.0
			part_count = 30
			light_range = 4.0
		2:
			col = Color(0.15, 1.0, 0.4)
			scale_mult = 1.6
			part_count = 48
			light_range = 6.0
		3:
			col = Color(0.1, 0.8, 1.0)
			scale_mult = 2.8
			part_count = 75
			light_range = 9.0

	if light:
		light.light_color = col
		light.omni_range = light_range
		light.light_energy = 8.0 * scale_mult

	if particles:
		particles.amount = part_count
		var p_mat := ParticleProcessMaterial.new()
		p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p_mat.emission_sphere_radius = 0.08 * scale_mult
		p_mat.direction = Vector3(0, 0, 1)
		p_mat.spread = 80.0
		p_mat.initial_velocity_min = 4.0 * scale_mult
		p_mat.initial_velocity_max = 9.0 * scale_mult
		p_mat.gravity = Vector3(0, -6.0, 0)
		p_mat.scale_min = 0.08 * scale_mult
		p_mat.scale_max = 0.16 * scale_mult
		p_mat.damping_min = 3.0
		p_mat.damping_max = 7.0
		particles.process_material = p_mat

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
		shockwave_ring.scale = Vector3(0.2, 0.2, 0.2) * scale_mult

	if star_flare:
		var flare_mat := StandardMaterial3D.new()
		flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flare_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flare_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		flare_mat.emission_enabled = true
		flare_mat.emission = col
		flare_mat.emission_energy_multiplier = 10.0
		star_flare.material_override = flare_mat
		star_flare.scale = Vector3(0.5, 0.5, 0.5) * scale_mult

func _process(delta: float) -> void:
	_timer += delta
	var progress: float = clampf(_timer / duration, 0.0, 1.0)
	
	if shockwave_ring:
		var target_scale: float = 1.2
		if charge_level == 2: target_scale = 2.0
		elif charge_level == 3: target_scale = 3.6
		var s: float = lerpf(0.2, target_scale, ease(progress, 0.4))
		shockwave_ring.scale = Vector3(s, s, 0.1)
		if shockwave_ring.material_override is StandardMaterial3D:
			var rmat: StandardMaterial3D = shockwave_ring.material_override
			rmat.albedo_color.a = (1.0 - progress) * 0.9

	if star_flare:
		var s: float = (1.0 - progress) * (0.8 if charge_level == 1 else (1.4 if charge_level == 2 else 2.5))
		star_flare.scale = Vector3(s, s, s)
		star_flare.rotate_z(delta * 12.0)
	
	if light:
		light.light_energy = (1.0 - progress) * 8.0
	
	if _timer >= duration:
		queue_free()
