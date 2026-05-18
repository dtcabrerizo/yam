extends Node3D
class_name CustomCamera

@onready var camera := $Camera3D

# Camera parameters
@export var rotate_speed := 0.01
@export var pan_speed := 0.05
@export var zoom_speed := 1.0

@export var min_zoom := -7.0
@export var max_zoom := 20.0

# Touch setting
@export var touch_zoom_speed := 0.1

# Touch controls
var _touches := {}
var _touch_changed_frame := -1 # Armazena o frame onde houve mudança no toque

# Camera controls
var rotating := false
var panning := false

# Default values
var default_position : Vector3
var default_rotation : Vector3
var default_zoom : float

# Stores the default (initial) values 
func _ready():
	default_position = global_position
	default_rotation = rotation
	default_zoom = camera.position.z



func _unhandled_input(event: InputEvent) -> void:
	# Mouse Controls (DESKTOP)
	if event is InputEventMouseButton:		
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed # Right mouse button rotates the camera
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed # Middle mouse button pans the camera

		# Wheel controls the zoom (by zoom_speed parameter)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom(zoom_speed)

	# If the mouse is moving adjust the rotation and pannig
	if event is InputEventMouseMotion:
		# If it is rotating, adjust the rotation of the Camera Pivot based on the rotate_speed and the relative mouse movement
		if rotating:
			rotation.y -= event.relative.x * rotate_speed
			rotation.x -= event.relative.y * rotate_speed
			rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(-10)) 

		# If it is panning, adjust the global_position of the Camera Pivot based on the pan_speed and the current rotation (on Y axis)
		if panning:
			var yaw = rotation.y
			var right = Vector3(cos(yaw), 0, -sin(yaw))
			var forward = Vector3(sin(yaw), 0, cos(yaw))
			global_position -= right * event.relative.x * pan_speed
			global_position -= forward * event.relative.y * pan_speed

	# Touch Controls (MOBILE)
	# If the event is a touch (press or release)
	if event is InputEventScreenTouch:
		# If the event is a new touch add the touch position to the touch ocntrols
		if event.pressed:
			_touches[event.index] = event.position
		else:
			# If the event is a touch release, remove the data of the touch controls
			_touches.erase(event.index)
		
		# Register the exact frame that the amoount of touches changed
		_touch_changed_frame = Engine.get_frames_drawn()

	# If the event is a touch move (drag)
	if event is InputEventScreenDrag:
		# Get the previous touch position before updating the touch controls
		var prev_pos = _touches.get(event.index, event.position - event.relative)
		_touches[event.index] = event.position
		
		# If this move (drag) is happening on the same frame that a touch ended, ignore the move (drag)
		# this should reset the touch deltas and stop teleporting the camera
		if Engine.get_frames_drawn() == _touch_changed_frame:
			return
		
		# Single touch: PAN - adjust the global_position of the Camera Pivot based on the pan_speed and the current rotation (on Y axis)
		if _touches.size() == 1:			
			var yaw = rotation.y
			var right = Vector3(cos(yaw), 0, -sin(yaw))
			var forward = Vector3(sin(yaw), 0, cos(yaw))
			
			global_position -= right * event.relative.x * pan_speed
			global_position -= forward * event.relative.y * pan_speed
			
		# Two touches: ZOOM - adjust the zoom based on the delta distancs of the two touches and the touch_zoom_speed
		elif _touches.size() == 2:
			var indices = _touches.keys()
			var other_index = indices[1] if event.index == indices[0] else indices[0]
			var other_pos = _touches.get(other_index, Vector2.ZERO)
			
			if other_pos != Vector2.ZERO:
				var current_dist = event.position.distance_to(other_pos)
				var prev_dist = prev_pos.distance_to(other_pos)
				var zoom_delta = prev_dist - current_dist
				
				zoom(zoom_delta * touch_zoom_speed)


	# Shortcut (R) to reset the camera on Desktop Mode
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			reset_view()

# Apply zoom
func zoom(amount):
	# Change the Z positionn of the camera inside the Camer Pivot to simulate zoom by a amount
	camera.position.z = clamp(camera.position.z + amount, min_zoom, max_zoom)

# Resets the camera config to the initial values
func reset_view():
	global_position = default_position
	rotation = default_rotation
	camera.position.z = default_zoom

# Animate the camera config to a position and zoom
func move_camera(target_position: Vector3, zoom_val: float) -> void: 
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_parallel()
	tween.tween_property(self, "global_position", target_position, 1.0)
	tween.tween_property(camera, "position:z", zoom_val, 1.0)
