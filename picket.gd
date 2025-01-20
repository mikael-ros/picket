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
		_redraw()
## Position for the texture for the posts placed intermittently
@export 
var fence_post_texture_ID : int = 1:
	set(new_fence_post_texture_ID): 
		fence_post_texture_ID = new_fence_post_texture_ID
		_redraw()

# Exported variables related to position of the fence
@export_group("Positioning")
## The offset
@export_range(0,1, 0.01) 
var offset = 0.0:
	set(new_offset): 
		offset = new_offset
		_set_properties(true)
## Custom x origin position
@export 
var origin_x : float = 0.0:
	set(new_x): 
		origin_x = new_x
		_set_properties()
## Custom y origin position
@export 
var origin_y : float = 0.0:
	set(new_y): 
		origin_y = new_y
		_set_properties()

## Modes for directional fence interpretation
enum DIRECTION_INTERPRETATION_MODE {
	NONE,		## Do not interpret any direction rotation
	EXPLICIT,	## User explicitly chooses by rotating in the tile editor
	#PREDICTIVE,## Predict directions based on position compared to previously painted cell (not implemented)
	#IMPLICIT, 	## Calculate directions based on ray-casting or similar (not implemented)
}

@export_subgroup("Direction interpretation")
## How directional fences are interpreted
@export_enum("None", "Explicit")
var direction_interpretation_mode : int = 0:
	set(new_mode): 
		direction_interpretation_mode = new_mode
		_redraw()

## Whether directions that look funky (90 degrees, 270 degrees) should be enabled		
@export
var enable_unsupported_directions : bool = false:
	set(new_bool): 
		enable_unsupported_directions = new_bool
		_redraw()
		
# Where in a tile the intersection of two fences will occur
@export_subgroup("Anchor")
## Anchor x coordinate
@export_range(0, 1, 0.01) 
var anchor_x : float = 0.5: 
	set(new_x): 
		anchor_x = new_x
		_set_properties()
## Anchor y coordinate
@export_range(0, 1, 0.01) 
var anchor_y : float = 0.5:
	set(new_y): 
		anchor_y = new_y
		_set_properties()

# ---------------
# Local properties
var _fence_layer_horizontal : TileMapLayer 	## Layer upon which the horizontal parts of fence are displayed
var _fence_layer_vertical : TileMapLayer 	## Layer upon which the vertical parts of fence are displayed

var _post_layer_horizontal : TileMapLayer 	## Layer upon which horizontal posts are displayed
var _post_layer_vertical : TileMapLayer		## Layer upon which vertical posts are displayed
var _post_layer_stationary : TileMapLayer	## Layer upon which stationary posts are displayed

var _preview_layer : TileMapLayer	 		## Layer upon which tile edits are previewed to the user

var _painted_cells : Array[Vector2i] 		## Used for tracking what cells have been painted, dissimilar from [method get_used_cells]
var _initialized = false 					## Has [Picket] been initialized?

var _mouse_pos : Vector2i = -Vector2i.ONE 	## Used for tracking previous mouse position in the editor

## Axis' for fence post usage
enum Axis {
	HORIZONTAL, 	## Post has a neighbor to the left, and one to the right
	VERTICAL, 		## Post has neighbors below and above
	BOTH_OR_NEITHER ## Post has more than two neighbors, or none at all
}
	
## Taken from Godot docs example
enum TileTransform {
	ROTATE_0 = 0,																				## Represents 0 (or n * 360) degree rotation
	ROTATE_90 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,	## Represents 90 degree rotation
	ROTATE_180 = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,		## Represents 180 degree rotation
	ROTATE_270 = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,	## Represents 270 degree rotation
}

# -----------------------------

