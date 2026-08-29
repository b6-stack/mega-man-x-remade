extends Area3D
class_name BusterShot

@export var charge_level: int = 1:
	set(value):
		charge_level = clampi(value, 1, 3)
		if is_node_ready():
			_update_shot_properties()

@export var speed: float = 24.0
@export var damage: float = 1.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var light: OmniLight3D = $OmniLight3D

var _lifetime: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_update_shot_properties()

func _update_shot_properties() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true

	match charge_level:
		1:
			# Lemon / Small Pellet
			damage = 1.0
			speed = 22.0
			scale = Vector3(0.12, 0.12, 0.22)
			mat.albedo_color = Color(1.0, 0.95, 0.2, 1.0)
			mat.emission = Color(1.0, 0.9, 0.1)
			mat.emission_energy_multiplier = 4.0
			if light:
				light.light_color = Color(1.0, 0.9, 0.2)
				light.light_energy = 1.5
				light.omni_range = 2.0
		2:
			# Medium Charge / Greenish-Blue Plasma
			damage = 2.5
			speed = 26.0
			scale = Vector3(0.24, 0.24, 0.42)
			mat.albedo_color = Color(0.15, 0.95, 0.85, 1.0)
			mat.emission = Color(0.1, 1.0, 0.8)
			mat.emission_energy_multiplier = 6.0
			if light:
				light.light_color = Color(0.2, 1.0, 0.85)
				light.light_energy = 3.0
				light.omni_range = 3.5
		3:
			# Heavy / Max Charge - Pink / Cyan Mega Blast
			damage = 5.0
			speed = 30.0
			scale = Vector3(0.45, 0.45, 0.72)
			mat.albedo_color = Color(1.0, 0.25, 0.85, 1.0)
			mat.emission = Color(1.0, 0.3, 0.9)
			mat.emission_energy_multiplier = 8.0
			if light:
				light.light_color = Color(1.0, 0.3, 0.85)
				light.light_energy = 5.0
				light.omni_range = 5.0

	if mesh_instance:
		mesh_instance.material_override = mat

func _physics_process(delta: float) -> void:
	# Move forward along negative local Z
	global_position += -global_transform.basis.z * speed * delta
	
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
	queue_free()
