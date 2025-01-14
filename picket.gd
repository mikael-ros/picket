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
	

# -----------------------------
func _enter_tree() -> void:
	# Initialize fence
	fence_layer_horizontal = TileMapLayer.new()
	fence_layer_vertical = TileMapLayer.new()
	post_layer_horizontal = TileMapLayer.new()
	post_layer_vertical = TileMapLayer.new()
	post_layer_stationary = TileMapLayer.new()
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
	# Make sure fence layers are under posts
	fence_layer_horizontal.show_behind_parent = true
	fence_layer_vertical.show_behind_parent = true
	
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
		if (not cell in painted_cells):
			clear_fence_neighbors(cell)
			clear_post_cell(cell)
			
	# Find and draw new fences
	for cell in painted_cells:
		if (not cell in prev_painted_cells):
			draw_fence_neighbors(cell)
			

	
## Paint neighbors of a certain cell. More performant than [method draw_fence]
func draw_fence_neighbors(cell: Vector2i) -> void:
	var axis_neighbors = Vector2i.ZERO
	for neighbor in get_surrounding_cells(cell): 	# For every neighbor cell
		if painted_cells.has(neighbor):	 			# If neighbor is painted (get_surrounding_cells includes every cell, so)
			set_fence_cell(cell, neighbor)
			if (neighbor.x == cell.x):
				axis_neighbors.x += 1
			else:
				axis_neighbors.y += 1
	
	var axis = Axis.BOTH_OR_NEITHER
	if axis_neighbors == Vector2i(0,2):
		axis = Axis.HORIZONTAL
	elif axis_neighbors == Vector2i(2,0):
		axis = Axis.VERTICAL
		
	set_post_cell(cell, axis)
		

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
func clear_fence_neighbors(cell: Vector2i) -> void:
	for neighbor in get_surrounding_cells(cell): # Remove cells in every direction
		fence_layer_horizontal.erase_cell(cell)							# Cell to the right
		fence_layer_horizontal.erase_cell(Vector2(cell.x - 1, cell.y))	# Cell to the left
		fence_layer_vertical.erase_cell(cell)							# Cell above
		fence_layer_vertical.erase_cell(Vector2(cell.x, cell.y - 1))	# Cell below
		
## Paints posts in intermediary layers
func set_post_cell(cell: Vector2i, axis: Axis) -> void:
	match axis:
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

func clear_post_cell(cell: Vector2i) -> void:
	post_layer_horizontal.erase_cell(cell)
	post_layer_vertical.erase_cell(cell)
	post_layer_stationary.erase_cell(cell)
