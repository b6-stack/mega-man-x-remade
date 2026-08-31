extends StaticBody3D
class_name ShootingTargetDummy

enum WeaponType {
	ENERGY_BALL,
	TRACKING_MISSILE
}

const ENERGY_BALL_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_energy_ball.tscn")
const TRACKING_MISSILE_SCENE: PackedScene = preload("res://scenes/projectiles/tracking_missile.tscn")

@export var weapon_type: WeaponType = WeaponType.ENERGY_BALL
@export var fire_interval: float = 1.8
@export var max_health: float = 8.0
@export var respawn_time: float = 4.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var cannon_eye: MeshInstance3D = $CannonEye
@onready var muzzle: Marker3D = $Muzzle
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var current_health: float = 8.0
var is_triggered: bool = false
var is_enemy: bool = true
var _fire_timer: float = 0.0
var _charge_flash_timer: float = 0.0
var _is_destroyed: bool = false
var _respawn_timer: float = 0.0
var _flash_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	_fire_timer = 0.6

func set_triggered(active: bool) -> void:
	is_triggered = active
	if active and _fire_timer <= 0.2:
		_fire_timer = 0.4

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and not _is_destroyed and mesh_instance:
			mesh_instance.material_override = null

	if _is_destroyed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if not is_triggered:
		return

	# Aim at player camera
	var player_cam := _get_player_node()
	if player_cam:
		var to_cam := player_cam.global_position - global_position
		to_cam.y += 0.2
		if to_cam.length_squared() > 0.001:
			var target_look := global_position - to_cam.normalized()
			look_at(target_look, Vector3.UP)

	# Firing sequence
	_fire_timer -= delta
	if _fire_timer <= 0.35 and _fire_timer > 0.0:
		# Muzzle charge pre-flash
		if cannon_eye and cannon_eye.material_override is StandardMaterial3D:
			cannon_eye.material_override.emission_energy_multiplier = 12.0
	
	if _fire_timer <= 0.0:
		_fire_weapon()
		_fire_timer = fire_interval
		if cannon_eye and cannon_eye.material_override is StandardMaterial3D:
			cannon_eye.material_override.emission_energy_multiplier = 4.0

func _get_player_node() -> Node3D:
	if get_tree().current_scene:
		var cam := get_tree().current_scene.find_child("XRCamera3D", true, false) as Node3D
		if cam: return cam
		var p := get_tree().current_scene.find_child("VRPlayer", true, false) as Node3D
		if p: return p
	return null

func _fire_weapon() -> void:
	var scene_to_spawn: PackedScene = ENERGY_BALL_SCENE if weapon_type == WeaponType.ENERGY_BALL else TRACKING_MISSILE_SCENE
	if not scene_to_spawn:
		return
	
	var proj = scene_to_spawn.instantiate()
	var current_scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	current_scene.add_child(proj)
	
	if muzzle:
		proj.global_transform = muzzle.global_transform
	else:
		proj.global_transform = global_transform

func take_damage(amount: float, _hit_pos: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.ZERO) -> bool:
	if _is_destroyed:
		return false
	
	current_health -= amount
	_flash_hit()
	
	if current_health <= 0:
		_destroy()
	return true

func _flash_hit() -> void:
	_flash_timer = 0.10
	if mesh_instance:
		var flash_mat := StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 1.0, 1.0, 1.0)
		flash_mat.emission_energy_multiplier = 6.0
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
