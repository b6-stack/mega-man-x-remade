extends StaticBody3D
class_name ArmoredTargetDummy

@export var is_armored: bool = true

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var shield_plate: MeshInstance3D = $MeshInstance3D/ShieldPlate

var _deflect_flash_timer: float = 0.0

func _process(delta: float) -> void:
	if _deflect_flash_timer > 0.0:
		_deflect_flash_timer -= delta
		if _deflect_flash_timer <= 0.0:
			if shield_plate:
				shield_plate.material_override = null

func take_damage(_amount: float, _hit_pos: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.ZERO) -> bool:
	# Armored: Blocks ALL levels of buster shots (Level 1, Level 2, Level 3)
	_flash_shield_deflect()
	return false

func _flash_shield_deflect() -> void:
	_deflect_flash_timer = 0.08
	if shield_plate:
		var flash_mat := StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.albedo_color = Color(1.0, 0.85, 0.3, 1.0)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.8, 0.2, 1.0)
		flash_mat.emission_energy_multiplier = 4.0
		shield_plate.material_override = flash_mat
