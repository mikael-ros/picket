@tool
class_name Picket
extends TileMapLayer

# -----------------------------
# Properties used in the plugin
@export_group("Texture positions")			# Positions in the tilemap for the textures used by the plugin
@export var fence_texture : int 	 = 0	## Position for the texture for the fence itself. Assumed to be first
@export var fence_post_texture : int = 1	## Position for the texture for the posts placed intermittently

@export_group("Positioning")				# Exported variables related to position of the fence
@export_range(0,1, 0.1) var offset   = 0.0	## The offset
@export_subgroup("Anchor")					# Where in a tile the intersection of two fences will occur
@export_range(0,1, 0.1) var anchor_x = 0.5	## Anchor x position
@export_range(0,1, 0.1) var anchor_y = 0.5	## Anchor y position

# ---------------
# Private, local, properties
var fence_layer_horizontal : TileMapLayer 	## The tile map layer upon which the horizontal parts are displayed
var fence_layer_vertical : TileMapLayer 	## The tile map layer upon which the horizontal parts are displayed
											# note: a post layer is not needed, as that's the "self" layer.

# -----------------------------

func _enter_tree() -> void:
	# Initialize fence
	fence_layer_horizontal = TileMapLayer.new()
	fence_layer_vertical = TileMapLayer.new()
	
	# Copy certain properties over
	fence_layer_horizontal.tile_set = tile_set
	fence_layer_vertical.tile_set = tile_set
	# todo: copy more properties over? maybe write a for-each? not sure. 
	
	# Set offset for fence layer
	# This is simply the position + half a tile in the relevant direction
	fence_layer_horizontal.position.x = position.x + tile_set.tile_size.x / 2
	fence_layer_vertical.position.y = position.y + tile_set.tile_size.y / 2

func _exit_tree() -> void:
	# todo: figure out what needs to be cleaned up
	pass

## Paints the fence upon the fence layer
func draw_fence() -> void:
	# read positions where anything is painted in tilemap
	# node traversal is left to right
	# for each tile painted:
	# 	read adjacencies 
	# 	for each adjacency:
	#		read relative axis
	#		paint in relative axis, if not painted
	pass
