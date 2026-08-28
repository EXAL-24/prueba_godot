extends Area3D

const CASQUILLO: PackedScene = preload("uid://5kurr8x8ex38")

# Asigna la escena de la bala en el Inspector (deja vacío para usar hitscan)
@export var BALA: PackedScene = null
@export var MAX_RANGE: float = 200.0
@export var BULLET_SPEED: float = 120.0

# Dispersión en grados: hip-fire (no apuntando) y apuntando
@export var HIP_SPREAD_DEG: float = 6.0
@export var AIM_SPREAD_DEG: float = 1.0

func _ready() -> void:
	_configurar_sombras()

# Llamar desde Jugador: pistola.disparar(esta_apuntando)
func disparar(is_aiming: bool = false) -> void:
	# expulsar casquillo (world parent) y disparar proyectil/hitscan
	expulsar_casquillo()
	_shoot(is_aiming)


# ------------------ expulsar casquillo ------------------

func expulsar_casquillo() -> void:
	var expulsor: Node3D = get_node_or_null("Casquillo") as Node3D
	if expulsor == null:
		return

	# Esperar un frame para asegurar transform actualizado si depende de huesos/animaciones
	await get_tree().process_frame

	var instancia: Node = CASQUILLO.instantiate()
	if instancia == null:
		return

	# Parentar al root de la escena (para que el casquillo no siga a la pistola)
	var world_parent: Node = get_tree().current_scene
	if world_parent == null:
		world_parent = get_tree().get_root()
	world_parent.add_child(instancia)

	var transform_expulsor: Transform3D = expulsor.global_transform
	var dir: Vector3 = (transform_expulsor.basis * Vector3(-1.0, 0.35, 0.15)).normalized()
	var eject_offset: float = 0.06

	# Posicionar en espacio mundial (desacoplado)
	if instancia is Node3D:
		var nodo3d: Node3D = instancia as Node3D
		nodo3d.global_transform = transform_expulsor.translated(dir * eject_offset)
	else:
		instancia.global_transform = transform_expulsor.translated(dir * eject_offset)

	if instancia is RigidBody3D:
		var rb: RigidBody3D = instancia as RigidBody3D
		rb.linear_velocity = dir * 2.5
		rb.angular_velocity = Vector3(
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0)
		)
		rb.sleeping = false

	# Auto-limpieza
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(instancia):
			instancia.queue_free()
	)


# ------------------ disparo (proyectil o hitscan) ------------------

func _shoot(is_aiming: bool) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_shoot_fallback(is_aiming)
		return

	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var ray_origin: Vector3 = cam.project_ray_origin(screen_center)
	var ray_dir: Vector3 = cam.project_ray_normal(screen_center).normalized()

	var spread_deg: float
	if is_aiming:
		spread_deg = AIM_SPREAD_DEG
	else:
		spread_deg = HIP_SPREAD_DEG

	var aim_dir: Vector3 = _random_dir_in_cone(ray_dir, spread_deg)
	var target_point: Vector3 = ray_origin + aim_dir * MAX_RANGE

	if BALA != null:
		_spawn_projectile_from_muzzle(aim_dir, target_point)
	else:
		_perform_hitscan(ray_origin, aim_dir)


func _shoot_fallback(is_aiming: bool) -> void:
	var expulsor: Node3D = get_node_or_null("Casquillo") as Node3D
	if expulsor == null:
		return

	var forward: Vector3 = (expulsor.global_transform.basis * Vector3(-1.0, 0.0, 0.0)).normalized()

	var spread_deg: float
	if is_aiming:
		spread_deg = AIM_SPREAD_DEG
	else:
		spread_deg = HIP_SPREAD_DEG

	var aim_dir: Vector3 = _random_dir_in_cone(forward, spread_deg)

	if BALA != null:
		_spawn_projectile_from_muzzle(aim_dir, expulsor.global_transform.origin + aim_dir * MAX_RANGE)
	else:
		_perform_hitscan(expulsor.global_transform.origin, aim_dir)


