extends Node3D
class_name ImpactSplash

@export var charge_level: int = 1
@export var duration: float = 0.35

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var shockwave: MeshInstance3D = $Shockwave
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
	var col := Color(1.0, 0.92, 0.1)
	var scale_mult := 1.0
	var part_count := 24
	var light_range := 2.2
	
	match charge_level:
		1:
			col = Color(1.0, 0.95, 0.15)
			scale_mult = 0.8
			part_count = 20
			light_range = 2.0
		2:
			col = Color(0.2, 1.0, 0.45)
			scale_mult = 1.4
			part_count = 36
			light_range = 3.5
		3:
			col = Color(0.15, 0.8, 1.0)
			scale_mult = 2.4
			part_count = 60
			light_range = 5.5

	if light:
		light.light_color = col
		light.omni_range = light_range
		light.light_energy = 4.0 * scale_mult

	if particles:
		particles.amount = part_count
		var p_mat := ParticleProcessMaterial.new()
		p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p_mat.emission_sphere_radius = 0.04 * scale_mult
		p_mat.direction = Vector3(0, 0, 1)
		p_mat.spread = 75.0
		p_mat.initial_velocity_min = 2.5 * scale_mult
		p_mat.initial_velocity_max = 6.5 * scale_mult
		p_mat.gravity = Vector3(0, -4.0, 0)
		p_mat.scale_min = 0.03 * scale_mult
		p_mat.scale_max = 0.07 * scale_mult
		p_mat.damping_min = 4.0
		p_mat.damping_max = 8.0
		particles.process_material = p_mat

		var draw_mesh := SphereMesh.new()
		draw_mesh.radius = 0.02 * scale_mult
		draw_mesh.height = 0.04 * scale_mult
		var draw_mat := StandardMaterial3D.new()
		draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw_mat.albedo_color = col
		draw_mat.emission_enabled = true
		draw_mat.emission = col
		draw_mat.emission_energy_multiplier = 6.0
		draw_mesh.material = draw_mat
		particles.draw_pass_1 = draw_mesh

		particles.restart()
		particles.emitting = true

	if shockwave:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(col.r, col.g, col.b, 0.9)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 4.0
		shockwave.material_override = mat
		shockwave.scale = Vector3(0.1, 0.1, 0.1) * scale_mult

func _process(delta: float) -> void:
	_timer += delta
	var progress: float = clampf(_timer / duration, 0.0, 1.0)
	
	if shockwave:
		var s: float = lerpf(0.15, 0.9, progress)
		if charge_level == 2: s *= 1.5
		elif charge_level == 3: s *= 2.5
		shockwave.scale = Vector3(s, s, s)
		if shockwave.material_override is StandardMaterial3D:
			var smat: StandardMaterial3D = shockwave.material_override
			smat.albedo_color.a = (1.0 - progress) * 0.85
	
	if light:
		light.light_energy = (1.0 - progress) * 4.0
	
	if _timer >= duration:
		queue_free()
