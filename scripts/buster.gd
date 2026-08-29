extends Node3D
class_name Buster

@export var buster_shot_scene: PackedScene = preload("res://scenes/buster_shot.tscn")
@export var muzzle_path: NodePath = "Muzzle"
@export var charge_glow_path: NodePath = "Muzzle/ChargeGlow"

@onready var muzzle: Marker3D = get_node_or_null(muzzle_path) as Marker3D
@onready var charge_glow: MeshInstance3D = get_node_or_null(charge_glow_path) as MeshInstance3D
@onready var controller: XRController3D = get_parent() as XRController3D

var is_charging: bool = false
var charge_time: float = 0.0
var current_level: int = 1
var last_notified_level: int = 0
var max_pulse_timer: float = 0.0

func _ready() -> void:
	if not muzzle:
		muzzle = Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0, 0, -0.3)
		add_child(muzzle)
		
	if charge_glow:
		charge_glow.visible = false

	if controller:
		controller.button_pressed.connect(_on_controller_button_pressed)
		controller.button_released.connect(_on_controller_button_released)

func _on_controller_button_pressed(button_name: String) -> void:
	if button_name == "trigger_click" or button_name == "trigger" or button_name == "primary_click" or button_name == "ax_button":
		start_charging()

func _on_controller_button_released(button_name: String) -> void:
	if button_name == "trigger_click" or button_name == "trigger" or button_name == "primary_click" or button_name == "ax_button":
		release_charge()

func _unhandled_input(event: InputEvent) -> void:
	# Desktop fallback for testing without VR headset
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_charging()
		else:
			release_charge()
	elif event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.echo:
			start_charging()
		elif not event.pressed:
			release_charge()

func _process(delta: float) -> void:
	# Check analog trigger on controller if present
	if controller and not is_charging:
		var trigger_val: float = controller.get_float("trigger")
		if trigger_val > 0.4:
			start_charging()
	elif controller and is_charging:
		var trigger_val: float = controller.get_float("trigger")
		if trigger_val < 0.2 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_key_pressed(KEY_SPACE):
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
	_apply_charge_visuals(1)

func _process_charging(delta: float) -> void:
	if charge_time < 0.5:
		current_level = 1
	elif charge_time < 1.5:
		current_level = 2
	else:
		current_level = 3

	# Haptics & visuals on level up
	if current_level != last_notified_level:
		last_notified_level = current_level
		_apply_charge_visuals(current_level)
		if current_level == 2:
			_send_haptic(160.0, 0.45, 0.12)
		elif current_level == 3:
			_send_haptic(260.0, 0.85, 0.2)

	# Level 3 continuous vibration buzz
	if current_level == 3:
		max_pulse_timer += delta
		if max_pulse_timer >= 0.15:
			max_pulse_timer = 0.0
			_send_haptic(280.0, 0.3, 0.08)

func release_charge() -> void:
	if not is_charging:
		return
	
	var shot_level := 1
	if charge_time < 0.5:
		shot_level = 1
	elif charge_time < 1.5:
		shot_level = 2
	else:
		shot_level = 3

	fire_shot(shot_level)
	is_charging = false
	charge_time = 0.0
	current_level = 1
	last_notified_level = 0
	if charge_glow:
		charge_glow.visible = false

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

	# Fire haptic feedback
	match level:
		1:
			_send_haptic(120.0, 0.35, 0.06)
		2:
			_send_haptic(200.0, 0.7, 0.15)
		3:
			_send_haptic(320.0, 1.0, 0.3)

func _apply_charge_visuals(level: int) -> void:
	if not charge_glow:
		return
	
	charge_glow.visible = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	match level:
		1:
			charge_glow.scale = Vector3(0.08, 0.08, 0.08)
			mat.albedo_color = Color(1.0, 0.95, 0.2, 0.6)
		2:
			charge_glow.scale = Vector3(0.18, 0.18, 0.18)
			mat.albedo_color = Color(0.15, 0.95, 0.85, 0.75)
		3:
			charge_glow.scale = Vector3(0.3, 0.3, 0.3)
			mat.albedo_color = Color(1.0, 0.25, 0.85, 0.9)

	charge_glow.material_override = mat

func _send_haptic(frequency: float, amplitude: float, duration: float) -> void:
	if controller and controller.has_method("trigger_haptic_pulse"):
		controller.trigger_haptic_pulse("haptic", frequency, amplitude, duration, 0.0)
