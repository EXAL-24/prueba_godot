# name=bullet.gd
extends RigidBody3D

@export var post_impact_unfreeze_delay: float = 0.02
@export var stick_on_impact: bool = false  # true = queda clavada en la superficie (visual), false = se para y luego cae
var _last_pos: Vector3
var _impacted: bool = false

func _ready() -> void:
	_last_pos = global_transform.origin
	_impacted = false
	gravity_scale = 1.0
	linear_damp = 0.0
	angular_damp = 0.1

func _physics_process(delta: float) -> void:
	if _impacted:
		return

	var next_pos: Vector3 = global_transform.origin + linear_velocity * delta

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	params.from = _last_pos
	params.to = next_pos
	params.exclude = [self]

	var result: Dictionary = space.intersect_ray(params)
	if not result.is_empty():
		var hit_pos: Vector3 = result.get("position") as Vector3
		var collider: Object = result.get("collider")
		_handle_impact(hit_pos, collider, result)
	else:
		_last_pos = global_transform.origin


func _handle_impact(hit_pos: Vector3, collider: Object, result: Dictionary) -> void:
	# Colocamos la bala exactamente en el punto de impacto y la paramos
	global_transform = Transform3D(global_transform.basis, hit_pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_impacted = true

	# Si queremos "clavar" visualmente la bala en la superficie (sin física),
	# intentamos duplicar el MeshInstance3D hijo (si existe) y parentarlo al collider.
	if stick_on_impact and collider is Node:
		var node_collider: Node = collider as Node
		# Buscar un MeshInstance3D hijo típico llamado "Mesh" (ajusta el nombre si tu escena usa otro)
		var mesh_inst: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
		if mesh_inst != null:
			var mesh_copy: MeshInstance3D = mesh_inst.duplicate() as MeshInstance3D
			# Calculamos la transform local respecto al collider
			if node_collider is Node3D:
				var local_t: Transform3D = (node_collider as Node3D).global_transform.affine_inverse() * Transform3D(global_transform.basis, hit_pos)
				node_collider.add_child(mesh_copy)
				mesh_copy.transform = local_t
				# Liberamos la body física original (ya no es necesaria)
				queue_free()
				return
		# Si no había mesh para duplicar, como fallback parentamos la propia RigidBody al collider,
		# la paramos y la mantenemos (visual) como child del collider.
		if is_instance_valid(self) and node_collider is Node:
			var prev_parent: Node = get_parent()
			if prev_parent != null:
				prev_parent.remove_child(self)
			node_collider.add_child(self)
			global_transform = Transform3D(global_transform.basis, hit_pos)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			sleeping = true
			return

	# Si no queremos que quede clavada, dejamos que la gravedad la mueva tras un breve delay
	await get_tree().create_timer(post_impact_unfreeze_delay).timeout
	if is_instance_valid(self):
		# Permitimos que la física (gravedad) la mueva si no está apoyada
		sleeping = false
