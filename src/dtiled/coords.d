/**
 * This module helps handle coordinate systems within a map.
 *
 * When dealing with a grid, do you ever forget whether the row or column is the first index?
 *
 * Me too.
 *
 * For this reason, all functions dealing with grid coordinates take a RowCol argument.
 * This makes it abundantly clear that the map is indexed in row-major order.
 * Furthormore, it prevents confusion between **grid** coordinates and **pixel** coordinates.
 *
 * A 'pixel' coordinate refers to an (x,y) location in 'pixel' space.
 * The units used by 'pixel' coords are the same as used in MapData tilewidth and tileheight.
 *
 * Within dtiled, pixel locations are represented by a PixelCoord.
 * However, you may already be using a game library that provides some 'Vector' implementation
 * used to represent positions.
 * You can pass any such type to dtiled functions expecting a pixel coordinate so long as it
 * satisfies isPixelCoord.
 */
module dtiled.coords;

import std.conv      : to;
import std.math      : abs, sgn;
import std.range     : iota, only, take, chain;
import std.format    : format;
import std.typecons  : Tuple, Flag;
import std.algorithm : map, cartesianProduct;

private alias coord_t = long;

/// Whether to consider diagonals adjacent in situations dealing with the concept of adjacency.
alias Diagonals = Flag!"Diagonals";

/// Represents a discrete location within the map grid.
struct RowCol {
  coord_t row, col;

  /// Construct a row column pair
  @nogc
  this(coord_t row, coord_t col) {
    this.row = row;
    this.col = col;
  }

  /// Get a string representation of the coordinate, useful for debugging
  @property {
    string toString() {
      return "(%d,%d)".format(row, col);
    }

    /**
     * Get a coordinate above this coordinate
     * Params:
     *  dist = distance in number of tiles
     */
    auto north(int dist = 1) { return RowCol(row - dist, col); }

    /**
     * Get a coordinate below this coordinate
     * Params:
     *  dist = distance in number of tiles
     */
    auto south(int dist = 1) { return RowCol(row + dist, col); }

    /**
     * Get a coordinate to the left of this coordinate
     * Params:
     *  dist = distance in number of tiles
     */
    auto west(int dist = 1)  { return RowCol(row, col - dist); }

    /**
     * Get a coordinate to the right of this coordinate
     * Params:
     *  dist = distance in number of tiles
     */
    auto east(int dist = 1)  { return RowCol(row, col + dist); }

    /**
     * Return a range containing the coords adjacent to this coord.
     *
     * The returned coords are ordered from north to south, west to east.
     *
     * Params:
     *  diagonal = if no, include coords to the north, south, east, and west only.
     *             if yes, additionaly include northwest, northeast, southwest, and southeast.
     */
    auto adjacent(Diagonals diagonal = Diagonals.no) {
      // the 'take' statements are used to conditionally include the diagonal coords
      return chain(
          (this.north.west).only.take(diagonal ? 1 : 0),
          (this.north).only,
          (this.north.east).only.take(diagonal ? 1 : 0),
          (this.west ).only,
          (this.east ).only,
          (this.south.west).only.take(diagonal ? 1 : 0),
          (this.south).only,
          (this.south.east).only.take(diagonal ? 1 : 0));
    }
  }

  /// convenient access of nearby coordinates
  unittest {
    import std.algorithm : equal;

    assert(RowCol(1,1).north == RowCol(0,1));
    assert(RowCol(1,1).south == RowCol(2,1));
    assert(RowCol(1,1).east  == RowCol(1,2));
    assert(RowCol(1,1).west  == RowCol(1,0));

    assert(RowCol(1,1).south(5)         == RowCol(6,1));
    assert(RowCol(1,1).south(2).east(5) == RowCol(3,6));

    assert(RowCol(1,1).adjacent.equal([
      RowCol(0,1),
      RowCol(1,0),
      RowCol(1,2),
      RowCol(2,1)
    ]));

    assert(RowCol(1,1).adjacent(Diagonals.yes).equal([
      RowCol(0,0),
      RowCol(0,1),
      RowCol(0,2),
      RowCol(1,0),
      RowCol(1,2),
      RowCol(2,0),
      RowCol(2,1),
      RowCol(2,2)
    ]));
  }

  /// Add or subtract one coordinate from another
  @nogc
  RowCol opBinary(string op)(RowCol rhs) const if (op == "+" || op == "-") {
    return mixin(q{RowCol(this.row %s rhs.row, this.col %s rhs.col)}.format(op, op));
  }

  unittest {
    assert(RowCol(1, 2) + RowCol(4, 1) == RowCol(5, 3));
    assert(RowCol(4, 2) - RowCol(6, 1) == RowCol(-2, 1));
  }
}

/**
 * Enumerate all row/col pairs spanning the rectangle bounded by the corners start and end.
 *
 * The order of enumeration is determined as follows:
 * Enumerate all columns in a row before moving to the next row.
 * If start.row >= end.row, enumerate rows in increasing order, otherwise enumerate in decreasing.
 * If start.col >= end.col, enumerate cols in increasing order, otherwise enumerate in decreasing.
 *
 * Params:
 *  start = RowCol pair to start enumeration from, $(B inclusive)
 *  end   = RowCol pair to end enumeration at, $(B exclusive)
 */
