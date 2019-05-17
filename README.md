# SuperTilemap

This is a Godot Engine 3.1 project showing the use of stacked TileMap nodes to render a classic sloped isometric map, as seen in Transport Tycoon Deluxe (or OpenTTD, nowadays).

![Screenshot](https://raw.githubusercontent.com/PetePete1984/SuperTilemap/master/media/screenshot.png)

## Motivation  
The default TileMap node represents a single level of tiles and has built-in support for basic colliders and some Godot-style 2D light occlusion. This is enough for pretty much all games that keep gameplay on a flat plane, and can also be enough for some fake height display if you use non-flat tiles. They also allow for easy sorting of child nodes (so your player can walk behind trees), albeit only in Y direction.

[Dean](https://github.com/deanvaessen) wanted a tilemap with multiple levels, and I wanted to see if I could make it work because for some reason sloped iso heightmaps seem to be somewhat of a mystery. So here we are!

## Usage
Open the project in Godot, click the "World" Node in the main scene that pops up and play with its exported settings. Running the project/scene will draw the map.

## Concept
Since this is written in hindsight, it's also more of an experimentation log than the idea I based this off, because the ideas came after the fact.

1. Acquire appropriate image set of tiles for experimentation, see Reference [1]
1. Build TileSet resource in Godot, apply texture from step 1
1. Place a default TileMap into the world and start painting flat tiles and slopes, to see how they line up
1. Realize that slopes connect perfectly when they start at the height you're painting on, and point one height level higher
1. Realize that flat "height 0" and "height 1" tiles would need to be offset by a constant pixel amount, so the higher level connects to the slopes again
1. Place a second TileMap and offset it by (in this case) 8 pixels upwards
1. Start painting tiles on second TileMap, see that they line up, rejoice!

After that initial set of tinkering it was time for the difficult part: actually putting it into code. Well, that became a headache and a half.

1. Add a few (first try: three) TileMap nodes with vertical offsets
1. Generate some [noise](https://docs.godotengine.org/en/3.1/classes/class_opensimplexnoise.html) for a 2D heightmap, put it into a grid data structure
1. The first attempt sampled the float noise value and mapped it to 0, 1 and 2 values in the grid, which corresponds to the three tilemaps
1. As per the above observations, we should try to slope all tiles that have higher neighboring tiles
1. To find out which corners are raised, sample the diagonal neighbors for each tile (North, East, South, West)
1. Contrary to intuition, diagonals are actually the visually-not-diagonal tiles!
1. With the neighbor info, construct a bitmask (0000 = flat, 0001 = south raised, 0010 = east raised etc)
1. Map the TileSet tile IDs to the bitmask
1. Paint the tiles into the tilemaps: get the height (= which tilemap to paint onto) from the grid data, get the tile from the tile-id-to-bitmask-mapping

This started off pretty okay, but basically only worked for corners because the tiles didn't look at their neighbors across each edge. After adding that (lots of trial and error and semi-educated guessing involved), most cases looked good but there were still holes here and there.

The holes stem from the fact that the generator doesn't play by the rules of the tileset, and instead of fiddling with it (which I wasn't confident about) I applied some rudimentary smoothing (which I'm also not confident about).

This can likely be avoided with correct generator settings, or a smooth terracing pre-pass over the heightmap (so that all neighbors only ever have +1 height difference, *maybe* respecting the rare cases where one neighbor is -1 and the other +1).

Afterwards I tried to get rid of most of the magic numbers, package the settings into export vars and make the entire thing a bit more dynamic. That includes being able to use more tilemap levels (they're scene instances now), some texture overrides for multiple tile colors and the ability to toggle some of the generator / display options.

## Disclaimer
I'm convinced that games like TTD actually work with the corners (vertices) between tiles, instead of the tiles themselves, which would make this process easier (probably). Godot only stores one value (Tile ID) per grid position, so unless you keep that info out of the tilemap (which this kinda does, but not in a persistent way) it's difficult to replicate.

I also have only the faintest idea how OpenSimplex works, so I've left the settings at their defaults as per the Godot docs.

On top of that, I'm pretty sure that the code I've produced isn't The Best Way to do things, as evidenced by the fact that there are still holes everywhere. Chalk it up to the tileset not being great for +2 or higher elevation differences, and the generator happily generating such cliffs all day, especially if you set the levels too high.

There's zero concern applied here for NavPoly, Collision or any other feature "on top" of TileMaps, I just wanted slopes, man.

Also, my first approach used hashed neighbor dictionaries instead of bitmasks, but don't tell anyone.

## References

[1] Clint Bellanger's "Terrain Renderer" Tileset on opengameart [https://opengameart.org/content/terrain-renderer](https://opengameart.org/content/terrain-renderer)
[2] TTD Tile Slope List [https://newgrf-specs.tt-wiki.net/wiki/NML:List_of_tile_slopes](https://newgrf-specs.tt-wiki.net/wiki/NML:List_of_tile_slopes)

## License
As per the LICENSE file, the MIT License applies.

## Shameless self-promo
If you like what you see here, check out my other Github repos!
If you really like what you see here, I have a Patreon too, where you can <a href="https://www.patreon.com/bePatron?u=19976598" data-patreon-widget-type="become-patron-button">Become a Patron!</a>
