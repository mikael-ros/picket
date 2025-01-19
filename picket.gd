@tool
class_name Picket
extends TileMapLayer
## A simple fence plugin for Godot Engine 4.x. Makes the building of fences easy, and dynamic.
## @tutorial: https://github.com/mikael-ros/picket/readme.md 
# -----------------------------
# Properties used in the plugin

# Positions in the tilemap for the textures used by the plugin
@export_group("Texture positions")
## Position for the texture for the fence itself. Assumed to be first
@export 
var fence_texture_ID : int = 0:
	set(new_fence_texture_ID): 
		fence_texture_ID = new_fence_texture_ID
		redraw()
## Position for the texture for the posts placed intermittently
@export 
var fence_post_texture_ID : int = 1:
	set(new_fence_post_texture_ID): 
		fence_post_texture_ID = new_fence_post_texture_ID
		redraw()

# Exported variables related to position of the fence
@export_group("Positioning")
## The offset
@export_range(0,1, 0.01) 
var offset = 0.0:
	set(new_offset): 
		offset = new_offset
		set_properties(true)
## Custom x origin position
@export 
var origin_x : float = 0.0:
	set(new_x): 
		origin_x = new_x
		set_properties()
## Custom y origin position
@export 
var origin_y : float = 0.0:
	set(new_y): 
		origin_y = new_y
		set_properties()

## Modes for directional fence interpretation
enum DIRECTION_INTERPRETATION_MODE {
	NONE,		## Do not interpret any direction rotation
	EXPLICIT,	## User explicitly chooses by rotating in the tile editor
	#PREDICTIVE,## Predict directions based on position compared to previously painted cell (not implemented)
	#IMPLICIT, 	## Calculate directions based on ray-casting or similar (not implemented)
}

## How directional fences are interpreted
@export_enum("None", "Explicit")
var direction_interpretation_mode : int = 0:
	set(new_mode): 
		direction_interpretation_mode = new_mode
		redraw()
		
# Where in a tile the intersection of two fences will occur
@export_subgroup("Anchor")
## Anchor x coordinate
@export_range(0, 1, 0.01) 
var anchor_x : float = 0.5: 
	set(new_x): 
		anchor_x = new_x
		set_properties()
## Anchor y coordinate
@export_range(0, 1, 0.01) 
var anchor_y : float = 0.5:
	set(new_y): 
		anchor_y = new_y
		set_properties()

# ---------------
# Local properties
var fence_layer_horizontal : TileMapLayer 	## Layer upon which the horizontal parts of fence are displayed
var fence_layer_vertical : TileMapLayer 	## Layer upon which the vertical parts of fence are displayed

var post_layer_horizontal : TileMapLayer 	## Layer upon which horizontal posts are displayed
var post_layer_vertical : TileMapLayer		## Layer upon which vertical posts are displayed
var post_layer_stationary : TileMapLayer	## Layer upon which stationary posts are displayed

var painted_cells : Array[Vector2i] 		## Used for tracking what cells have been painted, dissimilar from [method get_used_cells]
var initialized = false ## Has [Picket] been initialized?

## Axis' for fence post usage
enum Axis {
	HORIZONTAL, 	## Post has a neighbor to the left, and one to the right
	VERTICAL, 		## Post has neighbors below and above
	BOTH_OR_NEITHER ## Post has more than two neighbors, or none at all
}
	

# -----------------------------

## Called when [Picket] enters tree
func _enter_tree() -> void:
	# Initialize fence
	fence_layer_horizontal = TileMapLayer.new()
	fence_layer_vertical = TileMapLayer.new()
	post_layer_horizontal = TileMapLayer.new()
	post_layer_vertical = TileMapLayer.new()
	post_layer_stationary = TileMapLayer.new()
	initialized = true
	
	# Add children, draw initial fence
	add_child(fence_layer_horizontal)
	add_child(fence_layer_vertical)
	add_child(post_layer_horizontal)
	add_child(post_layer_vertical)
	add_child(post_layer_stationary)
	
	set_properties(true)

## Called when [Picket] exits tree
func _exit_tree() -> void:
	# Free all layers
	fence_layer_horizontal.free()
	fence_layer_vertical.free()
	post_layer_horizontal.free()
	post_layer_vertical.free()
	post_layer_stationary.free()

## Called when [Picket] enters scene
func _ready() -> void:
	set_process(Engine.is_editor_hint()) # Only use [method _process] in the editor
	if (Engine.is_editor_hint()):
		changed.connect(set_properties)  # Only connect [method set_properties] if in the editor

