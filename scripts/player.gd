extends CharacterBody3D
class_name VRPlayer

enum ControllerProfile {
	GENERIC_OPENXR,
	META_QUEST,
	VALVE_INDEX
}

@export var controller_profile: ControllerProfile = ControllerProfile.META_QUEST
@export var move_speed: float = 4.0
@export var snap_turn_angle: float = 45.0
# 3x jump height: peak height ~3.8m (was ~1.27m at 5.0m/s)
@export var jump_velocity: float = 8.8
@export var gravity: float = 10.5

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var left_hand_offset: Node3D = get_node_or_null("XROrigin3D/LeftController/LeftHandOffset")
@onready var right_hand_offset: Node3D = get_node_or_null("XROrigin3D/RightController/RightHandOffset")

var is_xr_active: bool = false
var _can_snap_turn: bool = true
var _prev_q_pressed: bool = false
var _prev_e_pressed: bool = false

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
	# Dedicated VR Jump on A, B, X, Y buttons or primary stick click
	if button_name == "ax_button" or button_name == "by_button" or button_name == "primary_click":
		if is_on_floor():
			velocity.y = jump_velocity

func _physics_process(delta: float) -> void:
	# Gravity & Jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
		# Desktop jump fallback on Space / Enter
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER):
			velocity.y = jump_velocity

	# Locomotion Movement (Left Stick / WASD)
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

	if input_vec != Vector2.ZERO:
		var cam_basis := xr_camera.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		
		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()
		
		var move_dir := (right * input_vec.x + forward * input_vec.y).normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 6.0)

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
