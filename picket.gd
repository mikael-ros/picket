@tool
class_name Picket
extends TileMapLayer

# -----------------------------
# Properties used in the plugin
@export_group("Texture positions")			# Positions in the tilemap for the textures used by the plugin
@export var fence_texture_ID : int = 0:		## Position for the texture for the fence itself. Assumed to be first
	set(new_fence_texture_ID): 
		fence_texture_ID = new_fence_texture_ID
		redraw()
@export var fence_post_texture_ID : int = 1:## Position for the texture for the posts placed intermittently
	set(new_fence_post_texture_ID): 
		fence_post_texture_ID = new_fence_post_texture_ID
		redraw()

@export_group("Positioning")				# Exported variables related to position of the fence
@export_range(0,1, 0.01) var offset = 0.0:	## The offset
	set(new_offset): 
		offset = new_offset
		set_properties(true)
@export var origin_x : float = 0.0:			## Custom x origin position
	set(new_x): 
		origin_x = new_x
		set_properties()
@export var origin_y : float = 0.0:			## Custom y origin position
	set(new_y): 
		origin_y = new_y
		set_properties()
@export_subgroup("Anchor")					# Where in a tile the intersection of two fences will occur
@export_range(0, 1, 0.01) var anchor_x : float = 0.5: ## Anchor x 
	set(new_x): 
		anchor_x = new_x
		set_properties()
@export_range(0, 1, 0.01) var anchor_y : float = 0.5: ## Anchor y 
	set(new_y): 
		anchor_y = new_y
		set_properties()

# ---------------
# Local properties
var fence_layer_horizontal : TileMapLayer 	## Layer upon which the horizontal parts are displayed
var fence_layer_vertical : TileMapLayer 	## Layer upon which the horizontal parts are displayed

var post_layer_horizontal : TileMapLayer
var post_layer_vertical : TileMapLayer
var post_layer_stationary : TileMapLayer

var painted_cells : Array[Vector2i] 		## Used for tracking what cells were painted last revision

enum Axis {
	HORIZONTAL,
	VERTICAL,
	BOTH_OR_NEITHER
}
	
var inited = false
# -----------------------------
func _enter_tree() -> void:
	# Initialize fence
	fence_layer_horizontal = TileMapLayer.new()
	fence_layer_vertical = TileMapLayer.new()
	post_layer_horizontal = TileMapLayer.new()
	post_layer_vertical = TileMapLayer.new()
	post_layer_stationary = TileMapLayer.new()
	inited = true
	
	# Add children, draw initial fence
	add_child(fence_layer_horizontal)
	add_child(fence_layer_vertical)
	add_child(post_layer_horizontal)
	add_child(post_layer_vertical)
	add_child(post_layer_stationary)
	
	set_properties(true)

func _exit_tree() -> void:
	fence_layer_horizontal.free()
	fence_layer_vertical.free()
	
func _ready() -> void:
	set_process(Engine.is_editor_hint()) # Only use [method _process] in the editor
	if (Engine.is_editor_hint()):
		changed.connect(set_properties)  # Only connect [method set_properties] if in the editor

func _process(delta) -> void:
	update_tiles() # Update tiles every tick. Not effecient, but cant find a better solution yet

## Propagate properties over
func set_properties(redraw: bool = false) -> void:
	if inited:
		
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

## Retrieve all neighbors that are drawn, as [method get_surrounding_cells] retrieves all possible neighbors, not only existing ones
func get_drawn_neighbors(cell: Vector2i) -> Array[Vector2i]:
	return get_surrounding_cells(cell).filter(func(c): return painted_cells.has(c))

## Counts the amount of drawn neighbors in either direction
func count_neighbors(cell: Vector2i) -> Vector4i:
	var axis_neighbors = Vector4i.ZERO			# Neighbors on corresponding axis (-x,+y,+x,-y)
	for neighbor in get_drawn_neighbors(cell): 	# For every neighbor cell
		match cell - neighbor:
			Vector2i(-1,0): # Left of (-x)
				axis_neighbors.w = 1
			Vector2i(0,1): 	# Above (+y)
				axis_neighbors.x = 1
			Vector2i(1,0): 	# Right of (+x)
				axis_neighbors.y = 1
			Vector2i(0,-1): # Below (-y)
				axis_neighbors.z = 1
	return axis_neighbors

## Determines if cell is in a chain of strictly vertical or horizontal cells, or indeterminate
func determine_axis(cell: Vector2i, neighbor_count: Vector4i = -Vector4i.ONE) -> Axis:
	var n_count = neighbor_count
	if neighbor_count == -Vector4i.ONE: # If count has not been performed, perform count
		n_count = count_neighbors(cell)
	match n_count:
		Vector4i(1,0,1,0):
			return Axis.HORIZONTAL
		Vector4i(0,1,0,1):
			return Axis.VERTICAL
		_:
			return Axis.BOTH_OR_NEITHER

## Paints fence posts around and within a certain cell
func draw_post_neighbors(cell: Vector2i, new: bool = false) -> void:
	match determine_axis(cell):
		Axis.HORIZONTAL:
			if offset > 0:
				post_layer_horizontal.set_cell(Vector2(cell.x - 1, cell.y), fence_post_texture_ID, Vector2i.ZERO)
			post_layer_horizontal.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
		Axis.VERTICAL:
			if offset > 0:
				post_layer_vertical.set_cell(Vector2(cell.x, cell.y - 1), fence_post_texture_ID, Vector2i.ZERO)
			post_layer_vertical.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
		Axis.BOTH_OR_NEITHER:
			post_layer_stationary.set_cell(cell, fence_post_texture_ID, Vector2i.ZERO)
	if new:
		update_post_neighbors(cell)

## Remove fence posts in a certain cell
func clear_post_cell(cell: Vector2i, new: bool = false) -> void:
	post_layer_horizontal.erase_cell(cell)
	post_layer_vertical.erase_cell(cell)
	post_layer_stationary.erase_cell(cell)
	if new:
		update_post_neighbors(cell)
					
func update_post_neighbors(cell: Vector2i) -> void:
	var all_neighbors = [Vector2i(cell.x-1,cell.y+1), Vector2i(cell.x-1,cell.y-1), Vector2i(cell.x+1,cell.y+1), Vector2i(cell.x+1,cell.y-1)]
	all_neighbors.append_array(get_drawn_neighbors(cell))
	for neighbor in all_neighbors:
		if painted_cells.has(neighbor):
			clear_post_cell(neighbor)
			draw_post_neighbors(neighbor)
				
## Paint neighbors of a certain cell. More performant than [method draw_fence]
func draw_fence_neighbors(cell: Vector2i) -> void:
	for neighbor in get_drawn_neighbors(cell): 	# For every neighbor cell
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
func clear_fence_neighbors(cell: Vector2i) -> void:
	fence_layer_horizontal.erase_cell(cell)							# Cell to the right
	fence_layer_horizontal.erase_cell(Vector2(cell.x - 1, cell.y))	# Cell to the left
	fence_layer_vertical.erase_cell(cell)							# Cell above
	fence_layer_vertical.erase_cell(Vector2(cell.x, cell.y - 1))	# Cell below
	
