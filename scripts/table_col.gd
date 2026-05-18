extends VBoxContainer
class_name TableCol

# Possible columns: 

enum ColType {
	Down = 1,		# Down = Must be filled TOP to BOTTOM on any roll
	Up = 2,			# UP = Must be filled BOTTOM to UP on any roll
	Disorder = 3,	# DISORDER = Can be filled in any order on any roll
	Straight = 4	# Straight = Can be filled in any order on the first roll
}

# Array containing all the cells of this columns
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

# Array with the group cells of total from the upper part of the table
@onready var upper_total_cells: Array[Button] = [
	$VBoxContainer2/Total1,
	$VBoxContainer2/Bonus,
	$VBoxContainer2/Total2
]

# Array with the group cells of total from the lower part of the table
@onready var lower_total_cells: Array[Button] = [ $VBoxContainer4/Total3, $VBoxContainer4/Total4 ]

# Define the filling rule of this  column 
@export var col_type: ColType = ColType.Down

# Variables to hold the calculated totals
var upper_total: int = -1
var lower_total: int = -1
var total: int = -1

signal cell_clicked(col: TableCol, cell_id: int)


func _ready() -> void:
	# Connect the click event of each cell
	for id: int in cells.size():
		var cell: Button = cells[id]
		cell.connect("pressed", func(): _on_cell_pressed(id))

# Redirect the cell click event
func _on_cell_pressed(id: int) -> void:
	emit_signal("cell_clicked", self, id)

# Aggregate dice by face value
# Ex: [1,1,2,3,6] returns [2,1,1,0,0,1]
func _agg_dice(dice: Array) -> Array:
	return [1,2,3,4,5,6].map(func (n): return dice.filter(func (die): return die == n).size())

# Sum the dice values
func _sum_dice(dice: Array) -> int:
	return dice.reduce(func (a,b): return a + b)

# Calculate the result of a roll compared to a "number" cell 
# This is udes to check the upper part cells (1,2,3,4,5,6)
func _calculate_num(dice: Array, number: int) -> int:
	var amt: int = dice.filter(func (die): return die == number).size()
	return amt * number

# Calculate the result of a roll compared to a series of result
# This is used to check 4-of-a-kind (Q), full-hand (F) and Yams
func _calculate_equal(dice: Array, count: int, add: int) -> int:
	var values: Array = _agg_dice(dice)
	var index = values.find_custom(func (n): return n >= count) + 1
	if index > 0: return index * count + add
	return 0
	
# Calculate the result of a roll compared to a sequence: lower (S-) and upper (S+)
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
		
# Calculate the result of a roll compared to the MIN and MAX values of the col
# The MIN value should be smaller than the MAX value
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

# Return the first empty cell following the rule  of the column type
# For UP and DOWN column types
func _get_current_cell() -> int:
	var test: Callable = func (cell): return cell.text == ""
	if col_type == ColType.Down: return cells.find_custom(test)
	if col_type == ColType.Up: return cells.rfind_custom(test)
	return -1

# Return an Array with the possible values for each cell using the provided history:
# A value greater or equal than zero means the cell is a candidate
func _get_candidates(history: Array[Array]) -> Array[int]:
	# Return array
	var ret: Array[int] = []
	
	# Initiate the return array with zeros (to use on the easiest tests) 
	ret.resize(13)
	ret.fill(0)
	
	# If there is no roll on the history return an Array filled with zeros
	if history.size() == 0: return ret
	
	# If there is more than 1 roll on the history the value cannot be used on a STRAIGHT column type
	if history.size() > 1 and col_type == ColType.Straight: return ret
	
	# Helper function to tranform empty cells to value zero
	var set_or_zero = func(id, value): 
		if cells[id].text == "": return value
		return 0	
	
	# Get the last roll on the history
	var dice: Array = history[-1]
	
	# Empties the result to array to start testing
	ret.clear()
	
	# Test the dice result with the cells:
	
	# Upper cells: 1 to 6
	for num: int in range(6):
		var cell: Button = cells[num]
		var value: int = set_or_zero.call(num, _calculate_num(dice, num + 1))
		if cell.text != "": value = 0
		ret.append(value)	
	# 4-of-a-kind (Q)
	ret.append(set_or_zero.call(6, _calculate_equal(dice, 4, 20)))
	# full-hand (F)
	ret.append(set_or_zero.call(7, _calculate_seq(dice, true, [2,3], 30)))
	# Lower squence (S-)
	ret.append(set_or_zero.call(8, _calculate_seq(dice, false, [1,1,1,1,1,0], 35)))
	# Higher sequence (S+)
	ret.append(set_or_zero.call(9, _calculate_seq(dice, false, [0,1,1,1,1,1], 40)))
	# MIN and MAX
	var min_max: Array[int] = _calculate_min_max(dice)
	ret.append(set_or_zero.call(10, min_max[0]))
	ret.append(set_or_zero.call(11, min_max[1]))					
	# Yam
	ret.append(set_or_zero.call(12, _calculate_equal(dice, 5, 50)))
	
	# Test the current cell for UP and DOWN columns
	var current_cell: int = _get_current_cell()
	for id in ret.size():			
		if current_cell != -1 and current_cell != id:
			ret[id] = 0
	
	# Return the array
	return ret 