## Called when [Picket] enters tree
func _enter_tree() -> void:
	# Initialize fence
	_fence_layer_horizontal = TileMapLayer.new()
	_fence_layer_vertical = TileMapLayer.new()
	_post_layer_horizontal = TileMapLayer.new()
	_post_layer_vertical = TileMapLayer.new()
	_post_layer_stationary = TileMapLayer.new()
	
	if Engine.is_editor_hint():
		_preview_layer = TileMapLayer.new()
	_initialized = true
	
	# Add children, draw initial fence
	add_child(_fence_layer_horizontal)
	add_child(_fence_layer_vertical)
	add_child(_post_layer_horizontal)
	add_child(_post_layer_vertical)
	add_child(_post_layer_stationary)
	
	if _preview_layer:
		add_child(_preview_layer)
	
	_set_properties(true)

## Called when [Picket] exits tree
func _exit_tree() -> void:
	# Free all layers
	_fence_layer_horizontal.free()
	_fence_layer_vertical.free()
	_post_layer_horizontal.free()
	_post_layer_vertical.free()
	_post_layer_stationary.free()
	
	if _preview_layer:
		_preview_layer.free()

var _editor_interface # for caching EditorInterface
## Called when [Picket] enters scene
func _ready() -> void:
	set_process(Engine.is_editor_hint()) # Only use [method _process] in the editor
	if Engine.is_editor_hint():
		changed.connect(_set_properties)  # Only connect [method set_properties] if in the editor
		var plugin = EditorPlugin.new()
		_editor_interface = plugin.get_editor_interface() # Save editor interface
		plugin.queue_free()

## Called every tick, in the editor only
func _process(delta) -> void:
	if _initialized:
		_preview_cell()
		_update_tiles() # Update tiles every tick. Not effecient, but cant find a better solution yet

## Preview the currently hovered cell
func _preview_cell() -> void:
	# This is currently a simple fence post preview.
	# Ideally I wanted to display rotation, and preview what the fence will look like with the post added
	# While the second is possible (though computationally intensive), the first does not seem possible,
	# as the Godot editor - to my knowledge - does not yet expose rotation settings in the Tile Map editor
	if self in _editor_interface.get_selection().get_selected_nodes(): 			# If Picket is selected
		var prev_mouse_pos : Vector2i = _mouse_pos								# Save previous cursor location
		_mouse_pos = local_to_map(get_global_mouse_position()) - Vector2i.ONE 	# Get current cursor location, in TileMapLayer terms
		if prev_mouse_pos != _mouse_pos: 									  	# If position has changed	
			_preview_layer.erase_cell(prev_mouse_pos)							# Erase previous preview
			if not _is_painted(_mouse_pos): 									# If the current position is not already painted (preview useless)
				_preview_layer.set_cell(_mouse_pos, 1, Vector2i.ZERO, 0)		# Paint a preview

## Propagate properties over to children
func _set_properties(redraw: bool = false) -> void:
	# Only execute the following when [Picket] has not been initialized
	if _initialized: 
		# Copy certain properties over
		if redraw:
			_fence_layer_horizontal.tile_set = tile_set
			_fence_layer_vertical.tile_set = tile_set
			_post_layer_horizontal.tile_set = tile_set
			_post_layer_vertical.tile_set = tile_set
			_post_layer_stationary.tile_set = tile_set
			if _preview_layer:
				_preview_layer.tile_set = tile_set
			_redraw()
		# todo: copy more properties over? maybe write a for-each? not sure. 
		
		# Adjust by anchor
		position = Vector2(origin_x, origin_y) + Vector2((anchor_x + 0.5) * tile_set.tile_size.x, (anchor_y + 0.5) * tile_set.tile_size.y)
		
		# Set offset for fence layer
		# This is simply the position + half a tile in the relevant direction
		_fence_layer_horizontal.position.x = tile_set.tile_size.x / 2
		_fence_layer_vertical.position.y = tile_set.tile_size.y / 2
		
		# Set offset for post layer
		_post_layer_horizontal.position.x = offset * tile_set.tile_size.x
		_post_layer_vertical.position.y = offset * tile_set.tile_size.y
		
		self.self_modulate.a = 0.0
	
## Redraws all tiles. Used for texture changes
func _redraw() -> void:
	if _initialized:
		_painted_cells = []
		_update_tiles()
	
