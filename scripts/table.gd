extends PanelContainer
class_name Table

@onready var cols: Array[TableCol] = [
	%TableCol, 
	%TableCol2, 
	%TableCol3, 
	%TableCol4
]

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


func set_value(col: TableCol, cell_id: int, history: Array[Array]) -> int:
	return col.set_value(cell_id, history)
