extends CharacterBody3D
class_name VRPlayer

enum ControllerProfile {
	GENERIC_OPENXR,
	META_QUEST,
	VALVE_INDEX
}

@export var controller_profile: ControllerProfile = ControllerProfile.META_QUEST
@export var move_speed: float = 4.0
@export var turn_speed: float = 2.0
@export var gravity: float = 9.8

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var left_hand_offset: Node3D = get_node_or_null("XROrigin3D/LeftController/LeftHandOffset")
@onready var right_hand_offset: Node3D = get_node_or_null("XROrigin3D/RightController/RightHandOffset")

var is_xr_active: bool = false

func _ready() -> void:
	_apply_controller_profile()
	_init_openxr()

func _apply_controller_profile() -> void:
	# Calibrate tracking offsets based on VR controller profile
	match controller_profile:
		ControllerProfile.META_QUEST:
			# Meta Quest Touch: grip offset ~+0.08m along Z, -12 deg pitch for natural wrist alignment
			if left_hand_offset:
				left_hand_offset.position = Vector3(0, -0.015, 0.085)
				left_hand_offset.rotation_degrees = Vector3(-12, 0, 0)
			if right_hand_offset:
				right_hand_offset.position = Vector3(0, -0.015, 0.085)
				right_hand_offset.rotation_degrees = Vector3(-12, 0, 0)
		ControllerProfile.VALVE_INDEX:
			# Valve Index Knuckles: steeper handle angle, closer pivot
			if left_hand_offset:
				left_hand_offset.position = Vector3(0, -0.02, 0.06)
				left_hand_offset.rotation_degrees = Vector3(-20, 0, 0)
			if right_hand_offset:
				right_hand_offset.position = Vector3(0, -0.02, 0.06)
				right_hand_offset.rotation_degrees = Vector3(-20, 0, 0)
		ControllerProfile.GENERIC_OPENXR:
			# Default standard OpenXR aim pose
			if left_hand_offset:
				left_hand_offset.position = Vector3(0, 0, 0.08)
				left_hand_offset.rotation_degrees = Vector3(0, 0, 0)
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

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var input_vec := Vector2.ZERO
	
	# Left controller thumbstick input if in XR
	if is_xr_active and left_controller:
		var thumbstick: Vector2 = left_controller.get_vector2("primary")
		if thumbstick.length() < 0.1:
			thumbstick = left_controller.get_vector2("thumbstick")
		input_vec = thumbstick
	
	# Desktop WASD fallback
	if input_vec == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W): input_vec.y += 1.0
		if Input.is_key_pressed(KEY_S): input_vec.y -= 1.0
		if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
		if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
		input_vec = input_vec.normalized()

	# Calculate movement relative to camera direction
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
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)

	# Right controller turn input (smooth turn)
	if is_xr_active and right_controller:
		var r_stick: Vector2 = right_controller.get_vector2("primary")
		if r_stick.length() < 0.1:
			r_stick = right_controller.get_vector2("thumbstick")
		if abs(r_stick.x) > 0.2:
			rotate_y(-r_stick.x * turn_speed * delta)

	move_and_slide()