## Update all tiles, based on differences
func _update_tiles() -> void:
	# The methodology outlined below is fairly terrible. Ideally, when a tile is set,
	# we'd just want to read that coordinate and perform the update there, but it doesn't
	# seem like that is possible in Godot 4.3 so far
	# This method simply checks for any new cells in the array, with a time complexity of O(n)
	# As you can imagine, this only gets worse as the amount of cells grows. 
	
	var prev_painted_cells = _painted_cells
	_painted_cells = get_used_cells() 
			
	# Find and clear removed fences
	for cell in prev_painted_cells:
		if not cell in _painted_cells:
			_clear_fence_neighbors(cell)
			_clear_post_cell(cell, true)
			
	# Find and draw new fences
	for cell in _painted_cells:
		if not cell in prev_painted_cells:
			_draw_fence_neighbors(cell)
			_draw_post_neighbors(cell, true)

## Is this cell painted (as far as the array [member painted_cells] is aware)?
func _is_painted(cell: Vector2i) -> bool:
	return _painted_cells.has(cell)

## Retrieve all neighbors that are drawn, as [method get_surrounding_cells] retrieves all possible neighbors, not only existing ones
func _get_drawn_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return get_surrounding_cells(cell).filter(_is_painted)

## Retrieve all direct neighbors, in addition to diagonal ones
func _get_all_drawn_neighbors(cell: Vector2i) -> Array[Vector2i]:
	# Start with diagonal neighbors
	var all_neighbors : Array[Vector2i] = 	[cell + Vector2i.LEFT + Vector2i.DOWN, 
											 cell + Vector2i.LEFT + Vector2i.UP, 
											 cell + Vector2i.RIGHT + Vector2i.DOWN, 
											 cell + Vector2i.RIGHT + Vector2i.UP] 
	all_neighbors.append_array(get_surrounding_cells(cell)) # Add direct neighbors
	return all_neighbors.filter(_is_painted) # Filter

## Counts the amount of drawn neighbors in either direction
func _count_neighbors(cell: Vector2i) -> Vector2i:
	var axis_neighbors = Vector2i.ZERO			# Neighbors on corresponding axis
	for neighbor in _get_drawn_neighbors(cell): 	# For every neighbor cell
		if (neighbor.x == cell.x):				# If neighbor is on y-axis (vertical neighbor)
			axis_neighbors.y += 1				# Increase y-axis neighbor count
		else:									# Same, for x-axis (horizontal neighbor)
			axis_neighbors.x += 1
	return axis_neighbors

## Determines if cell is in a chain of strictly vertical or horizontal cells, or indeterminate
func _determine_axis(cell: Vector2i) -> Axis:
	match _count_neighbors(cell):
		Vector2i(2,0): # If there are neighbors to the left of, and to the right of
			return Axis.HORIZONTAL
		Vector2i(0,2): # If there are neigbors above and below
			return Axis.VERTICAL
		_:			   # Otherwise, treat the same as static post
			return Axis.BOTH_OR_NEITHER

