extends Node3D
class_name Board

@onready var Die_Scene: PackedScene = preload("res://scenes/Die.tscn")
@onready var dice_container: Node3D = $DiceContainer
@onready var reserve_marker: Marker3D = $Reserve/ReserveMarker
@onready var camera: CustomCamera = $CameraPivot

signal roll_finished(result: Array[int]) 

var lock_mouse_event: bool = false
var rolling: int = 0

func _ready() -> void:
	for i in range(5):
		var die:Die3D = Die_Scene.instantiate()
		die.name = "Die-" + str(i)
		die.global_position = Vector3(i * 2 - 4,1.0,0.0)
		die.connect("die_selected", _on_die_selected)
		die.connect("roll_finished", _on_die_roll_finished)
		dice_container.add_child(die)

func _on_die_roll_finished(die: Die3D, value: int) -> void:
	rolling -= 1
	print ("Die roll finished: ", rolling, " result: ", die.value)
	if rolling == 0:
		emit_signal("roll_finished", get_dice_values())
	
	
func _on_die_selected(die: Die3D) -> void:
	if lock_mouse_event: return
	lock_mouse_event = true
	if die.locked: 
		_move_die_to_board(die)
	else:
		_move_die_to_reserve(die)		
	
	await get_tree().create_timer(0.4).timeout
	lock_mouse_event = false
	
	
func _move_die_to_reserve(die: Die3D) -> void:
	var dice: Array[Die3D] = _get_dice()
	var locked: Array[Die3D] = dice.filter(func(d): return d.locked)
	for i in range(5):	
		var target: Vector3 = reserve_marker.global_position + Vector3(i * 1.2, 0.0, 0.0)	
		var is_free = _is_spot_free(target)
		#print(target, ' - ', is_free)
		if is_free:
			die.move_to_position(target)
			die.locked = true
			return

func _move_die_to_board(die: Die3D) -> void:
	var target: Vector3 = _find_random_spot()
	die.move_to_position(target)
	die.locked = false

func _get_random_spot() -> Vector3:
	return Vector3(randf_range(-5, 5), 1.5, randf_range(-5, 5))

func _find_random_spot() -> Vector3:
	var target = _get_random_spot()
	if _is_spot_free(target):
		return target
	else:
		return _find_random_spot()
	
func _is_spot_free(test_pos: Vector3) -> bool:
	
	# Acessa o estado direto do mundo físico
	var space_state = get_world_3d().direct_space_state
	
	# Criamos um parâmetro de checagem (uma esfera de colisão invisível)
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.6 # Um pouco maior que o dado
	query.shape = sphere
	query.transform = Transform3D(Basis(), test_pos)
	query.collision_mask = 2
	
	# Verifica se há algo nesse local
	var result = space_state.intersect_shape(query)

	return result.is_empty()

func _get_dice() -> Array[Die3D]:
	var ret: Array[Die3D] = []
	for node: Node in dice_container.get_children():
		ret.append(node as Die3D)
	return ret

func _get_dice_on_reserve() -> Array[Die3D]:
	return _get_dice().filter(func (die): return die.locked)
	
func _get_dice_on_table() -> Array[Die3D]:
	return _get_dice().filter(func (die): return !die.locked)

func can_roll() -> bool:
	return _get_dice_on_table().size() > 0

func reset_dice() -> void:
	for die:Die3D in _get_dice_on_reserve():
		_move_die_to_board(die)
		
func roll_dice() -> void:
	rolling = 0
	for die:Die3D in _get_dice_on_table():
		die.roll()
		rolling += 1
	print("Rolling: ", rolling, " dice")
	
func get_dice_values() -> Array[int]:
	var ret: Array[int] = []
	for die:Die3D in _get_dice():
		ret.append(die.value)
	return ret
	
func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body is Die3D:
		print('Killed die: ', body)
		_move_die_to_board(body)
