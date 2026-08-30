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
var _prev_global_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	_prev_global_pos = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_update_shot_properties()

func _update_shot_properties() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true

	match charge_level:
		1:
			# Level 1 (Lemon): 0.05m radius x 0.10m length capsule, yellow emissive
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
			# Level 2 (Medium): 0.12m radius x 0.22m length capsule, chunky dense green trail
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
				_setup_particles(Color(0.2, 1.0, 0.45), 0.10, 32, 0.22)

		3:
			# Level 3 (Charged): 0.375m radius x 0.75m length capsule (150% enlarged), massive dense blue plasma trail
			damage = 5.0
			speed = 30.0
			scale = Vector3(1.0, 1.0, 1.0)
			if mesh_instance:
				var cap := CapsuleMesh.new()
				cap.radius = 0.375
				cap.height = 0.75
				mesh_instance.mesh = cap
				mesh_instance.rotation_degrees = Vector3(90, 0, 0)
			if collision_shape:
				var shape := CapsuleShape3D.new()
				shape.radius = 0.375
				shape.height = 0.75
				collision_shape.shape = shape
				collision_shape.rotation_degrees = Vector3(90, 0, 0)

			mat.albedo_color = Color(0.15, 0.75, 1.0, 1.0)
			mat.emission = Color(0.1, 0.65, 1.0)
			mat.emission_energy_multiplier = 7.0
			if light:
				light.light_color = Color(0.2, 0.65, 1.0)
				light.light_energy = 6.5
				light.omni_range = 6.5
			if particles:
				particles.emitting = true
				particles.visible = true
				_setup_particles(Color(0.15, 0.75, 1.0), 0.33, 56, 0.32)

	if mesh_instance:
		mesh_instance.material_override = mat

func _setup_particles(color: Color, p_scale: float, p_amount: int, p_lifetime: float) -> void:
	if not particles:
		return
	
	particles.amount = p_amount
	particles.lifetime = p_lifetime
	particles.local_coords = false
	
	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = p_scale * 0.4
	p_mat.direction = Vector3(0, 0, 1)
	p_mat.spread = 10.0
	p_mat.initial_velocity_min = 1.0
	p_mat.initial_velocity_max = 3.0
	p_mat.gravity = Vector3(0, 0, 0)
	p_mat.scale_min = p_scale * 0.8
	p_mat.scale_max = p_scale * 1.3
	particles.process_material = p_mat

	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = p_scale * 0.5
	draw_mesh.height = p_scale
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = color
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 6.0
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh

const IMPACT_SPLASH_SCENE: PackedScene = preload("res://scenes/effects/impact_splash.tscn")
const DEFLECT_SPARKS_SCENE: PackedScene = preload("res://scenes/effects/deflect_sparks.tscn")

func _physics_process(delta: float) -> void:
	var move_step: Vector3 = -global_transform.basis.z * speed * delta
	var next_pos: Vector3 = global_position + move_step
	
	# Raycast forward from current position along the step to hit the exact outer mesh surface
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(global_position, next_pos + move_step * 0.15)
		query.exclude = [self]
		query.collision_mask = collision_mask
		var result := space_state.intersect_ray(query)
		if not result.is_empty() and result.collider:
			var hit_collider: Node3D = result.collider as Node3D
			var hit_pos: Vector3 = result.position + result.normal * 0.08
			var hit_normal: Vector3 = result.normal
			_process_impact(hit_collider, hit_pos, hit_normal)
			return

	_prev_global_pos = global_position
	global_position = next_pos
	
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	_handle_hit_fallback(body)

func _on_area_entered(area: Area3D) -> void:
	_handle_hit_fallback(area)

func _handle_hit_fallback(target: Node3D) -> void:
	var hit_normal: Vector3 = global_transform.basis.z
	var hit_pos: Vector3 = _prev_global_pos + hit_normal * 0.08
	
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(_prev_global_pos, global_position + -global_transform.basis.z * 0.5)
		query.exclude = [self]
		query.collision_mask = collision_mask
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			hit_pos = result.position + result.normal * 0.08
			hit_normal = result.normal

	_process_impact(target, hit_pos, hit_normal)

func _process_impact(target: Node3D, hit_pos: Vector3, hit_normal: Vector3) -> void:
	var damage_dealt := false
	
	var damage_target: Node = target
	if not damage_target.has_method("take_damage") and target.get_parent() and target.get_parent().has_method("take_damage"):
		damage_target = target.get_parent()
	
	if damage_target.has_method("take_damage"):
		var result = damage_target.take_damage(damage, hit_pos, hit_normal)
		if result is bool:
			damage_dealt = result
		else:
			damage_dealt = true
	
	if damage_dealt:
		_spawn_impact_splash(hit_pos, hit_normal)
	else:
		_spawn_deflect_sparks(hit_pos, hit_normal)
	
	queue_free()

func _spawn_impact_splash(pos: Vector3, normal: Vector3) -> void:
	if not IMPACT_SPLASH_SCENE:
		return
	var splash = IMPACT_SPLASH_SCENE.instantiate()
	if splash:
		var target_parent := get_tree().current_scene if get_tree().current_scene else get_parent()
		target_parent.add_child(splash)
		splash.global_position = pos
		if splash.has_method("setup"):
			splash.setup(charge_level, normal)

func _spawn_deflect_sparks(pos: Vector3, normal: Vector3) -> void:
	if not DEFLECT_SPARKS_SCENE:
		return
	var sparks = DEFLECT_SPARKS_SCENE.instantiate()
	if sparks:
		var target_parent := get_tree().current_scene if get_tree().current_scene else get_parent()
		target_parent.add_child(sparks)
		sparks.global_position = pos
		if sparks.has_method("setup"):
			sparks.setup(normal)
