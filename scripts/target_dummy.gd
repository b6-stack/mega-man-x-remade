extends StaticBody3D
class_name TargetDummy

@export var max_health: float = 6.0
@export var respawn_time: float = 3.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var current_health: float = 6.0
var _orig_material: Material
var _flash_timer: float = 0.0
var _is_destroyed: bool = false
var _respawn_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	if mesh_instance:
		_orig_material = mesh_instance.get_active_material(0)

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and not _is_destroyed:
			if mesh_instance and _orig_material:
				mesh_instance.material_override = null

	if _is_destroyed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()

func take_damage(amount: float) -> void:
	if _is_destroyed:
		return

	current_health -= amount
	_flash_hit()

	if current_health <= 0:
		_destroy()

func _flash_hit() -> void:
	_flash_timer = 0.15
	if mesh_instance:
		var flash_mat := StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.4, 0.4)
		flash_mat.emission_energy_multiplier = 4.0
		mesh_instance.material_override = flash_mat

func _destroy() -> void:
	_is_destroyed = true
	_respawn_timer = respawn_time
	visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func _respawn() -> void:
	_is_destroyed = false
	current_health = max_health
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if mesh_instance:
		mesh_instance.material_override = null
