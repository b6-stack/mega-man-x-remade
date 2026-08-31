extends Area3D
class_name CombatTriggerPad

@export var linked_dummy: ShootingTargetDummy = null
@export var pad_color_inactive: Color = Color(0.1, 0.5, 0.8, 1.0)
@export var pad_color_active: Color = Color(1.0, 0.4, 0.05, 1.0)

@onready var plate_mesh: MeshInstance3D = $PlateMesh
@onready var border_mesh: MeshInstance3D = $BorderMesh
@onready var light: OmniLight3D = $OmniLight3D

var is_active: bool = false
var _time_passed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_pad_visuals()

func _process(delta: float) -> void:
	_time_passed += delta
	if is_active:
		var pulse: float = sin(_time_passed * 6.0) * 0.5 + 0.5
		if border_mesh and border_mesh.material_override is StandardMaterial3D:
			border_mesh.material_override.emission_energy_multiplier = lerpf(4.0, 9.0, pulse)
		if light:
			light.light_energy = lerpf(3.0, 6.5, pulse)

func _on_body_entered(body: Node3D) -> void:
	if body is VRPlayer or (body.get_parent() and body.get_parent() is VRPlayer):
		is_active = true
		if linked_dummy:
			linked_dummy.set_triggered(true)
		_update_pad_visuals()

func _on_body_exited(body: Node3D) -> void:
	if body is VRPlayer or (body.get_parent() and body.get_parent() is VRPlayer):
		is_active = false
		if linked_dummy:
			linked_dummy.set_triggered(false)
		_update_pad_visuals()

func _update_pad_visuals() -> void:
	var active_col: Color = pad_color_active if is_active else pad_color_inactive
	var energy: float = 5.0 if is_active else 1.8
	
	if border_mesh:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = active_col
		mat.emission_enabled = true
		mat.emission = active_col
		mat.emission_energy_multiplier = energy
		border_mesh.material_override = mat
	
	if light:
		light.light_color = active_col
		light.light_energy = 3.5 if is_active else 1.2
