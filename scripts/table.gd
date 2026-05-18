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
		
	# Dentro de res://scripts/table.gd
	## 1. Faz as colunas do cabeçalho (MPB, S, D, setas...) expandirem igualmente em largura
	#for botao in $MarginContainer/VBoxContainer/HBoxContainer3.get_children():
		#if botao is Button:
			#botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
#
	## 2. Faz as colunas de dados (TableFixed e as TableCols) expandirem igualmente em largura
	#for coluna in $MarginContainer/VBoxContainer/HBoxContainer.get_children():
		#coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		## Se as suas sub-cenas TableCol tiverem VBoxContainers internos, 
		## você pode garantir a expansão vertical deles aqui também se necessário.
#
	## 3. DESTREVAR O RODAPÉ (O painel "TOTAL GERAL")
	## Atualmente ele está travado em 252px no seu .tscn, o que quebra o layout em telas largas.
	#var painel_total = $MarginContainer/VBoxContainer/HBoxContainer2/Panel
	#painel_total.custom_minimum_size.x = 0 # Remove a trava de 252px
	#painel_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Faz ele ocupar o resto da largura
		
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
