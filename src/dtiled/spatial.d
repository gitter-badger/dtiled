/**
 * This module models various representations of space in a map.
 *
 * When dealing with a grid, do you ever forget whether the row or column is the first index?
 * Me too.
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
module dtiled.spatial;

import std.conv     : to;
import std.typecons : Tuple;


/// Represents a discrete location within the map grid.
alias RowCol = Tuple!(long, "row", long, "col");

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
