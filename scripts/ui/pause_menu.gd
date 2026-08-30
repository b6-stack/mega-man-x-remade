extends Node3D
class_name PauseMenu

signal resumed
signal restarted
signal quitted

@onready var resume_btn: Button = $SubViewport/Control/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $SubViewport/Control/VBoxContainer/RestartButton
@onready var quit_btn: Button = $SubViewport/Control/VBoxContainer/QuitButton
@onready var sub_viewport: SubViewport = $SubViewport
@onready var menu_quad: MeshInstance3D = $MenuQuad

var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func open(cam_transform: Transform3D) -> void:
	is_active = true
	visible = true
	# Position 1.5m in front of camera at eye level
	var forward := -cam_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	global_position = cam_transform.origin + forward * 1.5 + Vector3(0, 0.0, 0)
	look_at(global_position + forward, Vector3.UP)
	get_tree().paused = true

func close() -> void:
	is_active = false
	visible = false
	get_tree().paused = false
	emit_signal("resumed")

func _on_resume_pressed() -> void:
	close()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	emit_signal("restarted")
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().paused = false
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
