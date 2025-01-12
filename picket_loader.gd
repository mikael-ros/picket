@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("Picket", "TileMapLayer", preload("picket.gd"), preload("res://Textures/Lamp.png"))


func _exit_tree():
	remove_custom_type("Picket")