auto span(RowCol start, RowCol end) {
  auto colInc = sgn(end.col - start.col); // direction to increment columns (1 or -1)
  auto rowInc = sgn(end.row - start.row); // direction to increment rows (1 or -1)

  // default increment to 1 in case there is no difference between coords
  colInc = (colInc == 0) ? 1 : colInc;
  rowInc = (rowInc == 0) ? 1 : rowInc;

  // add/subtract 1 because we want an inclusive range, while iota is exclusive on the upper bound
  auto colRange = iota(start.col, end.col, colInc);
  auto rowRange = iota(start.row, end.row, rowInc);

  return rowRange.cartesianProduct(colRange).map!(x => RowCol(x[0], x[1]));
}

///
unittest {
  import std.algorithm : equal;

  assert(RowCol(0,0).span(RowCol(2,3)).equal([
    RowCol(0,0), RowCol(0,1), RowCol(0,2),
    RowCol(1,0), RowCol(1,1), RowCol(1,2)]));

  assert(RowCol(2,2).span(RowCol(0,0)).equal([
    RowCol(2,2), RowCol(2,1),
    RowCol(1,2), RowCol(1,1)]));

  assert(RowCol(2,2).span(RowCol(1,3)).equal([RowCol(2,2)]));

  assert(RowCol(2,2).span(RowCol(3,1)).equal([RowCol(2,2)]));

  // as the upper bound of span is exclusive, both of these are empty (span over 0 columns):
  assert(RowCol(2,2).span(RowCol(2,2)).empty);
  assert(RowCol(2,2).span(RowCol(5,2)).empty);
}

/// ditto
auto span(RowCol start, coord_t endRow, coord_t endCol) {
  return span(start, RowCol(endRow, endCol));
}

unittest {
  import std.algorithm : equal;

  assert(RowCol(0,0).span(2,3).equal([
    RowCol(0,0), RowCol(0,1), RowCol(0,2),
    RowCol(1,0), RowCol(1,1), RowCol(1,2)]));
}

/// Represents a location in continuous 2D space.
alias PixelCoord = Tuple!(float, "x", float, "y");

/// True if T is a type that can represent a location in terms of pixels.
enum isPixelCoord(T) = is(typeof(T.x) : real) &&
                       is(typeof(T.y) : real) &&
                       is(T == struct); // must be a struct/tuple

///
unittest {
  // PixelCoord is dtiled's vector representation within pixel coordinate space.
  static assert(isPixelCoord!PixelCoord);

  // as a user, you may choose any (x,y) numeric pair to use as a pixel coordinate
  struct MyVector(T) { T x, y; }

  static assert(isPixelCoord!(MyVector!int));
  static assert(isPixelCoord!(MyVector!uint));
  static assert(isPixelCoord!(MyVector!float));
  static assert(isPixelCoord!(MyVector!double));
  static assert(isPixelCoord!(MyVector!real));

  // To avoid confusion, grid coordinates are distinct from pixel coordinates
  static assert(!isPixelCoord!RowCol);
}

/// Convert a PixelCoord to a user-defined (x,y) numeric pair.
T as(T)(PixelCoord pos) if (isPixelCoord!T) {
  T t;
  t.x = pos.x.to!(typeof(t.x));
  t.y = pos.y.to!(typeof(t.y));
  return t;
}

/// Convert dtiled's pixel-space coordinates to your own types:
unittest {
  // your own representation may be a struct
  struct MyVector(T) { T x, y; }

  assert(PixelCoord(5, 10).as!(MyVector!double) == MyVector!double(5, 10));
  assert(PixelCoord(5.5, 10.2).as!(MyVector!int) == MyVector!int(5, 10));

  // or it may be a tuple
  alias MyPoint(T) = Tuple!(T, "x", T, "y");

  assert(PixelCoord(5, 10).as!(MyPoint!double) == MyPoint!double(5, 10));
  assert(PixelCoord(5.5, 10.2).as!(MyPoint!int) == MyPoint!int(5, 10));

  // std.conv.to is used internally, so it should detect overflow
  import std.conv : ConvOverflowException;
  import std.exception : assertThrown;
  assertThrown!ConvOverflowException(PixelCoord(-1, -1).as!(MyVector!ulong));
}

/**
 * Return the manhattan distance between two tile coordinates.
 * For two coordinates a and b, this is defined as abs(a.row - b.row) + abs(a.col - b.col)
 */
@nogc
auto manhattan(RowCol a, RowCol b) {
  return abs(a.row - b.row) + abs(a.col - b.col);
}

unittest {
  assert(manhattan(RowCol(0,0), RowCol(2,2))     == 4);
  assert(manhattan(RowCol(2,2), RowCol(2,2))     == 0);
  assert(manhattan(RowCol(-2,-2), RowCol(-2,-2)) == 0);
  assert(manhattan(RowCol(4,-2), RowCol(2,2))    == 6);
  assert(manhattan(RowCol(4,-2), RowCol(-2,-2))  == 6);
}