## Called every tick, in the editor only
func _process(delta) -> void:
	update_tiles() # Update tiles every tick. Not effecient, but cant find a better solution yet

## Propagate properties over to children
func set_properties(redraw: bool = false) -> void:
	# Only execute the following when [Picket] has not been initialized
	if initialized: 
		# Copy certain properties over
		if redraw:
			fence_layer_horizontal.tile_set = tile_set
			fence_layer_vertical.tile_set = tile_set
			post_layer_horizontal.tile_set = tile_set
			post_layer_vertical.tile_set = tile_set
			post_layer_stationary.tile_set = tile_set
			redraw()
		# todo: copy more properties over? maybe write a for-each? not sure. 
		
		# Adjust by anchor
		position = Vector2(origin_x, origin_y) + Vector2((anchor_x + 0.5) * tile_set.tile_size.x, (anchor_y + 0.5) * tile_set.tile_size.y)
		
		# Set offset for fence layer
		# This is simply the position + half a tile in the relevant direction
		fence_layer_horizontal.position.x = tile_set.tile_size.x / 2
		fence_layer_vertical.position.y = tile_set.tile_size.y / 2
		
		# Set offset for post layer
		post_layer_horizontal.position.x = offset * tile_set.tile_size.x
		post_layer_vertical.position.y = offset * tile_set.tile_size.y
		
		self.self_modulate.a = 0.0
	
## Redraws all tiles. Used for texture changes
func redraw() -> void:
	painted_cells = []
	update_tiles()
	
## Update all tiles, based on differences
func update_tiles() -> void:
	var prev_painted_cells = painted_cells
	painted_cells = get_used_cells() 
			
	# Find and clear removed fences
	for cell in prev_painted_cells:
		if not cell in painted_cells:
			clear_fence_neighbors(cell)
			clear_post_cell(cell, true)
			
	# Find and draw new fences
	for cell in painted_cells:
		if not cell in prev_painted_cells:
			draw_fence_neighbors(cell)
			draw_post_neighbors(cell, true)

## Is this cell painted (as far as the array [member painted_cells] is aware)?
func is_painted(cell: Vector2i) -> bool:
	return painted_cells.has(cell)

## Retrieve all neighbors that are drawn, as [method get_surrounding_cells] retrieves all possible neighbors, not only existing ones
func get_drawn_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return get_surrounding_cells(cell).filter(is_painted)

## Retrieve all direct neighbors, in addition to diagonal ones
func get_all_drawn_neighbors(cell: Vector2i) -> Array[Vector2i]:
	# Start with diagonal neighbors
	var all_neighbors : Array[Vector2i] = 	[cell + Vector2i.LEFT + Vector2i.DOWN, 
											 cell + Vector2i.LEFT + Vector2i.UP, 
											 cell + Vector2i.RIGHT + Vector2i.DOWN, 
											 cell + Vector2i.RIGHT + Vector2i.UP] 
	all_neighbors.append_array(get_surrounding_cells(cell)) # Add direct neighbors
	return all_neighbors.filter(is_painted) # Filter

## Counts the amount of drawn neighbors in either direction
func count_neighbors(cell: Vector2i) -> Vector2i:
	var axis_neighbors = Vector2i.ZERO			# Neighbors on corresponding axis
	for neighbor in get_drawn_neighbors(cell): 	# For every neighbor cell
		if (neighbor.x == cell.x):				# If neighbor is on y-axis (vertical neighbor)
			axis_neighbors.y += 1				# Increase y-axis neighbor count
		else:									# Same, for x-axis (horizontal neighbor)
			axis_neighbors.x += 1
	return axis_neighbors

## Determines if cell is in a chain of strictly vertical or horizontal cells, or indeterminate
func determine_axis(cell: Vector2i) -> Axis:
	match count_neighbors(cell):
		Vector2i(2,0): # If there are neighbors to the left of, and to the right of
			return Axis.HORIZONTAL
		Vector2i(0,2): # If there are neigbors above and below
			return Axis.VERTICAL
		_:			   # Otherwise, treat the same as static post
			return Axis.BOTH_OR_NEITHER

