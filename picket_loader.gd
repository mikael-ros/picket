@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Picket", "TileMapLayer", preload("picket.gd"), preload("assets/picket_square_logo.svg"))


func _exit_tree():
	remove_custom_type("Picket")
