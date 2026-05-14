extends VBoxContainer
class_name TableCol

enum ColType {
	Down = 1,
	Up = 2,
	Disorder = 3,
	Straight = 4
}

@onready var cells: Array[Button] = [
	$"VBoxContainer/1",
	$"VBoxContainer/2",
	$"VBoxContainer/3",
	$"VBoxContainer/4",
	$"VBoxContainer/5",
	$"VBoxContainer/6",
	$VBoxContainer3/Q, 
	$VBoxContainer3/F, 
	$"VBoxContainer3/S-", 
	$"VBoxContainer3/S+", 
	$VBoxContainer3/MIN, 
	$VBoxContainer3/MAX, 
	$VBoxContainer3/YAM
]

@onready var cell_groups = [
	$VBoxContainer, $VBoxContainer3
]

@export var col_type: ColType 

signal cell_clicked(col: TableCol, cell_id: int)


func _ready() -> void:
	for id: int in cells.size():
		var cell: Button = cells[id]
		cell.connect("pressed", func(): _on_cell_pressed(id))

func _on_cell_pressed(id: int) -> void:
	emit_signal("cell_clicked", self, id)

func _agg_dice(dice: Array) -> Array:
	return [1,2,3,4,5,6].map(func (n): return dice.filter(func (die): return die == n).size())

func _sum_dice(dice: Array) -> int:
	return dice.reduce(func (a,b): return a + b)
	
func _calculate_num(dice: Array, number: int) -> int:
	var amt: int = dice.filter(func (die): return die == number).size()
	return amt * number

func _calculate_equal(dice: Array, count: int, add: int) -> int:
	var values: Array = _agg_dice(dice)
	var index = values.find_custom(func (n): return n >= count) + 1
	if index > 0: return index * count + add
	return 0
	
func _calculate_seq(dice: Array, filter: bool, seq: Array[int], add: int) -> int:
	var values: Array = _agg_dice(dice)
	var sum: int = _sum_dice(dice)
	if filter:
		values.sort()
		values = values.filter(func (n): return n > 0)
		
	if values == seq:
		return sum + add
	else:
		return 0

func _calculate_min_max(dice: Array) -> Array[int]: 
	var min_value: int = int(cells[10].text)
	var max_value: int = int(cells[11].text)
	var sum: int = _sum_dice(dice)
	
	if min_value == 0 and max_value == 0:
		return [sum, sum]
	elif min_value == 0 and sum < max_value:
		return [sum, 0] 
	elif max_value == 0 and sum > min_value:
		return [0, sum]
	else:
		return [0, 0]

func _get_current_cell() -> int:
	var test: Callable = func (cell): return cell.text == ""
	if col_type == ColType.Down: return cells.find_custom(test)
	if col_type == ColType.Up: return cells.size() - cells.find_custom(test) - 1
	return -1

func _get_candidates(history: Array[Array]) -> Array[int]:
	var ret: Array[int] = []
	ret.resize(13)
	ret.fill(0)
	
	if history.size() == 0: return ret
	if history.size() > 1 and col_type == ColType.Straight: return ret
	
	var dice: Array = history[-1]
	
	ret.clear()
	# 1..6
	for num: int in range(6):
		var cell: Button = cells[num]
		var value: int = _calculate_num(dice, num + 1)
		if cell.text != "": value = 0
		ret.append(value)
	# Q
	ret.append(_calculate_equal(dice, 4, 20))		
	# F
	ret.append(_calculate_seq(dice, true, [2,3], 30))		
	# S-
	ret.append(_calculate_seq(dice, false, [1,1,1,1,1,0], 35))
	# S+
	ret.append(_calculate_seq(dice, false, [0,1,1,1,1,1], 40))
	ret.append_array(_calculate_min_max(dice))		
	# Yam
	ret.append(_calculate_equal(dice, 5, 50))
	
	var current_cell: int = _get_current_cell()
	for item in ret.size():
		if current_cell != -1 and current_cell != item:
			ret[item] = 0
	
	return ret 
	
func highlight_candidates(history: Array[Array]) -> void:
	var candidates: Array[int] = _get_candidates(history)
	for i: int in candidates.size():
		var cell: Button = cells[i]
		if candidates[i] > 0:
			cell.modulate = Color.WHEAT
		else: 
			cell.modulate = Color.WHITE
	
func clear_candidates() -> void:
	for cell: Button in cells:
		cell.modulate = Color.WHITE
	
func set_value(id: int, history: Array[Array]) -> int:
	var candidates: Array[int] = _get_candidates(history)
	var value: int = candidates[id]
	var cell: Button = cells[id]	
	cell.text = str(value)
	return value
