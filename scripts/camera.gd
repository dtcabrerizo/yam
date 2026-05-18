extends Node3D
class_name CustomCamera

@export var rotate_speed := 0.01
@export var pan_speed := 0.05
@export var zoom_speed := 1.0

@export var min_zoom := -7.0
@export var max_zoom := 20.0

# --- CONFIGURAÇÕES DE TOUCH ---
@export var touch_zoom_speed := 0.02
var _touches := {}
var _last_touch_count := 0 # Trava de segurança para evitar o "salto" ao levantar os dedos

var rotating := false
var panning := false

var default_position : Vector3
var default_rotation : Vector3
var default_zoom : float

@onready var camera := $Camera3D

func _ready():
	default_position = global_position
	default_rotation = rotation
	default_zoom = camera.position.z

func _unhandled_input(event: InputEvent) -> void:
	
	# =========================================================================
	# 1. CONTROLES DE MOUSE (DESKTOP) - Mantidos originais
	# =========================================================================
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom(zoom_speed)

	if event is InputEventMouseMotion:
		if rotating:
			rotation.y -= event.relative.x * rotate_speed
			rotation.x -= event.relative.y * rotate_speed
			rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(-10)) 

		if panning:
			var yaw = rotation.y
			var right = Vector3(cos(yaw), 0, -sin(yaw))
			var forward = Vector3(sin(yaw), 0, cos(yaw))
			global_position -= right * event.relative.x * pan_speed
			global_position -= forward * event.relative.y * pan_speed

	# =========================================================================
	# 2. CONTROLES DE TOQUE (MOBILE WEB / NATIVO) - Novos & Simplificados
	# =========================================================================
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		
		# Atualiza a contagem imediatamente no toque/soltura para preparar a trava
		_last_touch_count = _touches.size()

	if event is InputEventScreenDrag:
		# Pega a posição anterior do dedo antes de atualizar o dicionário (usado no Zoom)
		var prev_pos = _touches.get(event.index, event.position - event.relative)
		_touches[event.index] = event.position
		
		# [SISTEMA ANTISALTO] Se a quantidade de dedos mudou neste frame (ex: tirou um dedo),
		# nós ignoramos o movimento atual para evitar que a câmera seja teleportada.
		if _touches.size() != _last_touch_count:
			_last_touch_count = _touches.size()
			return
		
		# GESTO DE 1 DEDO: Apenas mover (Pan) a mesa
		if _touches.size() == 1:
			var yaw = rotation.y
			var right = Vector3(cos(yaw), 0, -sin(yaw))
			var forward = Vector3(sin(yaw), 0, cos(yaw))
			
			# Move usando o deslocamento relativo do arrasto
			global_position -= right * event.relative.x * pan_speed
			global_position -= forward * event.relative.y * pan_speed
			
		# GESTO DE 2 DEDOS: Apenas dar Zoom (Pinch)
		elif _touches.size() == 2:
			var indices = _touches.keys()
			var other_index = indices[1] if event.index == indices[0] else indices[0]
			var other_pos = _touches.get(other_index, Vector2.ZERO)
			
			if other_pos != Vector2.ZERO:
				# Calcula a variação de distância entre os dois dedos ativos
				var current_dist = event.position.distance_to(other_pos)
				var prev_dist = prev_pos.distance_to(other_pos)
				var zoom_delta = prev_dist - current_dist
				
				zoom(zoom_delta * touch_zoom_speed)
				
		_last_touch_count = _touches.size()

	# Atalho de teclado para resetar
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			reset_view()

func zoom(amount):
	camera.position.z = clamp(camera.position.z + amount, min_zoom, max_zoom)

func reset_view():
	global_position = default_position
	rotation = default_rotation
	camera.position.z = default_zoom

func move_camera(position: Vector3, zoom_val: float) -> void: 
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_parallel()
	tween.tween_property(self, "global_position", position, 1.0)
	tween.tween_property(camera, "position:z", zoom_val, 1.0)
