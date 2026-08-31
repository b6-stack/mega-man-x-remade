extends Area3D
class_name HealthPickup

@export var heal_amount: int = 1
@export var bob_amplitude: float = 0.08
@export var bob_speed: float = 2.5
@export var rotate_speed: float = 1.8

@onready var orb_mesh: MeshInstance3D = get_node_or_null("Visuals/CoreOrb")
@onready var particles: GPUParticles3D = get_node_or_null("Visuals/Particles")

var _base_y: float = 0.0
var _time_passed: float = 0.0
var _is_collected: bool = false

func _ready() -> void:
	_base_y = position.y
	# Connect collision detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Randomize initial phase so multiple pickups don't bob in identical sync
	_time_passed = randf() * 10.0

func _process(delta: float) -> void:
	if _is_collected:
		return
	
	_time_passed += delta
	# Floating bob animation
	position.y = _base_y + sin(_time_passed * bob_speed) * bob_amplitude
	# Smooth rotation
	rotate_y(rotate_speed * delta)
	
	# Subtle energy core pulse
	if orb_mesh and orb_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = orb_mesh.material_override
		var pulse: float = sin(_time_passed * 4.0) * 0.5 + 0.5
		mat.emission_energy_multiplier = lerpf(5.0, 9.0, pulse)

func _on_body_entered(body: Node3D) -> void:
	_try_pickup(body)

func _on_area_entered(area: Area3D) -> void:
	_try_pickup(area)
	if area.get_parent():
		_try_pickup(area.get_parent())

func _try_pickup(target: Node) -> void:
	if _is_collected or not is_instance_valid(target):
		return
	
	var player: VRPlayer = null
	if target is VRPlayer:
		player = target
	elif target.has_method("heal"):
		player = target as VRPlayer
	elif target.get_parent() and target.get_parent() is VRPlayer:
		player = target.get_parent() as VRPlayer
	
	if player and player.has_method("heal"):
		if player.heal(heal_amount):
			_collect()

func _collect() -> void:
	_is_collected = true
	# Turn off collision
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Quick scale-down pop
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
