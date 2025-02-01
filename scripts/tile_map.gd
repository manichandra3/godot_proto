extends TileMap

class_name PathfindingTileMap

# Constants for diagonal movement and optimization
const DIAGONAL_COST := 1.4
const ENABLE_DIAGONALS := true
const OPTIMIZATION_DISTANCE := 10.0

# A* pathfinding instance
var aStar: AStar2D
var debug_mode: bool = false
var map_size: Vector2i

func _ready() -> void:
	aStar = AStar2D.new()
	map_size = get_used_rect().size
	setup_astar_grid()

# Creates A* Grid based on TileMap with optional diagonal connections
func setup_astar_grid() -> void:
	aStar.clear()
	
	var used_rect = get_used_rect()
	var used_cells = get_used_cells(0)
	if used_cells.is_empty():
		return
	
	# Use actual TileMap bounds
	map_size = used_rect.size
	var total_cells = map_size.x * map_size.y
	aStar.reserve_space(total_cells)
	
	# Add all valid cells as points with offset from used_rect
	for cell in used_cells:
		# Adjust cell coordinates relative to used_rect origin
		var adjusted_cell = cell - used_rect.position
		var idx = get_astar_cell_id(adjusted_cell)
		if idx >= 0:
			aStar.add_point(idx, map_to_local(cell))
	
	# Connect neighbors including optional diagonals
	for cell in used_cells:
		var adjusted_cell = cell - used_rect.position
		var idx = get_astar_cell_id(adjusted_cell)
		if idx < 0:
			continue
			
		var neighbors = [
			cell + Vector2i(0, -1),  # Up
			cell + Vector2i(0, 1),   # Down
			cell + Vector2i(-1, 0),  # Left
			cell + Vector2i(1, 0)    # Right
		]
		
		if ENABLE_DIAGONALS:
			neighbors.append_array([
				cell + Vector2i(-1, -1),  # Top Left
				cell + Vector2i(1, -1),   # Top Right
				cell + Vector2i(-1, 1),   # Bottom Left
				cell + Vector2i(1, 1)     # Bottom Right
			])
		
		for neighbor in neighbors:
			var adjusted_neighbor = neighbor - used_rect.position
			var idx_neighbor = get_astar_cell_id(adjusted_neighbor)
			if idx_neighbor >= 0 and aStar.has_point(idx_neighbor):
				var is_diagonal = abs(cell.x - neighbor.x) + abs(cell.y - neighbor.y) == 2
				var weight = DIAGONAL_COST if is_diagonal else 1.0
				if not aStar.are_points_connected(idx, idx_neighbor):
					aStar.connect_points(idx, idx_neighbor, true)
					aStar.set_point_weight_scale(idx_neighbor, weight)

func get_astar_cell_id(cell: Vector2i) -> int:
	if map_size.y == 0:
		return -1
	
	# Ensure cell is within bounds
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return -1
		
	return cell.y + cell.x * map_size.y

func get_nearest_valid_point(cell_pos: Vector2i, max_radius: int = 3) -> int:
	var used_rect = get_used_rect()
	var adjusted_pos = cell_pos - used_rect.position
	
	var idx = get_astar_cell_id(adjusted_pos)
	if idx >= 0 and aStar.has_point(idx) and not aStar.is_point_disabled(idx):
		return idx
	
	# Spiral search pattern for nearby points
	for radius in range(1, max_radius + 1):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if abs(x) == radius or abs(y) == radius:
					var neighbor = adjusted_pos + Vector2i(x, y)
					var neighbor_idx = get_astar_cell_id(neighbor)
					if neighbor_idx >= 0 and aStar.has_point(neighbor_idx) and not aStar.is_point_disabled(neighbor_idx):
						return neighbor_idx
	return -1

func get_astar_path(start_pos: Vector2, end_pos: Vector2, smooth: bool = true) -> Array:
	var cell_start = local_to_map(start_pos)
	var cell_target = local_to_map(end_pos)
	
	var idx_start = get_nearest_valid_point(cell_start)
	var idx_target = get_nearest_valid_point(cell_target)
	
	if idx_start >= 0 and idx_target >= 0:
		var path = aStar.get_point_path(idx_start, idx_target)
		if smooth and path.size() > 2:
			path = smooth_path(path)
		return path
	return []

func smooth_path(path: Array) -> Array:
	if path.size() <= 2:
		return path
		
	var smoothed_path: Array = []
	smoothed_path.append(path[0])  # Add start point
	
	# Use path simplification by checking if we can move directly between points
	var current_idx := 0
	while current_idx < path.size() - 1:
		var can_skip := false
		for look_ahead in range(current_idx + 2, path.size()):
			# Check if we can directly move to a point further ahead
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(path[current_idx], path[look_ahead])
			var result = space_state.intersect_ray(query)
			
			if result.is_empty():  # If no collision, we can skip points
				can_skip = true
				if look_ahead == path.size() - 1:
					smoothed_path.append(path[look_ahead])
					current_idx = look_ahead
					break
			else:
				if can_skip:
					smoothed_path.append(path[look_ahead - 1])
					current_idx = look_ahead - 1
					break
				else:
					smoothed_path.append(path[current_idx + 1])
					current_idx += 1
					break
		
		if not can_skip:
			current_idx += 1
	
	# Ensure end point is added
	if smoothed_path[-1] != path[-1]:
		smoothed_path.append(path[-1])
	
	return smoothed_path

func occupy_astar_cell(pos: Vector2) -> void:
	var cell = local_to_map(pos)
	var used_rect = get_used_rect()
	var adjusted_cell = cell - used_rect.position
	var idx = get_astar_cell_id(adjusted_cell)
	if idx >= 0 and aStar.has_point(idx):
		aStar.set_point_disabled(idx, true)

func free_astar_cell(pos: Vector2) -> void:
	var cell = local_to_map(pos)
	var used_rect = get_used_rect()
	var adjusted_cell = cell - used_rect.position
	var idx = get_astar_cell_id(adjusted_cell)
	if idx >= 0 and aStar.has_point(idx):
		aStar.set_point_disabled(idx, false)
