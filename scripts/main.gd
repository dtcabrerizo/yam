extends Control
@onready var table: Table = %Table
@onready var board: Board = %Board
@onready var roll_button: Button = %RollButton
@onready var rolls: Array[TextureRect] = [
	%Roll1, %Roll2, %Roll3
]
@onready var foldable_container: FoldableContainer = $FoldableContainer


enum GameState {
	WAITING = 0,
	ROLLING = 1,
	SCORING = 3
}

var state: GameState = GameState.WAITING
var history: Array[Array] = []

func _ready() -> void:
	print("Ready")
	board.connect("roll_finished", _on_roll_finished)
	table.connect("cell_clicked", _on_table_cell_clicked)
	get_tree().root.size_changed.connect(_on_window_resized)
	
	var os: String = OS.get_name()
	if os == "Windows":
		foldable_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
		foldable_container.set_offsets_preset(Control.PRESET_TOP_LEFT)
		foldable_container.queue_sort()
	elif os == "Web":
		var browser_width = JavaScriptBridge.eval("window.innerWidth")
		if browser_width > 900:
			foldable_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
			foldable_container.set_offsets_preset(Control.PRESET_TOP_LEFT)
			foldable_container.queue_sort()
			
	
	
func _on_window_resized() -> void:
	pass
	#print("New Size: ", window_size, " <- ", $FoldableContainer.size)
	#print("scale_factor: ", get_window().get_screen_transform().get_scale(), " pizel_size ", get_global_rect().size * get_window().get_screen_transform().get_scale())
	
	#var real_width = $FoldableContainer.size.x * get_window().get_screen_transform().get_scale()
	#print("Real W: ", real_width)
	
	
	
func _on_table_cell_clicked(col: TableCol, cell_id: int) -> void:
	if state == GameState.ROLLING or history.size() == 0: return
	var ret: int = table.set_value(col, cell_id, history)
	if ret >= 0:
		_next_turn()
	
func _update_rolls() -> void:
	for i: int in range(3):
		rolls[i].visible = i < history.size()

func _update_visuals() -> void:
	_update_rolls()
	roll_button.visible = state == GameState.WAITING
	
func _on_roll_finished(dice: Array[int]) -> void:
	print("Roll finished: ", dice)
	history.append(dice)
	state = GameState.WAITING
	table.highlight_candidates(history)
	
	if history.size() == 3:
		state = GameState.SCORING

	_update_visuals()

func _on_roll_button_pressed() -> void:	
	if board.can_roll():
		state = GameState.ROLLING
		_update_visuals()
		board.roll_dice()
	
func _next_turn() -> void:
	state = GameState.WAITING
	history = []
	board.reset_dice()
	table.clear_candidates()
	_update_visuals()
