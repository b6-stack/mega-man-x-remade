extends Area3D
class_name BusterShot

@export var charge_level: int = 1:
	set(value):
		charge_level = clampi(value, 1, 3)
		if is_node_ready():
			_update_shot_properties()

@export var speed: float = 24.0
@export var damage: float = 1.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $TrailParticles

var _lifetime: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_update_shot_properties()

func _update_shot_properties() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true

	match charge_level:
		1:
			# Level 1 (Lemon): Elongated capsule/sphere, radius ~0.05m, length ~0.10m, emissive yellow material
			damage = 1.0
			speed = 24.0
			scale = Vector3(1.0, 1.0, 1.0)
			if mesh_instance:
				var cap := CapsuleMesh.new()
				cap.radius = 0.05
				cap.height = 0.10
				mesh_instance.mesh = cap
				mesh_instance.rotation_degrees = Vector3(90, 0, 0)
			if collision_shape:
				var shape := CapsuleShape3D.new()
				shape.radius = 0.05
				shape.height = 0.10
				collision_shape.shape = shape
				collision_shape.rotation_degrees = Vector3(90, 0, 0)

			mat.albedo_color = Color(1.0, 0.95, 0.1, 1.0)
			mat.emission = Color(1.0, 0.9, 0.05)
			mat.emission_energy_multiplier = 4.0
			if light:
				light.light_color = Color(1.0, 0.9, 0.1)
				light.light_energy = 1.5
				light.omni_range = 1.8
			if particles:
				particles.emitting = false
				particles.visible = false

		2:
			# Level 2 (Medium): Energy capsule/sphere, radius ~0.12m, length ~0.22m, emissive green material + green trailing particles
			damage = 2.5
			speed = 27.0
			scale = Vector3(1.0, 1.0, 1.0)
			if mesh_instance:
				var cap := CapsuleMesh.new()
				cap.radius = 0.12
				cap.height = 0.22
				mesh_instance.mesh = cap
				mesh_instance.rotation_degrees = Vector3(90, 0, 0)
			if collision_shape:
				var shape := CapsuleShape3D.new()
				shape.radius = 0.12
				shape.height = 0.22
				collision_shape.shape = shape
				collision_shape.rotation_degrees = Vector3(90, 0, 0)

			mat.albedo_color = Color(0.15, 0.95, 0.35, 1.0)
			mat.emission = Color(0.1, 1.0, 0.3)
			mat.emission_energy_multiplier = 5.5
			if light:
				light.light_color = Color(0.2, 1.0, 0.4)
				light.light_energy = 3.0
				light.omni_range = 3.0
			if particles:
				particles.emitting = true
				particles.visible = true
				_setup_particles(Color(0.2, 1.0, 0.4), 0.04)

		3:
			# Level 3 (Charged): Large plasma blast, radius ~0.25m, length ~0.50m, emissive blue material + blue trailing particles
			damage = 5.0
			speed = 30.0
			scale = Vector3(1.0, 1.0, 1.0)
			if mesh_instance:
				var cap := CapsuleMesh.new()
				cap.radius = 0.25
				cap.height = 0.50
				mesh_instance.mesh = cap
				mesh_instance.rotation_degrees = Vector3(90, 0, 0)
			if collision_shape:
				var shape := CapsuleShape3D.new()
				shape.radius = 0.25
				shape.height = 0.50
				collision_shape.shape = shape
				collision_shape.rotation_degrees = Vector3(90, 0, 0)

			mat.albedo_color = Color(0.1, 0.6, 1.0, 1.0)
			mat.emission = Color(0.1, 0.55, 1.0)
			mat.emission_energy_multiplier = 7.0
			if light:
				light.light_color = Color(0.2, 0.65, 1.0)
				light.light_energy = 5.0
				light.omni_range = 4.5
			if particles:
				particles.emitting = true
				particles.visible = true
				_setup_particles(Color(0.2, 0.7, 1.0), 0.08)

	if mesh_instance:
		mesh_instance.material_override = mat

func _setup_particles(color: Color, p_scale: float) -> void:
	if not particles:
		return
	
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = p_scale * 1.2
	p_mat.direction = Vector3(0, 0, 1)
	p_mat.spread = 15.0
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3(0, 0, 0)
	p_mat.scale_min = p_scale * 0.6
	p_mat.scale_max = p_scale * 1.4
	particles.process_material = p_mat

	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = p_scale * 0.5
	draw_mesh.height = p_scale
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 4.0
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

func _physics_process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta
	
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
	queue_free()
