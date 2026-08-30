extends Node3D
class_name GameOverMenu

signal restarted
signal quitted

@onready var restart_btn: Button = $SubViewport/Control/VBoxContainer/RestartButton
@onready var quit_btn: Button = $SubViewport/Control/VBoxContainer/QuitButton
@onready var sub_viewport: SubViewport = $SubViewport

var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func open(cam_transform: Transform3D) -> void:
	is_active = true
	visible = true
	var forward := -cam_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	global_position = cam_transform.origin + forward * 1.4 + Vector3(0, 0.0, 0)
	look_at(global_position + forward, Vector3.UP)

func _on_restart_pressed() -> void:
	emit_signal("restarted")
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	emit_signal("quitted")
	get_tree().quit()

func handle_pointer_click(uv: Vector2) -> void:
	var vp_size: Vector2 = sub_viewport.size
	var pixel_pos := Vector2(uv.x * vp_size.x, uv.y * vp_size.y)
	var ev_press := InputEventMouseButton.new()
	ev_press.position = pixel_pos
	ev_press.global_position = pixel_pos
	ev_press.button_index = MOUSE_BUTTON_LEFT
	ev_press.pressed = true
	sub_viewport.push_input(ev_press)

	var ev_release := InputEventMouseButton.new()
	ev_release.position = pixel_pos
	ev_release.global_position = pixel_pos
	ev_release.button_index = MOUSE_BUTTON_LEFT
	ev_release.pressed = false
	sub_viewport.push_input(ev_release)