## Get cell to the left of cell			
func _left_of(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.LEFT
	
## Get cell to the right of cell	
func _right_of(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.RIGHT
	
## Get cell above cell		
func _above(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.UP
	
## Get cell below cell		
func _below(cell: Vector2i) -> Vector2i:
	return cell + Vector2i.DOWN

## Paints fence posts around and within a certain cell
func _draw_post_neighbors(cell: Vector2i, should_update_neigbors: bool = false) -> void:
	match _determine_axis(cell):
		Axis.HORIZONTAL:
			if offset > 0:
				_post_layer_horizontal.set_cell(_left_of(cell), fence_post_texture_ID, Vector2i.ZERO)
			_post_layer_horizontal.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
		Axis.VERTICAL:
			if offset > 0:
				_post_layer_vertical.set_cell(_above(cell), fence_post_texture_ID, Vector2i.ZERO)
			_post_layer_vertical.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
		Axis.BOTH_OR_NEITHER:
			_post_layer_stationary.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
	if should_update_neigbors: # If this cell is newly painted, trigger update for neighbors
		_update_post_neighbors(cell)

## Remove fence posts in a certain cell
func _clear_post_cell(cell: Vector2i, should_update_neigbors: bool = false) -> void:
	if _post_layer_stationary.get_used_cells().has(cell):
		_post_layer_stationary.erase_cell(cell)
	else:
		var right = _right_of(cell)
		var below = _below(cell)
		# If post on the right doesn't exist, or if there is no conflict
		if not _is_painted(right) or _determine_axis(right) != Axis.HORIZONTAL: 
			_post_layer_horizontal.erase_cell(cell) # Erase horizontal part
		# Same, for below
		if not _is_painted(below) or _determine_axis(below) != Axis.VERTICAL: 
			_post_layer_vertical.erase_cell(cell)
			
		# Erase any offset copies	
		var left = _left_of(cell)
		var above = _above(cell)
		# Same logic as for the previous erasures
		if not _is_painted(left) or _determine_axis(left) != Axis.HORIZONTAL:
			_post_layer_horizontal.erase_cell(left)
		if not _is_painted(above) or _determine_axis(above) != Axis.VERTICAL:
			_post_layer_vertical.erase_cell(above)
	if should_update_neigbors: # If this cell is newly cleared, trigger update for neighbors
		_update_post_neighbors(cell)

## Update neighbors surrounding a post, in case posts can no longer be movable				
func _update_post_neighbors(cell: Vector2i) -> void:
	for neighbor in _get_all_drawn_neighbors(cell): 	# For every neighbor (including diagonals)
		_clear_post_cell(neighbor)					# Clear current drawn posts
		_draw_post_neighbors(neighbor)				# Redraw posts again

## Paint neighbors of a certain cell
func _draw_fence_neighbors(cell: Vector2i) -> void:
	var alternate_tile = get_cell_alternative_tile(cell)
	for neighbor in _get_drawn_neighbors(cell): 	# For every neighbor cell
		var pos = cell
		if neighbor.x == cell.x: 	# If neighbor is on vertical axis
			if neighbor.y < cell.y: # If neighbor is below
				pos = _above(cell)
				
			var rotation = TileTransform.ROTATE_90
			if direction_interpretation_mode == DIRECTION_INTERPRETATION_MODE.EXPLICIT:
				match alternate_tile:
					TileTransform.ROTATE_180: # 180 is the only supported rotation (other than 0, technically)
						rotation = TileTransform.ROTATE_270
					# Unsupported angles below
					TileTransform.ROTATE_90:
						if enable_unsupported_directions:
							rotation = TileTransform.ROTATE_180
					TileTransform.ROTATE_270:
						if enable_unsupported_directions:
							rotation = TileTransform.ROTATE_0
			_fence_layer_vertical.set_cell(pos, fence_texture_ID, Vector2i.ZERO, rotation)
		elif neighbor.y == cell.y:	# If neighbor is on horizontal axis
			if neighbor.x < cell.x: # If neighbor is to the left
				pos = _left_of(cell)
			
			var rotation = 0
			# Apply rotation, if any
			if direction_interpretation_mode == DIRECTION_INTERPRETATION_MODE.EXPLICIT:
				if enable_unsupported_directions: # Apply rotations regardless, if unsupported directions are supported
					rotation = alternate_tile
				elif alternate_tile == TileTransform.ROTATE_180: # 180 degrees is supported, though
					rotation = alternate_tile
			_fence_layer_horizontal.set_cell(pos, fence_texture_ID, Vector2i.ZERO, rotation)

## Remove neighbors of a certain cell.
func _clear_fence_neighbors(cell: Vector2i) -> void:
	_fence_layer_horizontal.erase_cell(cell)				# Cell to the right
	_fence_layer_horizontal.erase_cell(_left_of(cell))	# Cell to the left
	_fence_layer_vertical.erase_cell(cell)				# Cell above
	_fence_layer_vertical.erase_cell(_above(cell))		# Cell below
