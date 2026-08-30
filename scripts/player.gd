extends CharacterBody3D
class_name VRPlayer

enum ControllerProfile {
	GENERIC_OPENXR,
	META_QUEST,
	VALVE_INDEX
}

@export_group("Controller Profile")
@export var controller_profile: ControllerProfile = ControllerProfile.META_QUEST

@export_group("Locomotion")
@export var move_speed: float = 5.0
@export var snap_turn_angle: float = 45.0
@export var jump_velocity: float = 8.8
@export var gravity: float = 12.0

@export_group("Wall Jump & Slide")
@export var wall_slide_speed: float = 2.5
@export var wall_slide_gravity: float = 5.5
@export var wall_jump_kick_speed: float = 6.5
@export var wall_kick_lock_time: float = 0.14
@export var wall_coyote_time: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 10.0
@export var dash_duration: float = 0.32
@export var dash_cooldown: float = 0.45

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var left_hand_offset: Node3D = get_node_or_null("XROrigin3D/LeftController/LeftHandOffset")
@onready var right_hand_offset: Node3D = get_node_or_null("XROrigin3D/RightController/RightHandOffset")
@onready var wall_slide_particles: GPUParticles3D = get_node_or_null("WallSlideParticles")

var is_xr_active: bool = false
var is_wall_sliding: bool = false
var is_dashing: bool = false

var _can_snap_turn: bool = true
var _prev_q_pressed: bool = false
var _prev_e_pressed: bool = false
var _prev_shift_pressed: bool = false

var _wall_coyote_timer: float = 0.0
var _wall_kick_timer: float = 0.0
var _last_wall_normal: Vector3 = Vector3.ZERO
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	_apply_controller_profile()
	_init_openxr()
	
	if right_controller:
		right_controller.button_pressed.connect(_on_controller_button_pressed)
	if left_controller:
		left_controller.button_pressed.connect(_on_controller_button_pressed)

func _apply_controller_profile() -> void:
	match controller_profile:
		ControllerProfile.META_QUEST:
			if left_hand_offset:
				left_hand_offset.position = Vector3(0, -0.015, 0.085)
				left_hand_offset.rotation_degrees = Vector3(-12, 0, 90)
			if right_hand_offset:
				right_hand_offset.position = Vector3(0, -0.015, 0.085)
				right_hand_offset.rotation_degrees = Vector3(-12, 0, 0)
		ControllerProfile.VALVE_INDEX:
			if left_hand_offset:
				left_hand_offset.position = Vector3(0, -0.02, 0.06)
				left_hand_offset.rotation_degrees = Vector3(-20, 0, 90)
			if right_hand_offset:
				right_hand_offset.position = Vector3(0, -0.02, 0.06)
				right_hand_offset.rotation_degrees = Vector3(-20, 0, 0)
		ControllerProfile.GENERIC_OPENXR:
			if left_hand_offset:
				left_hand_offset.position = Vector3(0, 0, 0.08)
				left_hand_offset.rotation_degrees = Vector3(0, 0, 90)
			if right_hand_offset:
				right_hand_offset.position = Vector3(0, 0, 0.08)
				right_hand_offset.rotation_degrees = Vector3(0, 0, 0)

func _init_openxr() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("Mega Man X VR: OpenXR interface initialized successfully.")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		is_xr_active = true
	else:
		print("Mega Man X VR: OpenXR not found/active. Desktop preview mode.")

func _on_controller_button_pressed(button_name: String) -> void:
	# VR Jump (A, B, X, Y or stick click)
	if button_name == "ax_button" or button_name == "by_button" or button_name == "primary_click":
		_try_jump()
	
	# VR Dash (grip click, secondary click)
	if button_name == "grip_click" or button_name == "secondary_click":
		_try_dash()

func _try_jump() -> bool:
	if is_on_floor():
		velocity.y = jump_velocity
		is_wall_sliding = false
		return true
	elif is_wall_sliding or is_on_wall() or _wall_coyote_timer > 0.0:
		# Mega Man X Wall Kick!
		var kick_normal := _last_wall_normal
		if is_on_wall():
			kick_normal = get_wall_normal()
		
		velocity.y = jump_velocity
		velocity.x = kick_normal.x * wall_jump_kick_speed
		velocity.z = kick_normal.z * wall_jump_kick_speed
		
		_wall_kick_timer = wall_kick_lock_time
		_wall_coyote_timer = 0.0
		is_wall_sliding = false
		
		_trigger_haptic(0.6, 0.08)
		return true
	return false

