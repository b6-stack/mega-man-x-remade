extends Node3D
class_name GameOverMenu

signal restarted
signal quitted

@onready var sub_viewport: SubViewport = $SubViewport
@onready var menu_quad: MeshInstance3D = $MenuQuad
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
		mat.albedo_texture = sub_viewport.get_texture()
		menu_quad.material_override = mat

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
	
	global_position = cam_transform.origin + forward * 1.4 + Vector3(0, -0.05, 0)
	look_at(global_position + forward, Vector3.UP)

func _on_restart_pressed() -> void:
	emit_signal("restarted")
	get_tree().call_deferred("reload_current_scene")

func _on_quit_pressed() -> void:
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
