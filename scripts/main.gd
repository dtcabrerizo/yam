extends Control
@onready var table: Table = %Table
@onready var board: Board = %Board
@onready var roll_button: Button = %RollButton
@onready var rolls: Array[Sprite2D] = [
	$MarginContainer2/Roll1,
	$MarginContainer2/Roll2,
	$MarginContainer2/Roll3
]


enum GameState {
	WAITING = 0,
	ROLLING = 1,
	SCORING = 3
}

var state: GameState = GameState.WAITING
var history: Array[Array] = []

func _ready() -> void:
	board.connect("roll_finished", _on_roll_finished)
	table.connect("cell_clicked", _on_table_cell_clicked)
	
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