## Get cell to the left of cell			
func left_of(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.LEFT
	
## Get cell to the right of cell	
func right_of(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.RIGHT
	
## Get cell above cell		
func above(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.UP
	
## Get cell below cell		
func below(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.DOWN

## Paints fence posts around and within a certain cell
func draw_post_neighbors(cell: Vector2i, should_update_neigbors: bool = false) -> void:
	match determine_axis(cell):
		Axis.HORIZONTAL:
			if offset > 0:
				post_layer_horizontal.set_cell(left_of(cell), fence_post_texture_ID, Vector2i.ZERO)
			post_layer_horizontal.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
		Axis.VERTICAL:
			if offset > 0:
				post_layer_vertical.set_cell(above(cell), fence_post_texture_ID, Vector2i.ZERO)
			post_layer_vertical.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
		Axis.BOTH_OR_NEITHER:
			post_layer_stationary.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
	if should_update_neigbors: # If this cell is newly painted, trigger update for neighbors
		update_post_neighbors(cell)

## Remove fence posts in a certain cell
func clear_post_cell(cell: Vector2i, should_update_neigbors: bool = false) -> void:
	if post_layer_stationary.get_used_cells().has(cell):
		post_layer_stationary.erase_cell(cell)
	else:
		var right = right_of(cell)
		var below = below(cell)
		# If post on the right doesn't exist, or if there is no conflict
		if not is_painted(right) or determine_axis(right) != Axis.HORIZONTAL: 
			post_layer_horizontal.erase_cell(cell) # Erase horizontal part
		# Same, for below
		if not is_painted(below) or determine_axis(below) != Axis.VERTICAL: 
			post_layer_vertical.erase_cell(cell)
		# Erase any offset copies	
		if offset > 0:
			var left = left_of(cell)
			var above = above(cell)
			# Same logic as for the previous erasures
			if not is_painted(left) or determine_axis(left) != Axis.HORIZONTAL:
				post_layer_horizontal.erase_cell(left)
			if not is_painted(above) or determine_axis(above) != Axis.VERTICAL:
				post_layer_vertical.erase_cell(above)
	if should_update_neigbors: # If this cell is newly cleared, trigger update for neighbors
		update_post_neighbors(cell)

## Update neighbors surrounding a post, in case posts can no longer be movable				
func update_post_neighbors(cell: Vector2i) -> void:
	for neighbor in get_all_drawn_neighbors(cell): 	# For every neighbor (including diagonals)
		clear_post_cell(neighbor)					# Clear current drawn posts
		draw_post_neighbors(neighbor)				# Redraw posts again

## Taken from Godot docs example
enum TileTransform {
	ROTATE_0 = 0,
	ROTATE_90 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,
	ROTATE_180 = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	ROTATE_270 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,
}

## Paint neighbors of a certain cell
func draw_fence_neighbors(cell: Vector2i) -> void:
	var alternate_tile = get_cell_alternative_tile(cell)
	for neighbor in get_drawn_neighbors(cell): 	# For every neighbor cell
		var pos = cell
		if neighbor.x == cell.x: 	# If neighbor is on vertical axis
			if neighbor.y < cell.y: # If neighbor is below
				pos = above(cell)
				
			var rotation = TileTransform.ROTATE_270
			if direction_interpretation_mode == DIRECTION_INTERPRETATION_MODE.EXPLICIT:
				match alternate_tile:
					TileTransform.ROTATE_90:
						rotation = TileTransform.ROTATE_0
					TileTransform.ROTATE_180:
						rotation = TileTransform.ROTATE_90
					TileTransform.ROTATE_270:
						rotation = TileTransform.ROTATE_180
			fence_layer_vertical.set_cell(pos, fence_texture_ID, Vector2i.ZERO, rotation)
		elif neighbor.y == cell.y:	# If neighbor is on horizontal axis
			if neighbor.x < cell.x: # If neighbor is to the left
				pos = left_of(cell)
			
			var rotation = 0
			if direction_interpretation_mode == DIRECTION_INTERPRETATION_MODE.EXPLICIT:
				rotation = alternate_tile
			fence_layer_horizontal.set_cell(pos, fence_texture_ID, Vector2i.ZERO, rotation)

## Remove neighbors of a certain cell.
func clear_fence_neighbors(cell: Vector2i) -> void:
	fence_layer_horizontal.erase_cell(cell)				# Cell to the right
	fence_layer_horizontal.erase_cell(left_of(cell))	# Cell to the left
	fence_layer_vertical.erase_cell(cell)				# Cell above
	fence_layer_vertical.erase_cell(above(cell))		# Cell below
	
