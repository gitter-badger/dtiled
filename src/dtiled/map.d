/**
 * Provides a generic TileMap structure with commonly-needed functionality.
 *
 * While the types provided in dtiled.data are intended to provide the information needed to
 * load a map into a game, a TileMap is a structure intended to be used in-game.
 *
 * Authors: <a href="https://github.com/rcorre">rcorre</a>
 * License: <a href="http://opensource.org/licenses/MIT">MIT</a>
 * Copyright: Copyright © 2015, Ryan Roden-Corrent
 */
module dtiled.map;

import std.range     : only, take, chain;
import std.algorithm : map, filter;
import dtiled.data;
import dtiled.spatial;

version(unittest) {
  struct TestTile { int row, col; }

  alias TestMap = OrthoMap!TestTile;

  TestTile[][] testTiles;

  TestMap buildTestMap() {
    foreach(row ; 0..5) {
      foreach(col ; 0..5) {
        testTiles[row][col] = TestTile(row, col);
      }
    }

    // map is a 5x5 grid of tiles, each sized 32x32 pixels
    return TestMap(32, 32, testTiles);
  }
}

/**
 * Which tiles are included when getting the neighbors of a tile.
 *
 * Given the following grid of tiles:
 * v e v
 * e c e
 * v e v
 * 'c' is the 'center', 'e' are the 'edge' neighbors, and 'v' are the 'vertex' neighbors.
 * 'surround' would include all 'e' and 'v' tiles, 'all' would of course include all.
 */
enum NeighborType {
  center = 1 >> 0, /// The center tile.
  edge   = 1 >> 1, /// Tiles adjacent to the sides of the center.
  vertex = 1 >> 2, /// Tiles diagonally bordering the corners of the center.

  surround = edge | vertex,     /// All tiles around the center.
  all      = surround | center, /// All tiles around and including the center.
}

/**
 * Generic Tile Map structure that uses a single layer of tiles in an orthogonal grid.
 *
 * This provides a 'flat' representation of multiple tile and object layers.
 * T can be whatever type you would like to use to represent a single tile within the map.
 */
struct OrthoMap(Tile) {
  private {
    Tile[][] _tiles;
    size_t _numRows;
    size_t _numCols;
    int _tileWidth;
    int _tileHeight;
  }

  /**
   * Construct an orthogonal tilemap. The grid must be rectangular (not jagged).
   *
   * Params:
   *  tileWidth = width of each tile in pixels
   *  tileHeight = height of each tile in pixels
   *  tiles = tiles arranged in **row major** order, indexed as tiles[row][col].
   */
  this(int tileWidth, int tileHeight, Tile[][] tiles) {
    _tileWidth  = tileWidth;
    _tileHeight = tileHeight;

    _numRows = tiles.length;
    _numCols = tiles[0].length;

    debug {
      import std.algorithm : all;
      assert(tiles.all!(x => x.length == tiles[0].length),
          "all rows of an OrthoMap must have the same length (cannot be jagged array)");
    }

    _tiles = tiles;
  }

  @property {
    /// Number of rows along the tile grid y axis
    auto numRows()    { return _numRows; }
    /// Number of columns along the tile grid x axis
    auto numCols()    { return _numCols; }
    /// Width of each tile in pixels
    auto tileWidth()  { return _tileWidth; }
    /// Height of each tile in pixels
    auto tileHeight() { return _tileHeight; }
    /// Access the underlying tile store
    auto tiles()      { return _tiles; }
  }

  /**
   * Get the grid location corresponding to a given pixel coordinate.
   * Does not check bounds; the row/col may be negative or greater than numRows/numCols.
   */
  auto gridCoordAt(T)(T pos) if (isPixelCoord!T) {
    GridCoord coord;
    coord.col = pos.x / tileWidth;
    coord.row = pos.y / tileHeight;
    return coord;
  }

  /**
   * True if the grid coordinate is within the map bounds.
   */
  bool contains(GridCoord coord) {
    return coord.col >= 0 && coord.row >= 0 && coord.row < numRows && coord.col < numCols;
  }

  /**
   * True if the pixel position is within the map bounds.
   */
  bool contains(T)(T pos) if (isPixelCoord!T) {
    return contains(gridCoordAt(pos));
  }

  /**
   * Get the tile at a given position in the grid. Throws if out of bounds.
   * Params:
   *  coord = a row/column pair identifying a point in the tile grid.
   */
  Tile tileAt(GridCoord coord) {
    return _tiles[coord.row][coord.col];
  }

  /**
   * Get the tile at a given pixel position on the map. Throws if out of bounds.
   * Params:
   *  T = any pixel-positional point (see isPixelCoord).
   *  pos = pixel location in 2D space
   */
  Tile tileAt(T)(T pos) if (isPixelCoord!T) {
    return tileAt(gridCoordAt(pos));
  }

  /**
   * Return tiles adjacent to the given tile.
   *
   * Params:
   *  coord = grid location of center tile.
   *  neighbors = describes which neighbors to fetch.
   */
  auto neighbors(GridCoord coord, NeighborType neighbors = NeighborType.edge) {
    // TODO: this should be doable without allocating. custom range?
    GridCoord[] coords;

    if (neighbors & NeighborType.center) {
      coords ~= coord;
    }

    if (neighbors & NeighborType.edge) {
      coords ~= GridCoord(coord.row - 1, coord.col    );
      coords ~= GridCoord(coord.row    , coord.col - 1);
      coords ~= GridCoord(coord.row + 1, coord.col    );
      coords ~= GridCoord(coord.row    , coord.col + 1);
    }

    if (neighbors & NeighborType.vertex) {
      coords ~= GridCoord(coord.row - 1, coord.col - 1);
      coords ~= GridCoord(coord.row - 1, coord.col + 1);
      coords ~= GridCoord(coord.row + 1, coord.col - 1);
      coords ~= GridCoord(coord.row + 1, coord.col + 1);
    }

    // for the in-range coordinates, get the corresponding tiles
    return coords.filter!(x => this.contains(x)).map!(x => this.tileAt(x));
  }
}