func _spawn_projectile_from_muzzle(dir: Vector3, target_point: Vector3) -> void:
	var expulsor: Node3D = get_node_or_null("Casquillo") as Node3D
	if expulsor == null:
		# fallback: usar la transform de la propia pistola si no hay expulsor
		expulsor = self as Node3D

	await get_tree().process_frame

	var instancia: Node = BALA.instantiate()
	if instancia == null:
		return

	# Parentar al world
	var world_parent: Node = get_tree().current_scene
	if world_parent == null:
		world_parent = get_tree().get_root()
	world_parent.add_child(instancia)

	# Poner en muzzle (global) y dar velocidad si es RigidBody3D
	var transform_muzzle: Transform3D = expulsor.global_transform
	var eject_offset: float = 0.06
	if instancia is Node3D:
		var nodo3d: Node3D = instancia as Node3D
		nodo3d.global_transform = transform_muzzle.translated(dir * eject_offset)

		if instancia is RigidBody3D:
			var rb: RigidBody3D = instancia as RigidBody3D
			rb.linear_velocity = dir.normalized() * BULLET_SPEED
			rb.sleeping = false
		else:
			# Si no es física, movemos visualmente hacia target con un tween
			var distance: float = nodo3d.global_transform.origin.distance_to(target_point)
			var travel_time: float = 0.0
			if BULLET_SPEED > 0.0:
				travel_time = distance / BULLET_SPEED
			else:
				travel_time = 0.0
			_move_node_towards(nodo3d, target_point, travel_time)
	else:
		# fallback global transform
		instancia.global_transform = transform_muzzle.translated(dir * eject_offset)

	# Auto-limpieza
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		if is_instance_valid(instancia):
			instancia.queue_free()
	)


func _perform_hitscan(origin: Vector3, dir: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var to: Vector3 = origin + dir.normalized() * MAX_RANGE

	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = to
	params.exclude = [self]

	var result: Dictionary = space.intersect_ray(params)
	if not result.is_empty():
		var pos: Vector3 = result.get("position") as Vector3
		var collider: Object = result.get("collider") as Object
		if collider != null and collider.has_method("impact"):
			collider.call_deferred("impact", pos, dir)
		var normal: Vector3 = result.get("normal", Vector3.UP) as Vector3
		_spawn_impact_effect(pos, normal)


func _spawn_impact_effect(pos: Vector3, normal: Vector3) -> void:
	# Implementa partículas/decals si quieres
	return


# Mueve un Node3D hacia 'target' usando SceneTreeTween (para balas no físicas)
func _move_node_towards(node: Node3D, target: Vector3, travel_time: float) -> void:
	if travel_time <= 0.0:
		node.global_position = target
		return
	var tw = get_tree().create_tween()
	tw.tween_property(node, "global_position", target, travel_time)


# Genera una dirección aleatoria dentro de un cono alrededor de 'dir' (en grados)
func _random_dir_in_cone(dir: Vector3, max_angle_deg: float) -> Vector3:
	var max_angle: float = deg_to_rad(max_angle_deg)
	if max_angle <= 0.0:
		return dir.normalized()
	var cos_max: float = cos(max_angle)
	var cos_theta: float = randf_range(cos_max, 1.0)
	var theta: float = acos(cos_theta)
	var phi: float = randf() * TAU
	var x: float = sin(theta) * cos(phi)
	var y: float = sin(theta) * sin(phi)
	var z: float = cos_theta
	var local: Vector3 = Vector3(x, y, z)
	var forward: Vector3 = dir.normalized()
	var up: Vector3 = Vector3.UP
	if abs(forward.dot(up)) > 0.999:
		up = Vector3.RIGHT
	var right: Vector3 = forward.cross(up).normalized()
	var real_up: Vector3 = right.cross(forward).normalized()
	var world_dir: Vector3 = (right * local.x) + (real_up * local.y) + (forward * local.z)
	return world_dir.normalized()


# ------------------ helper: sombras (opcional) ------------------

func _configurar_sombras() -> void:
	var mesh_instance: MeshInstance3D = get_node_or_null("Pistola") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var material: Material = mesh_instance.get_surface_override_material(surface)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(surface)
		if material is BaseMaterial3D:
			if not material.disable_receive_shadows:
				var copia: BaseMaterial3D = material.duplicate() as BaseMaterial3D
				if copia != null:
					copia.disable_receive_shadows = true
					mesh_instance.set_surface_override_material(surface, copia)
			else:
				mesh_instance.set_surface_override_material(surface, material)
