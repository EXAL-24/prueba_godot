extends Area3D

const CASQUILLO: PackedScene = preload("uid://5kurr8x8ex38")

func _ready() -> void:
	_configurar_sombras()

func disparar() -> void:
	expulsar_casquillo()

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

func expulsar_casquillo() -> void:
	var expulsor: Node3D = get_node_or_null("Casquillo") as Node3D
	if expulsor == null:
		return

	await get_tree().process_frame  # garantiza transform actual si el expulsor sigue animación/hueso

	var instancia = CASQUILLO.instantiate()
	if instancia == null:
		return

	get_tree().current_scene.add_child(instancia)

	var t: Transform3D = expulsor.global_transform
	var dir: Vector3 = (t.basis * Vector3(-1.0, 0.35, 0.15)).normalized()
	var eject_offset: float = 0.06

	# Coloca el casquillo justo fuera del expulsor
	instancia.global_transform = t.translated(dir * eject_offset)

	if instancia is RigidBody3D:
		var rb: RigidBody3D = instancia as RigidBody3D
		rb.linear_velocity = dir * 2.5
		rb.angular_velocity = Vector3(
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0),
			randf_range(-12.0, 12.0)
		)
		rb.sleeping = false

	# Vida útil del casquillo
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(instancia):
			instancia.queue_free()
	)