# Highlight cells that are candidate for the roll history provided
func highlight_candidates(history: Array[Array]) -> void:
	# Get an array with the candidate value of each cell
	var candidates: Array[int] = _get_candidates(history)
	
	for i: int in candidates.size():
		var cell: Button = cells[i]
		# Change the modulate of each cell that is a candidate (value is greater than zero) 
		if candidates[i] > 0:
			cell.modulate = Color.WHEAT
		else: 
			cell.modulate = Color.WHITE
	
# Reset the highlight changing the modulate back to WHITE on each cell
func clear_candidates() -> void:
	for cell: Button in cells:
		cell.modulate = Color.WHITE
	
# Try to set the calue of a cell based on a history provided
func set_value(id: int, history: Array[Array]) -> int:
	# If the cell aready has a value ignore the new value
	if (cells[id].text != ""): return -1
	# Get an array with the candidate value of each cell
	var candidates: Array[int] = _get_candidates(history)
	# Get the specific value for this cell
	var value: int = candidates[id]
	# Set the text value for the button on the cell with the caculated value
	var cell: Button = cells[id]
	cell.text = str(value)
	
	# Update the upper and lower total of the column
	calculate_upper_total()
	calculate_lower_total()
	
	# Return the value calculated
	return value

# Return an array with the upper part cells of the table
func _get_upper_cells() -> Array[Button]:
	var arr: Array[Button] = []
	for i in [0, 1, 2, 3, 4, 5]: 
		arr.append(cells[i])
	return arr
	
# Return an array with the upper part cells of the table
func _get_lower_cells() -> Array[Button]:
	var arr: Array[Button] = []
	for i in [6, 7, 8, 9, 10, 11, 12]: 
		arr.append(cells[i]) 
	return arr

# Check if the upper part of the table is all filled
func is_upper_finished() -> bool:
	return ! _get_upper_cells().any(func (cell): return cell.text == "")
# Check if the lower part of the table is all filled
func is_lower_finished() -> bool:
	return ! _get_lower_cells().any(func (cell): return cell.text == "")

# Get the total sum af an array of cells
func _sum_cells(_cells: Array[Button]) -> int:
	return _cells.reduce(func(acc, cell): 
		acc = acc + int(cell.text)
		return acc
	, 0)

# Calculate the sum of the upper cells
func calculate_upper_total() -> void:
	# Only calculate the upper total if the upper part is finished
	if !is_upper_finished(): return
	
	# The upper total has 3 values: 
	#  1. First Total = Sum of the Upper Cells
	#  2; Bonus = 30 (If First Total is equal or greater then 60)
	#  3: Upper Total = First Total + Bonus
		
	var bonus: int = 0
	var first: int = _sum_cells(_get_upper_cells())
	if first >= 60: bonus = 30
	upper_total = first + bonus
	
	# Update cells text
	upper_total_cells[0].text = str(first)
	upper_total_cells[1].text = str(bonus)
	upper_total_cells[2].text = str(upper_total)
	
# Calculate the sun of the lower cells
func calculate_lower_total() -> void: 
	# Only calculate the lower total if the lower part is finished 
	if !is_lower_finished(): return
	
	# The lower total has 2 values:
	#  1. Total = sum of the lower cells
	#  2; Lower Total = Total + Calculated Upper Total 
	
	lower_total = _sum_cells(_get_lower_cells())
	lower_total_cells[0].text = str(lower_total)
	
	# Only update the Lower Total if the upper part is finished 
	if is_upper_finished():
		total = upper_total + lower_total
		lower_total_cells[1].text = str(total)
