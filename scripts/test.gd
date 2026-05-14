extends Node3D



@onready var node_3d: Node3D = $Node3D


func _on_button_pressed() -> void:
	for dice in node_3d.get_children():
		dice.roll(10.0)
