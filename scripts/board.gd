extends Node3D
class_name Board

@onready var Die_Scene: PackedScene = preload("res://scenes/Die.tscn")
@onready var dice_container: Node3D = $DiceContainer
@onready var reserve_marker: Marker3D = $Reserve/ReserveMarker
@onready var camera: CustomCamera = $CameraPivot

# Indicates that the available dice roll has finished and have a value 
signal roll_finished(result: Array[int]) 

# Locks the mouse interactio to avoid moving two dice to the reserve at the same time 
# (to avoid stacking)
var lock_mouse_event: bool = false
# Counts how many results the board is still waiting finish roll 
var rolling: int = 0

func _ready() -> void:
	# Creates 5 dice objets and connects its events
	for i in range(5):
		var die:Die3D = Die_Scene.instantiate()
		die.name = "Die-" + str(i)
		die.global_position = Vector3(i * 2 - 4,1.0,0.0)
		die.connect("die_selected", _on_die_selected)
		die.connect("roll_finished", _on_die_roll_finished)
		dice_container.add_child(die)

# Handles the result of a single die roll
func _on_die_roll_finished(die: Die3D, value: int) -> void:
	# Reduces the amount of expected reults 
	rolling -= 1
	print ("Die roll finished: ", rolling, " result: ", die.value)
	# If the board have all the results it was expecting, emits a signal with all the values
	if rolling == 0:
		emit_signal("roll_finished", get_dice_values())
	
# Handles a click on a single die
func _on_die_selected(die: Die3D) -> void:
	# If the mouse interaction is locked (to avoid stacking) or the die has not been rolled, ignore
	if lock_mouse_event or !die.rolled: return
	# Stop receiving click events
	lock_mouse_event = true
	# If the die is on reserve, move to the board
	if die.locked: 
		_move_die_to_board(die)
	else:
		# If the die is on board, move to reserve
		_move_die_to_reserve(die)		
	
	# Add a timer to avoid stacking dices moved to reserve/board
	# (board rarely occur, but reserve can happen) 
	await get_tree().create_timer(0.4).timeout
	
	# Resets the mouse event control
	lock_mouse_event = false
	
# Move a single die from the board to the reserve
func _move_die_to_reserve(die: Die3D) -> void:
	# Find a spot on the reserve to alocate this die
	
	# There are 5 possible spots on the reserve
	for i in range(5):
		# Get spot coordinates
		var target: Vector3 = reserve_marker.global_position + Vector3(i * 1.2, 0.0, 0.0)	
		# Check if the spot is free
		var is_free = _is_spot_free(target)
		if is_free:
			# If is free, move die to the spot position
			die.move_to_position(target)
			# Lock die so it won't participate on next roll
			die.locked = true
			# Stop loop
			return

# Move a single die from reserve to board 
func _move_die_to_board(die: Die3D) -> void:
	# Find a random free spot on the board
	var target: Vector3 = _find_random_spot()
	# Move the die to the position on board
	die.move_to_position(target)
	# Unlock die so it will participate on the next roll (if any)
	die.locked = false

# Get a random spot on the board
func _get_random_spot() -> Vector3:
	return Vector3(randf_range(-5, 5), 1.5, randf_range(-5, 5))

# Find a (Random) free spot on the board
func _find_random_spot() -> Vector3:
	# Get a random spot on the board
	var target = _get_random_spot()
	# If the spot is free, return
	if _is_spot_free(target):
		return target
	else:
		# Try again
		return _find_random_spot()
	
# Check if a spot (position) is free on the board 
func _is_spot_free(test_pos: Vector3) -> bool:
	
	# Access the direct space state of the physics world
	var space_state = get_world_3d().direct_space_state
	
	# Create a sphere to check the space
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.6 # A little bigger than a single die
	query.shape = sphere
	query.transform = Transform3D(Basis(), test_pos)
	query.collision_mask = 2 # It should collide only with other dice
	
	# Check if the sphere intersects with other shapes
	var result = space_state.intersect_shape(query)
	# If there were no intersections the spot (sphere) is free
	return result.is_empty()

# Get all 5 dice
func _get_dice() -> Array[Die3D]:
	var ret: Array[Die3D] = []
	for node: Node in dice_container.get_children():
		ret.append(node as Die3D)
	return ret
# Get die on reserve (locked)
func _get_dice_on_reserve() -> Array[Die3D]:
	return _get_dice().filter(func (die): return die.locked)
# Get die on the board (not locked)
func _get_dice_on_table() -> Array[Die3D]:
	return _get_dice().filter(func (die): return !die.locked)

# Check if the board is ready to execute a new roll
func can_roll() -> bool:
	# If there is at least one die on table
	return _get_dice_on_table().size() > 0

# Resets the dice status, movin them to the board
func reset_dice() -> void:
	for die:Die3D in _get_dice():
		die.rolled = false # Resets the interaction control
		# If the die is on reserve, nove to the table
		if die.locked:
			_move_die_to_board(die)

# Start a new roll
func roll_dice() -> void:
	# Resets the roll count
	rolling = 0
	# Roll all the dice on table and update counter
	for die:Die3D in _get_dice_on_table():
		die.roll()
		rolling += 1
	print("Rolling: ", rolling, " dice")

# Get the current dice value (the result of the last roll)
# NOTE: A map function could be used here
func get_dice_values() -> Array[int]:
	var ret: Array[int] = []
	for die:Die3D in _get_dice():
		ret.append(die.value)
	return ret

# Checks if a die fell of the table and crossed the "killzone", and restores it to the table
# This used to happen on older versions, but the walls now are higher
func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body is Die3D:
		print('Killed die: ', body)
		_move_die_to_board(body)
