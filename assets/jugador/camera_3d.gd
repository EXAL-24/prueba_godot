extends Camera3D


var camaras: Array[Camera3D] = []
var indice_actual := 0
var posiciones_normales: Array[Vector3] = []
const MASCARA_MAPA := 1
const MARGEN_COLISION := 0.12


func _ready() -> void:
	camaras = [
		$".",
		$"../Camera_3ra",
		$"../Camera_2da",
	]
	posiciones_normales = [
		camaras[0].position,
		camaras[1].position,
		camaras[2].position,
	]


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("cambiar_persona"):
		indice_actual = (indice_actual + 1) % camaras.size()
		camaras[indice_actual].make_current()

	# Evita que las cámaras exteriores atraviesen paredes del mapa.
	# La cámara en primera persona permanece en su posición original.
	for i in range(1, camaras.size()):
		actualizar_colision_camara(camaras[i], posiciones_normales[i])


func actualizar_colision_camara(camara: Camera3D, posicion_objetivo: Vector3) -> void:
	var origen := global_position
	var objetivo := camara.get_parent_node_3d().to_global(posicion_objetivo)
	var desplazamiento := objetivo - origen
	var distancia := desplazamiento.length()

	if distancia <= 0.001:
		camara.position = posicion_objetivo
		return

	var consulta := PhysicsRayQueryParameters3D.create(origen, objetivo)
	consulta.collision_mask = MASCARA_MAPA
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var jugador := get_owner()
	if jugador is CollisionObject3D:
		consulta.exclude = [jugador.get_rid()]

	var resultado := get_world_3d().direct_space_state.intersect_ray(consulta)

	if resultado.is_empty():
		camara.position = posicion_objetivo
		return

	var distancia_segura: float = maxf(float(resultado["position"].distance_to(origen)) - MARGEN_COLISION, 0.05)
	var punto_seguro := origen + desplazamiento.normalized() * minf(distancia_segura, distancia)
	camara.position = camara.get_parent_node_3d().to_local(punto_seguro)
