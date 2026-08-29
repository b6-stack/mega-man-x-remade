extends Node3D
class_name Buster

@export var buster_shot_scene: PackedScene = preload("res://scenes/buster_shot.tscn")
@export var muzzle_path: NodePath = "Muzzle"
@export var right_particles_path: NodePath = "RightChargeParticles"
@export var left_particles_path: NodePath = "^../../LeftController/LeftHandOffset/LeftChargeParticles"

@onready var muzzle: Marker3D = get_node_or_null(muzzle_path) as Marker3D
@onready var right_particles: GPUParticles3D = get_node_or_null(right_particles_path) as GPUParticles3D

var left_particles: GPUParticles3D = null
var controller: XRController3D = null
var is_charging: bool = false
var charge_time: float = 0.0
var current_level: int = 1
var last_notified_level: int = 0
var max_pulse_timer: float = 0.0

func _ready() -> void:
	controller = _find_controller()
	
	if not muzzle:
		muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0, 0, -0.215)
		add_child(muzzle)
	
	left_particles = get_node_or_null(left_particles_path) as GPUParticles3D
	if not left_particles and get_tree().current_scene:
		left_particles = get_tree().current_scene.find_child("LeftChargeParticles", true, false) as GPUParticles3D

	_stop_all_charge_particles()

	if controller:
		controller.button_pressed.connect(_on_controller_button_pressed)
		controller.button_released.connect(_on_controller_button_released)

func _find_controller() -> XRController3D:
	var p: Node = get_parent()
	while p:
		if p is XRController3D:
			return p as XRController3D
		p = p.get_parent()
	return null

func _on_controller_button_pressed(button_name: String) -> void:
	# Trigger exclusively fires/charges the Buster (A/B are reserved for jump)
	if button_name == "trigger_click" or button_name == "trigger":
		start_charging()

func _on_controller_button_released(button_name: String) -> void:
	if button_name == "trigger_click" or button_name == "trigger":
		release_charge()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_charging()
		else:
			release_charge()

func _process(delta: float) -> void:
	if controller and not is_charging:
		var trigger_val: float = controller.get_float("trigger")
		if trigger_val > 0.4:
			start_charging()
	elif controller and is_charging:
		var trigger_val: float = controller.get_float("trigger")
		if trigger_val < 0.2 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			release_charge()

	if is_charging:
		charge_time += delta
		_process_charging(delta)

func start_charging() -> void:
	if is_charging:
		return
	is_charging = true
	charge_time = 0.0
	current_level = 1
	last_notified_level = 1
	_apply_charge_particles(1)

func _process_charging(delta: float) -> void:
	# Level 2 reached at 1.0s, Level 3 reached at +3.0s (4.0s total)
	if charge_time < 1.0:
		current_level = 1
	elif charge_time < 4.0:
		current_level = 2
	else:
		current_level = 3

	if current_level != last_notified_level:
		last_notified_level = current_level
		_apply_charge_particles(current_level)
		if current_level == 2:
			_send_haptic(160.0, 0.45, 0.12)
		elif current_level == 3:
			_send_haptic(260.0, 0.85, 0.2)

	if current_level == 3:
		max_pulse_timer += delta
		if max_pulse_timer >= 0.15:
			max_pulse_timer = 0.0
			_send_haptic(280.0, 0.3, 0.08)

func release_charge() -> void:
	if not is_charging:
		return
	
	var shot_level := 1
	if charge_time < 1.0:
		shot_level = 1
	elif charge_time < 4.0:
		shot_level = 2
	else:
		shot_level = 3

	fire_shot(shot_level)
	is_charging = false
	charge_time = 0.0
	current_level = 1
	last_notified_level = 0
	_stop_all_charge_particles()

func fire_shot(level: int) -> void:
	if not buster_shot_scene:
		return

	var shot: BusterShot = buster_shot_scene.instantiate() as BusterShot
	if not shot:
		return

	shot.charge_level = level
	var target_parent := get_tree().current_scene if get_tree().current_scene else get_parent()
	target_parent.add_child(shot)
	shot.global_transform = muzzle.global_transform

	match level:
		1:
			_send_haptic(120.0, 0.35, 0.06)
		2:
			_send_haptic(200.0, 0.7, 0.15)
		3:
			_send_haptic(320.0, 1.0, 0.3)

func _apply_charge_particles(level: int) -> void:
	if not left_particles and get_tree().current_scene:
		left_particles = get_tree().current_scene.find_child("LeftChargeParticles", true, false) as GPUParticles3D

	match level:
		1:
			_set_particle_system(right_particles, true, Color(1.0, 0.95, 0.2), 0.016, 20, true)
			_set_particle_system(left_particles, true, Color(1.0, 0.95, 0.2), 0.018, 12, false)
		2:
			_set_particle_system(right_particles, true, Color(0.2, 1.0, 0.45), 0.026, 35, true)
			_set_particle_system(left_particles, true, Color(0.2, 1.0, 0.45), 0.030, 18, false)
		3:
			_set_particle_system(right_particles, true, Color(0.15, 0.75, 1.0), 0.038, 50, true)
			_set_particle_system(left_particles, true, Color(0.15, 0.75, 1.0), 0.042, 26, false)

func _set_particle_system(p: GPUParticles3D, emit: bool, color: Color, p_scale: float, p_amount: int, is_cannon: bool) -> void:
	if not p:
		return
	
	if not emit:
		p.emitting = false
		p.visible = false
		return

	p.visible = true
	p.amount = p_amount
	p.lifetime = 0.07
	
	var p_mat := ParticleProcessMaterial.new()
	if is_cannon:
		p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p_mat.emission_box_extents = Vector3(0.085, 0.085, 0.12)
		p_mat.initial_velocity_min = 0.2
		p_mat.initial_velocity_max = 0.6
	else:
		p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		p_mat.emission_sphere_radius = 0.045
		p_mat.initial_velocity_min = 0.2
		p_mat.initial_velocity_max = 0.5

	p_mat.direction = Vector3(0, 0, 0)
	p_mat.spread = 180.0
	p_mat.gravity = Vector3(0, 0, 0)
	p_mat.scale_min = p_scale * 0.8
	p_mat.scale_max = p_scale * 1.25
	p.process_material = p_mat

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
	p.draw_pass_1 = draw_mesh
	
	p.emitting = true

func _stop_all_charge_particles() -> void:
	_set_particle_system(right_particles, false, Color.BLACK, 0, 0, true)
	_set_particle_system(left_particles, false, Color.BLACK, 0, 0, false)

func _send_haptic(frequency: float, amplitude: float, duration: float) -> void:
	if controller and controller.has_method("trigger_haptic_pulse"):
		controller.trigger_haptic_pulse("haptic", frequency, amplitude, duration, 0.0)
