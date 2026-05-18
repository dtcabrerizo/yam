extends PanelContainer
class_name Table

@onready var cols: Array[TableCol] = [
	%TableCol, 
	%TableCol2, 
	%TableCol3, 
	%TableCol4
]
@onready var total_cell: Button = %TotalGeral
@onready var sound_write: AudioStreamPlayer2D = $SoundWrite

# The table total, suming all columns
var total: int = -1

signal cell_clicked(col: TableCol, cell_id: int)

func _ready() -> void:
	# Connect the cell clicked event
	for col: TableCol in cols:
		col.connect("cell_clicked", _on_cell_clicked)

# Redirect the cell clicekd event from a column, emiting a new signal
func _on_cell_clicked(col: TableCol, cell_id: int) -> void:
	emit_signal("cell_clicked", col, cell_id)

# Highlight candidates on all columns, based on the roll history provided
func highlight_candidates(history: Array[Array]) -> void:
	for col: TableCol in cols:
		col.highlight_candidates(history)

# Clear highlighted candidates on all columns
func clear_candidates() -> void:
	for col: TableCol in cols:
		col.clear_candidates()

# Caluclate the table total
func _calculate_total() -> void:
	# Sum the total of each column only if all columns have a total (is totally filled)
	var calc_total: int = 0
	for col: TableCol in cols:
		if col.total >= 0:
			calc_total += col.total
		else:
			return	
	
	# Update the variable and visual
	total = calc_total
	total_cell.text = str(total)	

# Try to set a cell value from a column	
func set_value(col: TableCol, cell_id: int, history: Array[Array]) -> int:
	# Try to set the value of a cell using the roll history provided
	var value = col.set_value(cell_id, history)
	# If the value was set
	if value >= 0:
		# Play the writing sound with a small random pitch 
		sound_write.pitch_scale = randf_range(0.9, 1.1)
		sound_write.play()
		# Recalculate the current total
		_calculate_total()
	
	# Return the value defined
	return value
