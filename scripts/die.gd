extends RigidBody3D
class_name Die3D

var is_rolling: bool = false
var value: int = 0

@export var locked: bool = false

# Limite de tolerância: 1.0 é perfeito, abaixo de 0.9 geralmente significa inclinado
@export var tolerance: float = 0.95 

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var sound_hit: AudioStreamPlayer3D = $SoundHit

signal roll_finished(die: Die3D, value: int) 
signal die_selected(die: Die3D)

func _ready() -> void:
	input_event.connect(_on_input_event)

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_rolling:
			emit_signal("die_selected", self)

func disable_collision() -> void:
	collision_shape_3d.disabled = true
func enable_collision() -> void:
	collision_shape_3d.disabled = false

func roll(force: float = 10.0) -> void:
	if locked: return
	sleeping = false
	is_rolling = true
	# Resetamos o modo de física para garantir que ele responda a impulsos
	freeze = false 
	apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1)) * force)
	apply_torque_impulse(Vector3(randf_range(2, 5), randf_range(2, 5), randf_range(2, 5)) * force)
	
func _physics_process(_delta: float) -> void:
	if is_rolling and sleeping:
		is_rolling = false		
		_check_and_fix_alignment()

func _get_vector_up() -> Dictionary:
	var b: Basis = global_transform.basis.orthonormalized()
	var faces: Dictionary = {
		4: b.y,
		3: -b.y,
		2: b.z,
		5: -b.z,
		1: b.x,
		6: -b.x
	}
	
	var max_dot: float = -1.1
	var winner_value: int = -1
	var winner_vector: Vector3 = Vector3.ZERO
	
	for v in faces:
		var dot = faces[v].dot(Vector3.UP)
		if dot > max_dot:
			max_dot = dot
			winner_value = v
			winner_vector = faces[v] # Vetor local da face que ganhou
	
	return { "value": winner_value, "vector": winner_vector, "dot": max_dot }

func _check_and_fix_alignment() -> void:
	
	var ret: Dictionary = _get_vector_up()
	var max_dot: float = ret.dot
	var winner_value: int = ret.value
	var winner_vector: Vector3 = ret.vector
	
	# Se o dot for menor que a tolerância, o dado está "de lado"
	if max_dot < tolerance:
		_nudge_die(winner_vector, winner_value)
	else:
		_finalize_roll(winner_value)

func _nudge_die(target_local_vector: Vector3, winner_value: int) -> void:
	# 1. Parar a física temporariamente para não brigar com a animação
	freeze = true
	
	# 2. Calcular a rotação necessária para alinhar o vetor da face com o Vector3.UP
	var current_dir = target_local_vector
	var target_dir = Vector3.UP
	
	# Uma forma mais precisa é usar quaternions para rotacionar do atual para o alvo
	var q_from = global_transform.basis.get_rotation_quaternion()
	var q_to = Quaternion(current_dir, target_dir) * q_from
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_basis", Basis(q_to), 0.25)
	
	# 3. Após a animação, finalizamos
	tween.finished.connect(func():		
		_finalize_roll(winner_value)
	)

func _finalize_roll(final_value: int) -> void:
	await get_tree().create_timer(0.2).timeout
	value = final_value
	roll_finished.emit(self, value)
	
func snap_to_closest(target_val: float, list: Array) -> float:
	if list.size() == 0: return target_val

	var closest = list[0]
	for item in list:
		if abs(item - target_val) < abs(closest - target_val):
			closest = item
	return closest

func move_to_position(target: Vector3) -> void:
	# Ativa freeza para a física não interferir no movimento
	freeze = true
	disable_collision()
	
	var up_vector = _get_vector_up()
	var rotation_axis: Vector3 = up_vector.vector.cross(Vector3.UP).normalized()
	var rotation_angle: float = acos(up_vector.vector.dot(Vector3.UP))
	
	var quat: Quaternion = Quaternion(up_vector.vector, Vector3.UP)
	var target_basis: Basis = Basis(quat) * global_transform.basis.orthonormalized() 
	
	var possible_values: Array[int] = [-270, -180, -90, 0, 90, 180, 270]
	var x_rot = snap_to_closest(global_rotation_degrees.x, possible_values)
	var y_rot = snap_to_closest(global_rotation_degrees.y, possible_values)
	var z_rot = snap_to_closest(global_rotation_degrees.z, possible_values)
	var target_rotation = Vector3(x_rot, y_rot, z_rot)
	
	var tween = create_tween()
	tween.set_parallel(true) # move e rotaciona ao mesmo tempo
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Move para o destino
	tween.tween_property(self, "global_position", target, 0.4)
	tween.tween_property(self, "global_rotation_degrees", target_rotation, 0.2)
	
	tween.finished.connect(func(): 
		enable_collision()
		freeze = false
	)


func _on_body_entered(body: Node) -> void:
	var force: float = linear_velocity.length()
	print("Force,", force)
	if force > 2.1:
		var volume = remap(force, 0.5, 10.0, -20.0, 0.0)
		sound_hit.volume_db = volume
		# Adiciona uma leve variação de pitch para o som não ser repetitivo (naturalidade)
		sound_hit.pitch_scale = randf_range(0.9, 1.1)
		sound_hit.play()
