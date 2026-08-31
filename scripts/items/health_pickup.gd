extends Area3D
class_name HealthPickup

@export var heal_amount: int = 1
@export var respawn_time: float = 6.0
@export var bob_amplitude: float = 0.08
@export var bob_speed: float = 2.5
@export var rotate_speed: float = 1.8

@onready var orb_mesh: MeshInstance3D = get_node_or_null("Visuals/CoreOrb")
@onready var particles: GPUParticles3D = get_node_or_null("Visuals/Particles")

var _base_y: float = 0.0
var _time_passed: float = 0.0
var _is_collected: bool = false
var _respawn_timer: float = 0.0

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_time_passed = randf() * 10.0

func _process(delta: float) -> void:
	if _is_collected:
		if respawn_time > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return
	
	_time_passed += delta
	position.y = _base_y + sin(_time_passed * bob_speed) * bob_amplitude
	rotate_y(rotate_speed * delta)
	
	if orb_mesh and orb_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = orb_mesh.material_override
		var pulse: float = sin(_time_passed * 4.0) * 0.5 + 0.5
		mat.emission_energy_multiplier = lerpf(5.0, 9.0, pulse)

func _on_body_entered(body: Node3D) -> void:
	_try_pickup(body)

func _try_pickup(target: Node) -> void:
	if _is_collected or not is_instance_valid(target):
		return
	
	var player: VRPlayer = null
	if target is VRPlayer:
		player = target
	elif target.get_parent() and target.get_parent() is VRPlayer:
		player = target.get_parent() as VRPlayer
	
	if player and is_instance_valid(player) and player.has_method("heal"):
		if player.current_health < player.max_health:
			_is_collected = true
			var healed = player.heal(heal_amount)
			if healed:
				_collect()
			else:
				_is_collected = false

func _collect() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		if respawn_time > 0.0:
			_respawn_timer = respawn_time
		else:
			queue_free()
	)

func _respawn() -> void:
	_is_collected = false
	visible = true
	scale = Vector3.ZERO
	position.y = _base_y
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
