extends Node3D
class_name EnergyGauge

@export var max_health: int = 8:
	set(value):
		max_health = clampi(value, 1, 32)
		if is_inside_tree():
			_rebuild_gauge()

@export var current_health: int = 8:
	set(value):
		current_health = clampi(value, 0, max_health)
		if is_inside_tree():
			_update_pips()

@export var pip_spacing: float = 0.0055
@export var pip_length: float = 0.0035
@export var pip_width: float = 0.012
@export var pip_height: float = 0.003
@export var margin_z: float = 0.004
@export var margin_x: float = 0.003

var gauge_back: MeshInstance3D = null
var _segments: Array[MeshInstance3D] = []
var _lit_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	_rebuild_gauge()

func _init_materials() -> void:
	_lit_mat = StandardMaterial3D.new()
	_lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lit_mat.albedo_color = Color(1.0, 0.90, 0.08, 1.0)
	_lit_mat.emission_enabled = true
	_lit_mat.emission = Color(1.0, 0.88, 0.05, 1.0)
	_lit_mat.emission_energy_multiplier = 4.0

	_dark_mat = StandardMaterial3D.new()
	_dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_dark_mat.albedo_color = Color(0.10, 0.10, 0.12, 1.0)
	_dark_mat.metallic = 0.8
	_dark_mat.roughness = 0.4

func _rebuild_gauge() -> void:
	# Clear existing segment instances
	for seg in _segments:
		if is_instance_valid(seg):
			seg.queue_free()
	_segments.clear()

	for child in get_children():
		if child.name.begins_with("Segment"):
			child.queue_free()

	# Calculate tight margin bounding box for GaugeBack
	var total_span_z: float = (max_health - 1) * pip_spacing + pip_length
	var back_len_z: float = total_span_z + 2.0 * margin_z
	var back_width_x: float = pip_width + 2.0 * margin_x
	var back_height_y: float = pip_height + 0.002

	gauge_back = get_node_or_null("GaugeBack") as MeshInstance3D
	if not gauge_back:
		gauge_back = MeshInstance3D.new()
		gauge_back.name = "GaugeBack"
		add_child(gauge_back)

	var back_box := BoxMesh.new()
	back_box.size = Vector3(back_width_x, back_height_y, back_len_z)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.05, 0.05, 0.07, 1.0)
	back_mat.metallic = 0.9
	back_mat.roughness = 0.25
	back_box.material = back_mat
	gauge_back.mesh = back_box

	# Instantiate health pips along Z
	var start_z: float = (total_span_z * 0.5) - (pip_length * 0.5)
	var pip_mesh := BoxMesh.new()
	pip_mesh.size = Vector3(pip_width, pip_height, pip_length)

	for i in range(max_health):
		var seg := MeshInstance3D.new()
		seg.name = "Segment" + str(i + 1)
		seg.mesh = pip_mesh
		var z_pos: float = start_z - (i * pip_spacing)
		seg.position = Vector3(0.0, back_height_y * 0.5 + 0.001, z_pos)
		add_child(seg)
		_segments.append(seg)

	_update_pips()

func set_health(current: int, max_val: int = -1) -> void:
	if max_val > 0 and max_val != max_health:
		max_health = max_val
	current_health = clampi(current, 0, max_health)
	_update_pips()

func _update_pips() -> void:
	if not _lit_mat:
		_init_materials()
	
	for i in range(_segments.size()):
		var seg := _segments[i]
		if is_instance_valid(seg):
			if i < current_health:
				seg.material_override = _lit_mat
			else:
				seg.material_override = _dark_mat
