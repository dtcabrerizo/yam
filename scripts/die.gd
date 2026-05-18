extends RigidBody3D
class_name Die3D

@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D
@onready var sound_hit: AudioStreamPlayer3D = $SoundHit

# Die controls
@export var locked: bool = false	# Locked = on reserve, Not Locked = on board
@export var rolled: bool = false	# Rolled = can be moved, Not Locked = cannot be moved
@export var value: int = 0 		 	# Value of the last roll

# Tolerance limit to determine if a dice is perfect aligned (1.0)
@export var tolerance: float = 0.95 

# Indicates if the die is still rolling
var is_rolling: bool = false

signal roll_finished(die: Die3D, value: int) 
signal die_selected(die: Die3D)

func _ready() -> void:
	# Connect the input event to intercept a die click
	input_event.connect(_on_input_event)

# Handles click on a die
func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	# If the event is a mouse left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# If is not rolling, emit the signal of a die being selected
		if not is_rolling:
			emit_signal("die_selected", self)

# Disables the collision to avoid hitting other dice (Moving to reserve)
func disable_collision() -> void:
	collision_shape_3d.disabled = true
# Enable the collision with other dice (Moving to table)
func enable_collision() -> void:
	collision_shape_3d.disabled = false

# Start a roll, applying a force (the default 10.0 is enough)
func roll(force: float = 10.0) -> void:
	# If the die is on reserve, dont roll it
	if locked: return
	# Resets the sleeping flag to stop calculating physics
	sleeping = false
	# Set the control to indicate that this die is rolling
	is_rolling = true
	# Reset the physics mode to turn gravvity and other forces off
	freeze = false 
	
	# Apply two random impulses to the die, one to the center of mass and another so the die will rotate
	# Scale those impulses by the parameter "force" 
	apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(0.5, 1), randf_range(-1, 1)) * force)
	apply_torque_impulse(Vector3(randf_range(2, 5), randf_range(2, 5), randf_range(2, 5)) * force)
	

func _physics_process(_delta: float) -> void:
	# Check if the die has finished rolling and it is "sleeping"
	if is_rolling and sleeping:
		# Resets the control 
		is_rolling = false	
		# Apply the rules to align the die with the floor axis	
		_check_and_fix_alignment()

# Get which vector represents the UP axis definig which value the die is displaying
func _get_vector_up() -> Dictionary:
	# Get the global_transform basis, the die is aligned with the default UP axis being Y+ (with a value of 4)
	# The other faces should sum 7 (regular die)
	var b: Basis = global_transform.basis.orthonormalized()
	var faces: Dictionary = {
		4: b.y,		# Y+ = 4
		3: -b.y,	# Y- = 3
		2: b.z,		# Z+ = 2
		5: -b.z,	# Z- = 5
		1: b.x,		# X+ = 1
		6: -b.x		# X- = 6
	}
	
	# Calculate the max_dot, comparing the dot vetor to determine which side is closest to Vector3.UP 
	# For each die face calculate the dot vector with Vector3.UP, the higher result is the closest 
	var max_dot: float = -1.1
	var winner_value: int = -1
	var winner_vector: Vector3 = Vector3.ZERO
	
	for v in faces:
		var dot = faces[v].dot(Vector3.UP)
		if dot > max_dot:
			max_dot = dot
			winner_value = v
			winner_vector = faces[v] # Vetor local da face que ganhou
	
	# Return a dictionary indicating the calculated value (value), the calculated vector (vector) and the resulting dot operation(dot)
	return { "value": winner_value, "vector": winner_vector, "dot": max_dot }

# Apply rules to align the die with the floor axis
func _check_and_fix_alignment() -> void:
	
	#  Get which vector represents the UP axis definig which value the die is displaying
	var ret: Dictionary = _get_vector_up()
	var max_dot: float = ret.dot
	var winner_value: int = ret.value
	var winner_vector: Vector3 = ret.vector
	
	# If the dot operation resulted a value lower than the tolerance the die is inclined and need to be adjusted
	if max_dot < tolerance:
		_nudge_die(winner_vector, winner_value)
	else:
		# If the die is aligned with the floor axis finalize the roll action 
		_finalize_roll(winner_value)

# Adjust the die with the floow axis
func _nudge_die(target_local_vector: Vector3, winner_value: int) -> void:
	# Stop the physics process
	freeze = true
	
	# Calculate the rotation needed to align the returned face vector with Vector3.UP
	var current_dir = target_local_vector
	var target_dir = Vector3.UP
	
	# Use quaternions to rotate the current direction to the target directtion (Vector3.UP) 
	var q_from = global_transform.basis.get_rotation_quaternion()
	var q_to = Quaternion(current_dir, target_dir) * q_from
	
	# Animate the die adjustment setting the basis to the target quaternion
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_basis", Basis(q_to), 0.25)
	
	# After the animation finalize the roll action
	tween.finished.connect(func():		
		_finalize_roll(winner_value)
	)

# Finalize the roll action
func _finalize_roll(final_value: int) -> void:
	# Add a wait timer so the die  was calculated completely
	# THis is used to make sure that other die won't move this one
	await get_tree().create_timer(0.2).timeout
	# Adjust the die varables 
	value = final_value
	rolled = true
	# Emits the signal indicating that this die was rolled and has a value
	roll_finished.emit(self, value)
	
# Force a value to be enclosed in a list by choosing the closest one
# TODO: Maybe Godot has a native function for this
func _snap_to_closest(target_val: float, list: Array) -> float:
	if list.size() == 0: return target_val

	var closest = list[0]
	for item in list:
		if abs(item - target_val) < abs(closest - target_val):
			closest = item
	return closest

# Move die to a specific position with animation
func move_to_position(target: Vector3) -> void:
	# Stops physics and collision so it won't interact with other objects during animation
	freeze = true
	disable_collision()
	
	
	# Define the desired rotation on the found axis, snaping to a "perfect" rotation aligned with the objects on the scene
	var possible_values: Array[int] = [-270, -180, -90, 0, 90, 180, 270]
	var x_rot = _snap_to_closest(global_rotation_degrees.x, possible_values)
	var y_rot = _snap_to_closest(global_rotation_degrees.y, possible_values)
	var z_rot = _snap_to_closest(global_rotation_degrees.z, possible_values)
	var target_rotation = Vector3(x_rot, y_rot, z_rot)
	
	# Initiate the move animation
	var tween = create_tween()
	tween.set_parallel(true) # move e rotaciona ao mesmo tempo
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Moves and rotates to the destination
	tween.tween_property(self, "global_position", target, 0.4)
	tween.tween_property(self, "global_rotation_degrees", target_rotation, 0.2)
	
	# After the animation finishes enable collision and physics
	tween.finished.connect(func(): 
		enable_collision()
		freeze = false
	)


# Detect die collision with walls, floor and other dice
func _on_body_entered(_body: Node) -> void:
	# Get the current velocity to calculate the impact
	var force: float = linear_velocity.length()
	# If the impact is grater than 2.1 a sound should be played
	# NOTE: 2.1 is arbitrary as the minimum force of a die being moved from reserve to the table
	if force > 2.1:
		# Define the volume of the sound to be proportional to the impact force
		var volume = remap(force, 0.5, 10.0, -20.0, 0.0)
		sound_hit.volume_db = volume
		# Add a small pitch variation so the sound won't be repetitive and creating naturality
		sound_hit.pitch_scale = randf_range(0.9, 1.1)
		# Play the sound
		sound_hit.play()
