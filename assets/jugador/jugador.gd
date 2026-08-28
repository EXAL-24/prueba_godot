extends CharacterBody3D
class_name Jugador

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SPRINT_MULTIPLIER = 1.8

@export var sensibilidad: float = 0.003
@export var aim_smooth_speed: float = 12.0 # ajuste de suavizado al apuntar (mayor = más rápido)

@onready var cabeza_pivot: Node3D = $Personaje/CabezaPivot
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_brazo_derecho: AnimationPlayer = $AnimationPlayerBrazoDerecho
@onready var anim_brazo_izquierdo: AnimationPlayer = $AnimationPlayerBrazoIzquierdo
@onready var anim_piernas: AnimationPlayer = $AnimationPlayerPiernas
@onready var brazo_izquierdo_pivot: Node3D = $Personaje/BrazoIzquierdoPivot
@onready var pistola: Area3D = $Personaje/BrazoIzquierdoPivot/brazo_izquierdo/Armas/pistola

var sprint_activado: bool = false
var animacion_activa: bool = false
var arma_sacada: bool = false
var está_apuntando: bool = false

func _ready() -> void:
	anim_player.animation_finished.connect(_on_animation_finished)
	pistola.visible = false
	arma_sacada = false
	está_apuntando = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("derecha", "izquierda", "atrás", "adelante")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var intenta_saltar := Input.is_action_just_pressed("saltar") and is_on_floor()
	var intenta_moverse := direction.length() > 0

	if animacion_activa and (intenta_moverse or intenta_saltar):
		anim_player.play("RESET")
		anim_player.advance(0)
		animacion_activa = false

	if animacion_activa:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	if intenta_saltar:
		velocity.y = JUMP_VELOCITY

	var va_hacia_adelante: bool = input_dir.y > 0
	var velocidad_actual: float = SPEED

	if está_apuntando == true:
		velocidad_actual *= 0.25
	elif sprint_activado and va_hacia_adelante:
		velocidad_actual *= SPRINT_MULTIPLIER

	if direction:
		velocity.x = direction.x * velocidad_actual
		velocity.z = direction.z * velocidad_actual

		if sprint_activado and va_hacia_adelante:
			anim_brazo_derecho.play("correr_brazo_derecho")
			anim_piernas.play("correr_piernas")
			if not está_apuntando:
				_sincronizar_brazo_izquierdo("correr_brazo_izquierdo")
		elif not sprint_activado and not está_apuntando:
			anim_brazo_derecho.play("andar_brazo_derecho")
			anim_piernas.play("andar_piernas")
			if not está_apuntando:
				_sincronizar_brazo_izquierdo("andar_brazo_izquierdo")
		elif está_apuntando:
			anim_brazo_derecho.play("shifteando_brazo_derecho")
			anim_piernas.play("shifteando_piernas")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

		anim_brazo_derecho.play("reposo_brazo_derecho")
		anim_piernas.play("reposo_piernas")
		if not está_apuntando:
			_sincronizar_brazo_izquierdo("reposo_brazo_izquierdo")

	# Si estamos apuntando, aplicamos la interpolación cada frame (suavizado)
	if está_apuntando:
		actualizar_apuntado(delta)

	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("sprint"):
		sprint_activado = !sprint_activado

	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * sensibilidad
		cabeza_pivot.rotation.x += event.relative.y * sensibilidad
		cabeza_pivot.rotation.x = clamp(cabeza_pivot.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

	if event.is_action_pressed("1"):
		toggle_pistola()

	if event.is_action_pressed("Apuntar") and arma_sacada:
		está_apuntando = true
		anim_brazo_izquierdo.stop()
		# No llamamos a actualizar_apuntado inmediatamente aquí: _physics_process lo hará suavemente

	if event.is_action_released("Apuntar") and está_apuntando:
		está_apuntando = false
		_actualizar_animacion_brazo_izquierdo()

	if event.is_action_pressed("Disparar") and arma_sacada:
		var script_pistola = pistola.get_script()
		if script_pistola != null and pistola.has_method("disparar"):
			pistola.call("disparar")

	if velocity.is_zero_approx() and not animacion_activa:
		if event.is_action_pressed("animación_1"):
			animacion_activa = true
			_detener_animaciones_extremidades()
			anim_player.play("polvo")
		elif event.is_action_pressed("animación_2"):
			animacion_activa = true
			_detener_animaciones_extremidades()
			anim_player.play("a_cuatro")

func toggle_pistola() -> void:
	arma_sacada = not arma_sacada
	pistola.visible = arma_sacada

	if not arma_sacada:
		está_apuntando = false
		anim_brazo_izquierdo.stop()
		brazo_izquierdo_pivot.rotation = Vector3(0.0, 0.0, -0.0004363358)
		_actualizar_animacion_brazo_izquierdo()
	else:
		está_apuntando = false
		_actualizar_animacion_brazo_izquierdo()

# Ahora recibe delta para interpolar suavemente
func actualizar_apuntado(delta: float) -> void:
	if not arma_sacada:
		return

	var target_rot := Vector3(-PI / 2.0 + cabeza_pivot.rotation.x, -0.0004363358, 0.0)
	var cur := brazo_izquierdo_pivot.rotation
	var t = clamp(delta * aim_smooth_speed, 0.0, 1.0)

	brazo_izquierdo_pivot.rotation.x = lerp_angle(cur.x, target_rot.x, t)
	brazo_izquierdo_pivot.rotation.y = lerp_angle(cur.y, target_rot.y, t)
	brazo_izquierdo_pivot.rotation.z = lerp_angle(cur.z, target_rot.z, t)

func _actualizar_animacion_brazo_izquierdo() -> void:
	if está_apuntando:
		anim_brazo_izquierdo.stop()
		return

	var input_dir := Input.get_vector("derecha", "izquierda", "atrás", "adelante")
	var va_hacia_adelante: bool = input_dir.y > 0
	var moviendose: bool = input_dir.length() > 0.0

	if moviendose and sprint_activado and va_hacia_adelante:
		_sincronizar_brazo_izquierdo("correr_brazo_izquierdo")
	elif moviendose:
		_sincronizar_brazo_izquierdo("andar_brazo_izquierdo")
	else:
		_sincronizar_brazo_izquierdo("reposo_brazo_izquierdo")

func _sincronizar_brazo_izquierdo(nombre_animacion: String) -> void:
	if está_apuntando:
		return
	anim_brazo_izquierdo.play(nombre_animacion)
	anim_brazo_izquierdo.seek(anim_brazo_derecho.current_animation_position, true)

func _detener_animaciones_extremidades() -> void:
	anim_brazo_derecho.stop()
	anim_brazo_izquierdo.stop()
	anim_piernas.stop()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "polvo" or anim_name == "a_cuatro":
		anim_player.play("RESET")
		anim_player.advance(0)
		animacion_activa = false