func _try_dash() -> bool:
	if _dash_cooldown_timer > 0.0 or is_dashing:
		return false
	
	var move_dir := _get_intended_move_direction()
	if move_dir == Vector3.ZERO:
		var forward := -xr_camera.global_transform.basis.z
		forward.y = 0.0
		move_dir = forward.normalized()
	
	is_dashing = true
	_dash_direction = move_dir
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	
	velocity.x = _dash_direction.x * dash_speed
	velocity.z = _dash_direction.z * dash_speed
	
	_trigger_haptic(0.8, 0.12)
	return true

func _trigger_haptic(amplitude: float, duration: float) -> void:
	if left_controller:
		left_controller.trigger_haptic_pulse("haptic", 100.0, amplitude, duration, 0.0)
	if right_controller:
		right_controller.trigger_haptic_pulse("haptic", 100.0, amplitude, duration, 0.0)

func _get_intended_move_direction() -> Vector3:
	var input_vec := Vector2.ZERO
	if is_xr_active and left_controller:
		var thumbstick: Vector2 = left_controller.get_vector2("primary")
		if thumbstick.length() < 0.1:
			thumbstick = left_controller.get_vector2("thumbstick")
		input_vec = thumbstick
	
	if input_vec == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W): input_vec.y += 1.0
		if Input.is_key_pressed(KEY_S): input_vec.y -= 1.0
		if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
		if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
		input_vec = input_vec.normalized()

	if input_vec == Vector2.ZERO:
		return Vector3.ZERO

	var cam_basis := xr_camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	
	return (right * input_vec.x + forward * input_vec.y).normalized()

func _physics_process(delta: float) -> void:
	# Timers
	if _wall_coyote_timer > 0.0:
		_wall_coyote_timer -= delta
	if _wall_kick_timer > 0.0:
		_wall_kick_timer -= delta
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			is_dashing = false

	# Desktop inputs
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER):
		_try_jump()
	
	var shift_pressed := Input.is_key_pressed(KEY_SHIFT)
	if shift_pressed and not _prev_shift_pressed:
		_try_dash()
	_prev_shift_pressed = shift_pressed

	# Wall Slide Detection
	var on_wall := is_on_wall()
	var on_floor := is_on_floor()

	if on_wall and not on_floor:
		_last_wall_normal = get_wall_normal()
		_wall_coyote_timer = wall_coyote_time
		
		# Slide if falling or maintaining wall contact
		if velocity.y <= 0.0:
			is_wall_sliding = true
		else:
			is_wall_sliding = false
	else:
		is_wall_sliding = false

	# Gravity & Vertical Movement
	if on_floor:
		if velocity.y < 0.0:
			velocity.y = 0.0
	elif is_wall_sliding:
		# Controlled Mega Man X wall slide
		velocity.y = move_toward(velocity.y, -wall_slide_speed, wall_slide_gravity * delta)
		if velocity.y < -wall_slide_speed:
			velocity.y = -wall_slide_speed
	else:
		velocity.y -= gravity * delta

	# Wall Slide FX
	if wall_slide_particles:
		wall_slide_particles.emitting = is_wall_sliding

	# Horizontal Movement (Steering & Dashing)
	if is_dashing:
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
	elif _wall_kick_timer > 0.0:
		# During initial kick arc, preserve explosive outward impulse
		var move_dir := _get_intended_move_direction()
		if move_dir != Vector3.ZERO:
			# Lightly blend in steer direction
			velocity.x = move_toward(velocity.x, move_dir.x * move_speed, move_speed * delta * 2.0)
			velocity.z = move_toward(velocity.z, move_dir.z * move_speed, move_speed * delta * 2.0)
	else:
		var move_dir := _get_intended_move_direction()
		if move_dir != Vector3.ZERO:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta * 8.0)
			velocity.z = move_toward(velocity.z, 0, move_speed * delta * 8.0)

	# VR Snap Turning (Right Stick flick left/right)
	var snap_input := 0.0
	if is_xr_active and right_controller:
		var r_stick: Vector2 = right_controller.get_vector2("primary")
		if r_stick.length() < 0.1:
			r_stick = right_controller.get_vector2("thumbstick")
		snap_input = r_stick.x

	if abs(snap_input) > 0.5:
		if _can_snap_turn:
			var turn_sign: float = -1.0 if snap_input > 0.0 else 1.0
			rotate_y(deg_to_rad(turn_sign * snap_turn_angle))
			_can_snap_turn = false
	elif abs(snap_input) < 0.2:
		_can_snap_turn = true

	# Desktop Snap Turning (Q and E keys)
	var q_pressed := Input.is_key_pressed(KEY_Q)
	var e_pressed := Input.is_key_pressed(KEY_E)
	if q_pressed and not _prev_q_pressed:
		rotate_y(deg_to_rad(snap_turn_angle))
	if e_pressed and not _prev_e_pressed:
		rotate_y(deg_to_rad(-snap_turn_angle))
	_prev_q_pressed = q_pressed
	_prev_e_pressed = e_pressed

	move_and_slide()
