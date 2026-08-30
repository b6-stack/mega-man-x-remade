extends Node3D
class_name LaserPointer

@export var max_distance: float = 6.0

@onready var beam_mesh: MeshInstance3D = $Beam
@onready var dot_mesh: MeshInstance3D = $Dot

var is_active: bool = false
var _controller: XRController3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_controller = _find_controller()
	if _controller:
		_controller.button_pressed.connect(_on_controller_button)

func _find_controller() -> XRController3D:
	var p: Node = get_parent()
	while p:
		if p is XRController3D:
			return p as XRController3D
		p = p.get_parent()
	return null

func set_active(active: bool) -> void:
	is_active = active
	visible = active

func _process(_delta: float) -> void:
	if not is_active:
		visible = false
		return
	
	visible = true
	var space_state := get_world_3d().direct_space_state
	var from_pos: Vector3 = global_position
	var to_pos: Vector3 = global_position + (-global_transform.basis.z * max_distance)
	
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 8
	
	var hit_dist: float = max_distance
	var result := space_state.intersect_ray(query) if space_state else {}
	
	if not result.is_empty():
		var hit_pos: Vector3 = result.position
		hit_dist = from_pos.distance_to(hit_pos)
		if dot_mesh:
			dot_mesh.visible = true
			dot_mesh.position = Vector3(0, 0, -hit_dist)
	else:
		if dot_mesh:
			dot_mesh.visible = false

	if beam_mesh:
		beam_mesh.scale = Vector3(1, hit_dist, 1)
		beam_mesh.position = Vector3(0, 0, -hit_dist * 0.5)

func _on_controller_button(button_name: String) -> void:
	if not is_active:
		return
	if button_name == "trigger_click" or button_name == "trigger" or button_name == "ax_button" or button_name == "primary_click":
		_trigger_click()

func _trigger_click() -> void:
	var space_state := get_world_3d().direct_space_state
	var from_pos: Vector3 = global_position
	var to_pos: Vector3 = global_position + (-global_transform.basis.z * max_distance)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 8
	var result := space_state.intersect_ray(query) if space_state else {}
	
	if not result.is_empty():
		var collider: Object = result.collider
		var menu = collider.get_parent()
		if menu and menu.has_method("handle_pointer_click"):
			var local_hit: Vector3 = menu.to_local(result.position)
			var uv := Vector2((local_hit.x / 1.2) + 0.5, 0.5 - (local_hit.y / 0.8))
			menu.handle_pointer_click(uv)
