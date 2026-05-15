extends PanelContainer
class_name Table

@onready var cols: Array[TableCol] = [
	%TableCol, 
	%TableCol2, 
	%TableCol3, 
	%TableCol4
]
@onready var total_geral: Button = %TotalGeral
@onready var sound_write: AudioStreamPlayer2D = $SoundWrite

var total: int = -1

signal cell_clicked(col: TableCol, cell_id: int)

func _ready() -> void:
	for col: TableCol in cols:
		col.connect("cell_clicked", _on_cell_clicked)
		
func _on_cell_clicked(col: TableCol, cell_id: int) -> void:
	emit_signal("cell_clicked", col, cell_id)

func highlight_candidates(history: Array[Array]) -> void:
	for col: TableCol in cols:
		col.highlight_candidates(history)

func clear_candidates() -> void:
	for col: TableCol in cols:
		col.clear_candidates()

func _calculate_total() -> void:
	var calc_total: int = 0
	for col: TableCol in cols:
		if col.total >= 0:
			calc_total += col.total
		else:
			return	
	
	total = calc_total
	total_geral.text = str(total)	
	
func set_value(col: TableCol, cell_id: int, history: Array[Array]) -> int:
	var value = col.set_value(cell_id, history)
	if value >= 0:
		sound_write.pitch_scale = randf_range(0.9, 1.1)
		sound_write.play()
		_calculate_total()
	return value
