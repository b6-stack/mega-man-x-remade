extends Node3D
class_name PauseMenu

signal resumed
signal restarted
signal quitted

@onready var sub_viewport: SubViewport = $SubViewport
@onready var menu_quad: MeshInstance3D = $MenuQuad
@onready var resume_btn: Button = $SubViewport/Control/Panel/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $SubViewport/Control/Panel/VBoxContainer/RestartButton
@onready var quit_btn: Button = $SubViewport/Control/Panel/VBoxContainer/QuitButton

var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if sub_viewport:
		sub_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	if sub_viewport and menu_quad:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mat.render_priority = 100
		mat.albedo_texture = sub_viewport.get_texture()
		menu_quad.material_override = mat

	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func open(cam_transform: Transform3D) -> void:
	is_active = true
	visible = true
	var forward := -cam_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	
	global_position = cam_transform.origin + forward * 1.3 + Vector3(0, -0.05, 0)
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
	get_tree().call_deferred("reload_current_scene")

func _on_quit_pressed() -> void:
	get_tree().paused = false
	emit_signal("quitted")
	get_tree().call_deferred("quit")

func handle_pointer_click(uv: Vector2) -> void:
	if not sub_viewport or not is_inside_tree() or not sub_viewport.is_inside_tree():
		return
	var vp_size: Vector2 = sub_viewport.size
	var pixel_pos := Vector2(uv.x * vp_size.x, uv.y * vp_size.y)
	
	var ev_press := InputEventMouseButton.new()
	ev_press.position = pixel_pos
	ev_press.global_position = pixel_pos
	ev_press.button_index = MOUSE_BUTTON_LEFT
	ev_press.pressed = true
	sub_viewport.push_input(ev_press)

	if is_inside_tree() and sub_viewport and sub_viewport.is_inside_tree():
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
