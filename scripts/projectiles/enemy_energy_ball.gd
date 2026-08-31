extends Area3D
class_name EnemyEnergyBall

@export var speed: float = 11.0
@export var damage: int = 1
@export var lifetime: float = 5.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $GPUParticles3D

var _timer: float = 0.0
var _spawn_grace_timer: float = 0.15
var _is_destroyed: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	
	if _spawn_grace_timer > 0.0:
		_spawn_grace_timer -= delta
	
	global_position += -global_transform.basis.z * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	_handle_impact(body)

func _on_area_entered(area: Area3D) -> void:
	_handle_impact(area)

func _handle_impact(target: Node3D) -> void:
	if _is_destroyed or not is_instance_valid(target):
		return
	
	if _spawn_grace_timer > 0.0 and (target is ShootingTargetDummy or target is StaticBody3D):
		return
	
	if target is VRPlayer or (target.get_parent() and target.get_parent() is VRPlayer):
		var player: VRPlayer = target as VRPlayer if target is VRPlayer else target.get_parent() as VRPlayer
		player.take_damage(damage, global_position)
		_explode()
	elif target is StaticBody3D or target is CSGShape3D:
		_explode()

func take_damage(_amount: float, _hit_pos: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.ZERO) -> bool:
	if _is_destroyed:
		return false
	_explode()
	return true

func _explode() -> void:
	_is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if mesh: mesh.visible = false
	if light: light.visible = false
	if particles:
		particles.emitting = false
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.05)
	tween.tween_callback(queue_free)
