extends Node2D

const tilemap_scene = preload("res://SingleTileMap.tscn")
var textures = [preload("res://tiles_sand.png"), preload("res://tiles_grass.png"), preload("res://tiles_red.png")]

export var world_width = 100
export var world_height = 100

export var levels = 15
export var level_offset = Vector2(0, -8)

export var slopes = true
export var smooth = true
export var stacking = false
export var staggered_display = true
export var tiles_per_frame = 10

export var texturing = false
export var randomization = true

export (int, 1, 6) var noise_octaves = 4
export (float, 0.0, 40.0) var noise_period = 20.0
export (float, 1.0) var noise_persistence = 0.8
export (float) var noise_frequency = 0.5

var grid = {}
var tile_ids = {}

var maps = []

var directions = {
	"CORNER_N": Vector2(-1, -1),
	"CORNER_W": Vector2(-1, 1),
	"CORNER_E": Vector2(1, -1),
	"CORNER_S": Vector2(1, 1)
}

var sides = {
	"SIDE_N": Vector2(0, -1),
	"SIDE_W": Vector2(-1, 0),
	"SIDE_E": Vector2(1, 0),
	"SIDE_S": Vector2(0, 1)
}

var bitmasks = {
	"CORNER_S": 1,
	"CORNER_E": 2,
	"CORNER_W": 4,
	"CORNER_N": 8,
	"STEEP": 16
}

# flat = 0
# south corner = 1
# east corner = 2
# west corner = 4
# north corner = 8
# steep = 16
# south & east corners = (1 | 2) == 3 (bitwise OR)
# south, east, north corners raised, east corner steep = (1 | 2 | 8 | 16) == 27
var bit_tiles = {
	0: 0,
	1: 5, # south
	2: 6, # east
	3: 10, # south east
	4: 4, # west
	5: 9, # south west
	6: 21, # west east
	7: 13, # south west east
	8: 7, # north
	9: 20, # north south
	10: 11, # north east
	11: 14, # north east south
	12: 8, # north west
	13: 12, # north west south
	14: 15, # north west east
	15: 1, # flat but different tile, is replaced by +1 height at runtime when smoothing is enabled
	24: 17, # TODO: unfinished, should be four tiles for +2 slopes but generation is wonky
	25: 16
}

func _ready():
	var hashes = {}
	
	for height in levels:
		var instance = tilemap_scene.instance() as TileMap
		# pick texture based on height level
		if texturing:
			instance.override_texture = textures[floor((float(height) / float(levels)) * textures.size())]
		add_child(instance)
		# offset height level
		instance.position = height * level_offset
	
	for c in get_children():
		if c is TileMap:
			maps.append(c)
	
	if randomization:
		randomize()
		# pre-warm the randomizer to avoid seeding bugs - might not be necessary anymore, depends on godot build
		randi(); randi(); randi();
		
	# generate noise as per the settings above
	var noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = noise_octaves
	noise.period = noise_period
	noise.persistence = noise_persistence
	
	# keep track of lowest and highest noise generated
	var min_noise = INF
	var max_noise = -INF
	
	var noise_values = {}
	
	# generate noise values for all coordinates
	for i in world_width:
		for j in world_height:
			var noise_value = noise.get_noise_2d(noise_frequency * i, noise_frequency * j)
			if noise_value < min_noise:
				min_noise = noise_value
			if noise_value > max_noise:
				max_noise = noise_value
			noise_values[Vector2(i, j)] = noise_value
	
	# derive grid positions from noise values, normalized to min and max noise and max map height
	for i in world_width:
		for j in world_height:
			var current_noise = noise_values[Vector2(i, j)]
			var gridval = round(range_lerp(current_noise, min_noise, max_noise, 0, maps.size()-1))
			grid[Vector2(i, j)] = gridval
	
	var unique_neighbors = []
	
	var cell_index = 0
	
	for cell in grid:
		# read diagonal neighbors
		var neighbor_bits = {}
		var neighbors = 0
		var neighbor_steep = {}
		for dir_key in directions:
			var direction = directions[dir_key]
			var diag_key = cell + direction
			if grid.has(diag_key):
				var neighbor = grid[diag_key]
				if neighbor == grid[cell] + 1:
					neighbor_bits[direction] = 1
					#neighbors = neighbors | bitmasks[dir_key]
				elif neighbor == grid[cell] + 2:
					neighbor_bits[direction] = 1
					#neighbors = neighbors | bitmasks["STEEP"]
					neighbor_steep[direction] = true
				else:
					neighbor_bits[direction] = 0
			else:
				neighbor_bits[direction] = 0
				
		if not unique_neighbors.has(neighbors):
			unique_neighbors.append(neighbors)
		
		# read side neighbors
		var side_bits = {}
		for side_key in sides:
			var direction = sides[side_key]
			var cell_key = cell + direction
			if grid.has(cell_key):
				var side = grid[cell_key]
				if side == grid[cell] + 1:
					side_bits[direction] = 1
				else:
					side_bits[direction] = 0
			else:
				side_bits[direction] = 0
		
		# check sides too, so slopes work
		neighbor_bits[directions.CORNER_N] = neighbor_bits[directions.CORNER_N] | side_bits[sides.SIDE_N] | side_bits[sides.SIDE_W]
		neighbor_bits[directions.CORNER_W] = neighbor_bits[directions.CORNER_W] | side_bits[sides.SIDE_W] | side_bits[sides.SIDE_S]
		neighbor_bits[directions.CORNER_E] = neighbor_bits[directions.CORNER_E] | side_bits[sides.SIDE_N] | side_bits[sides.SIDE_E]
		neighbor_bits[directions.CORNER_S] = neighbor_bits[directions.CORNER_S] | side_bits[sides.SIDE_S] | side_bits[sides.SIDE_E]
		
		# apply sides to bitmask
		for neigh_direction in directions:
			if neighbor_bits.has(directions[neigh_direction]) and neighbor_bits[directions[neigh_direction]] == 1:
				neighbors = neighbors | bitmasks[neigh_direction]
		
		# raise cell if all direct neighbors are higher
		if smooth:
			if neighbor_bits[directions.CORNER_N] == 1 \
			and neighbor_bits[directions.CORNER_W] == 1 \
			and neighbor_bits[directions.CORNER_E] == 1 \
			and neighbor_bits[directions.CORNER_S] == 1:
				grid[cell] += 1
		
		# could maybe work if one checked for the sides instead?
#		if neighbor_steep.size() > 0:
#			grid[cell] += 1
			
		if slopes == true:
			tile_ids[grid[cell]] = bit_tiles[neighbors]
		else:
			tile_ids[grid[cell]] = 0
		
		# could be improved if the bitmasking worked as I expect it to
		if slopes == true:
			if neighbor_steep.has(directions.CORNER_W):
				tile_ids[grid[cell]] = 17
			elif neighbor_steep.has(directions.CORNER_S):
				tile_ids[grid[cell]] = 16
			elif neighbor_steep.has(directions.CORNER_N):
				tile_ids[grid[cell]] = 18
			elif neighbor_steep.has(directions.CORNER_E):
				tile_ids[grid[cell]] = 19
		
		maps[grid[cell]].set_cellv(cell, tile_ids[grid[cell]])
		
		if stacking:
			if grid[cell] > 0:
				for level in grid[cell]-1:
					maps[level].set_cellv(cell, 0)
				
		if staggered_display:
			cell_index += 1
			if cell_index % tiles_per_frame == 0:
				yield(get_tree(), "idle_frame")
