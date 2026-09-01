extends Area3D
class_name TrackingMissile

const IMPACT_SPLASH_SCENE: PackedScene = preload("res://scenes/effects/impact_splash.tscn")

@export var speed: float = 7.8
@export var turn_speed: float = 3.0
@export var damage: int = 1
@export var lifetime: float = 3.5
@export var tracking_duration: float = 2.0
@export var max_health: float = 1.0

@onready var mesh_root: Node3D = $Visuals
@onready var exhaust_particles: GPUParticles3D = $Visuals/Exhaust
@onready var light: OmniLight3D = $OmniLight3D

var _timer: float = 0.0
var _spawn_grace_timer: float = 0.20
var _is_destroyed: bool = false
var _target_player: Node3D = null
var _can_track: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_find_player()

func _find_player() -> void:
	if get_tree().current_scene:
		var cam := get_tree().current_scene.find_child("XRCamera3D", true, false) as Node3D
		if cam and is_instance_valid(cam):
			_target_player = cam
			return
		var p := get_tree().current_scene.find_child("VRPlayer", true, false) as Node3D
		if p and is_instance_valid(p):
			_target_player = p

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	
	if _spawn_grace_timer > 0.0:
		_spawn_grace_timer -= delta
	
	_timer += delta
	if _timer >= lifetime:
		_explode()
		return
	
	# Stop tracking after tracking_duration expires
	if _timer >= tracking_duration:
		_can_track = false
	
	if not _target_player or not is_instance_valid(_target_player):
		_find_player()
	
	if _can_track and _target_player and is_instance_valid(_target_player):
		var target_pos := _target_player.global_position
		if _target_player is VRPlayer or _target_player.name == "VRPlayer":
			target_pos.y += 1.1
		
		var to_target := (target_pos - global_position).normalized()
		var current_forward := -global_transform.basis.z
		
		# If the missile has flown past the player, break tracking so it doesn't circle forever
		if _timer > 0.4 and to_target.dot(current_forward) < -0.15:
			_can_track = false
		else:
			# Smoothly rotate forward (-Z) towards player
			var new_forward := current_forward.slerp(to_target, turn_speed * delta).normalized()
			if new_forward.length_squared() > 0.001:
				var target_look := global_position + new_forward
				var up_axis := Vector3.UP if abs(new_forward.y) < 0.95 else Vector3.FORWARD
				look_at(target_look, up_axis)
	
	global_position += -global_transform.basis.z * speed * delta
	
	if mesh_root:
		mesh_root.rotate_z(delta * 12.0)

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
	if _is_destroyed:
		return
	_is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	if IMPACT_SPLASH_SCENE:
		var splash := IMPACT_SPLASH_SCENE.instantiate()
		var p := get_tree().current_scene if get_tree().current_scene else get_parent()
		p.add_child(splash)
		splash.global_position = global_position
	
	if mesh_root: mesh_root.visible = false
	if light: light.visible = false
	if exhaust_particles: exhaust_particles.emitting = false
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.04)
	tween.tween_callback(queue_free)
