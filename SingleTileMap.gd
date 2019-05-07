extends TileMap

export(Texture) var override_texture

func _ready():
	if override_texture:
		tile_set = tile_set.duplicate(true)
		for tile in tile_set.get_tiles_ids():
			tile_set.tile_set_texture(tile, override_texture)
