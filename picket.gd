@tool
class_name Picket
extends EditorPlugin

# -----------------------------
# Properties used in the plugin
@export_group("Painting")					# How the fence is painted, from which we interpret the rendered fence
@export var mapping : TileMapLayer			## The tilemap upon which the fence is painted

@export_group("Textures")					# Textures used by the plugin
@export var fence_texture : Texture2D		## The texture for the fence itself
@export var fence_post_texture : Texture2D	## The texture for the posts placed intermittently

@export_group("Positioning")				# Exported variables related to position of the fence
@export_range(0,1, 0.1) var offset   = 0.0	## The offset
@export_subgroup("Anchor")					# Where in a tile the intersection of two fences will occur
@export_range(0,1, 0.1) var anchor_x = 0.5	## Anchor x position
@export_range(0,1, 0.1) var anchor_y = 0.5	## Anchor y position

# ---------------
# Interpreted properties
var grid_size : int 						## The size of the grid, interpreted from fence_texture
# -----------------------------

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
