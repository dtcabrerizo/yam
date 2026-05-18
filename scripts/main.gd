extends Control

@onready var table: Table = %Table
@onready var board: Board = %Board
@onready var roll_button: Button = %RollButton
@onready var rolls: Array[TextureRect] = [
	%Roll1, %Roll2, %Roll3
]
@onready var foldable_container: FoldableContainer = $FoldableContainer
@onready var roll_button_container: MarginContainer = $MarginContainer2
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport

# Available game states
enum GameState {
	WAITING = 0,	# Awaiting first roll
	ROLLING = 1,	# Rolling dice
	SCORING = 3		# Awaitng user fill table
}

# Current Game State
var state: GameState = GameState.WAITING
# Roll history
var history: Array[Array] = []

func _ready() -> void:
	# Connect events of the two main components
	board.connect("roll_finished", _on_roll_finished)
	table.connect("cell_clicked", _on_table_cell_clicked)
	
	# Adjust the visual when the window changes size 
	get_tree().root.size_changed.connect(_on_window_resized)
	# Iitiate window scale
	_on_window_resized()

# Handles window changin sizes to adjust the scale of the table
func _on_window_resized() -> void:
	# Get current window size
	var window_size: Vector2i = DisplayServer.window_get_size()
	# The original width is 334 so this is used as base
	var ui_base_width: float = 334.0
	
	# --- MOBILE MODE / PORTRAIT ---
	if window_size.y > window_size.x: 
		# Calculates the scale based on the screen width
		var dynamic_scale: float = window_size.x / ui_base_width
		
		# Limits the scale between 1.0 and 2.5 to avoid extreme distortions
		get_window().content_scale_factor = clamp(dynamic_scale, 1.0, 2.5)
		
		# Sets the container presets to fill the entire screen
		foldable_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		foldable_container.set_offsets_preset(Control.PRESET_FULL_RECT)
		# Resets container size
		foldable_container.custom_minimum_size = Vector2.ZERO
		
		# Makes the table fill the entire container
		table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Adjusts the camera with a lower angle so it's possible to see the table and reserve
		board.camera.move_camera(Vector3(6.0, 9.0, -0.4), 18.0)
		
	else:
		# --- DESKTOP MODE / LANDSCAPE ---
		# Keep the native 1.0 scale because the window should be large enough
		get_window().content_scale_factor = 1.0
		
		# Sets the container presets to align to the left of the screen
		foldable_container.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		foldable_container.set_offsets_preset(Control.PRESET_LEFT_WIDE)
		foldable_container.custom_minimum_size = Vector2(326, 504)
		# Resets container size
		foldable_container.size.x = ui_base_width
		
		# Makes the table to occupy the minimum size
		table.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		table.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		board.camera.reset_view()

	# Keep the 3D Viewport in the device native resolution (avoids blur)
	sub_viewport.size = window_size
	
# Handles a click on a table cell 
func _on_table_cell_clicked(col: TableCol, cell_id: int) -> void:
	# If the state is a valid state to assign a value to the table
	# The roll must be finished and at least one roll on the history 
	if state == GameState.ROLLING or history.size() == 0: return
	# Try to set the value of the cell using the current history of rolls
	var ret: int = table.set_value(col, cell_id, history)
	# if the value were set start next turn
	if ret >= 0:
		_next_turn()

# Updates the visibility of the rolls markers with the amount of rolls in this turn
func _update_rolls() -> void:
	for i: int in range(3):
		rolls[i].visible = i < history.size()

# Updates the components visuals
func _update_visuals() -> void:
	# Updates the roll count
	_update_rolls()
	# Display or hide the button to roll the dice
	roll_button.visible = state == GameState.WAITING
	
# Handles the results of the current roll
func _on_roll_finished(dice: Array[int]) -> void:
	print("Roll finished: ", dice)
	# Add the result to the current turn history
	history.append(dice)
	# Update the game state to the next state
	state = GameState.WAITING
	# Highlights candidate cells of the table with this result
	table.highlight_candidates(history)
	
	# If this turn has already 3 rolls change the state to the scoring state and block new rolls
	if history.size() == 3:
		state = GameState.SCORING

	# Update component visuals
	_update_visuals()

# Handles the roll button click
func _on_roll_button_pressed() -> void:	
	# if the board os ready to roll the dice
	if board.can_roll():
		# Update the game state
		state = GameState.ROLLING
		# Update the components visuals
		_update_visuals()
		# Roll the dice
		board.roll_dice()

# Start nest turn
func _next_turn() -> void:
	# Update control variables to the initial position
	state = GameState.WAITING
	history = []
	# Put every dice on the table
	board.reset_dice()
	# Resets the highlighted candidates on the table
	table.clear_candidates()
	# Update components visuals
	_update_visuals()
