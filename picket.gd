@tool
class_name Picket
extends TileMapLayer

# -----------------------------
# Properties used in the plugin
@export_group("Texture positions")			# Positions in the tilemap for the textures used by the plugin
@export var fence_texture_ID : int 	 = 0	## Position for the texture for the fence itself. Assumed to be first
@export var fence_post_texture_ID : int = 1	## Position for the texture for the posts placed intermittently

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
var painted_cells : Array[Vector2i] 
var added_cells : Array[Vector2i] 
var removed_cells : Array[Vector2i] 
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
	
	# Add children, draw initial fence
	add_child(fence_layer_horizontal)
	add_child(fence_layer_vertical)
	
	update_tiles()

func _exit_tree() -> void:
	fence_layer_horizontal.free()
	fence_layer_vertical.free()
	
func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(delta) -> void:
	update_tiles()
	
## Update all tiles, based on differences
func update_tiles() -> void:
	var prev_painted_cells = painted_cells
	painted_cells = get_used_cells() 
			
	for cell in prev_painted_cells:
		if (not cell in painted_cells):
			remove_fence_neighbors(cell)
			
	for cell in painted_cells:
		if (not cell in prev_painted_cells):
			draw_fence_neighbors(cell)
	
## Paint neighbors of a certain cell. More performant than [method draw_fence]
func draw_fence_neighbors(cell: Vector2i) -> void:
	for neighbor in get_surrounding_cells(cell): 	# For every neighbor cell
		if painted_cells.has(neighbor):	 			# If neighbor is painted (get_surrounding_cells includes every cell, so)
			set_fence_cell(cell, neighbor)

## Paint connections between cells
func set_fence_cell(cell: Vector2i, neighbor: Vector2i) -> void:
	var pos = cell
	if neighbor.x == cell.x: 	# If neighbor is on vertical axis
		if neighbor.y < cell.y: # If neighbor is below
			pos.y -= 1
		fence_layer_vertical.set_cell(pos, fence_texture_ID, Vector2i.ZERO, TileSetAtlasSource.TRANSFORM_TRANSPOSE + TileSetAtlasSource.TRANSFORM_FLIP_V)
	elif neighbor.y == cell.y:	# If neighbor is on horizontal axis
		if neighbor.x < cell.x: # If neighbor is to the left
			pos.x -= 1
		fence_layer_horizontal.set_cell(pos, fence_texture_ID, Vector2i.ZERO)

## Remove neighbors of a certain cell.
func remove_fence_neighbors(cell: Vector2i) -> void:
	for neighbor in get_surrounding_cells(cell): # Remove cells in every direction
		fence_layer_horizontal.erase_cell(cell)							# Cell to the right
		fence_layer_horizontal.erase_cell(Vector2(cell.x - 1, cell.y))	# Cell to the left
		fence_layer_vertical.erase_cell(cell)							# Cell above
		fence_layer_vertical.erase_cell(Vector2(cell.x, cell.y - 1))	# Cell below
