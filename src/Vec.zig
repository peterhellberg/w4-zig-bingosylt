const std = @import("std");
const math = std.math;
const Self = @This();

const Vec = @Vector(2, f32);

data: Vec,

/// Construct new vector.
pub fn new(vx: f32, vy: f32) Self {
    return .{ .data = [2]f32{ vx, vy } };
}

/// Construct new triangle.
pub fn tri(x1: f32, y1: f32, x2: f32, y2: f32, x3: f32, y3: f32) [3]Self {
    return .{ Self.new(x1, y1), Self.new(x2, y2), Self.new(x3, y3) };
}

pub fn x(self: Self) f32 {
    return self.data[0];
}

pub fn y(self: Self) f32 {
    return self.data[1];
}

pub fn xi(self: Self) i32 {
    return @intFromFloat(self.data[0]);
}

pub fn yi(self: Self) i32 {
    return @intFromFloat(self.data[1]);
}

pub fn xu(self: Self) u16 {
    return @intFromFloat(self.data[0]);
}

pub fn yu(self: Self) u16 {
    return @intFromFloat(self.data[1]);
}

/// Set all components to the same given value.
pub fn set(val: f32) Self {
    const result = @as(Vec, @splat(val));
    return .{ .data = result };
}

/// Shorthand for (80..)
pub fn center() Self {
    return set(80);
}

/// Shorthand for (0..).
pub fn zero() Self {
    return set(0);
}

/// Shorthand for (1..).
pub fn one() Self {
    return set(1);
}

/// Shorthand for (0, -1).
pub fn up() Self {
    return Self.new(0, -1);
}

/// Shorthand for (0, 1).
pub fn down() Self {
    return Self.new(0, 1);
}

/// Shorthand for (1, 0).
pub fn right() Self {
    return Self.new(1, 0);
}

/// Shorthand for (-1, 0).
pub fn left() Self {
    return Self.new(-1, 0);
}

/// Negate the given vector.
pub fn negate(self: Self) Self {
    return self.scale(-1);
}

/// Construct new vector from slice.
pub fn fromSlice(slice: []const f32) Self {
    const result = slice[0..2].*;
    return .{ .data = result };
}

/// Transform vector to array.
pub fn toArray(self: Self) [2]f32 {
    return self.data;
}

/// Return the angle (in degrees) between two vectors.
pub fn getAngle(first_vector: Self, second_vector: Self) f32 {
    const dot_product = dot(norm(first_vector), norm(second_vector));
    return radianToDegree(math.acos(dot_product));
}

/// Convert radian to degree
pub inline fn radianToDegree(r: f32) f32 {
    return r * 180.0 / math.pi;
}

/// Return the length (magnitude) of given vector.
/// √[x^2 + y^2 + z^2 ...]
pub fn length(self: Self) f32 {
    return @sqrt(self.dot(self));
}

/// Return the distance between two points.
/// √[(x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2 ...]
pub fn distance(first_vector: Self, second_vector: Self) f32 {
    return length(first_vector.sub(second_vector));
}

/// Construct new normalized vector from a given one.
pub fn norm(self: Self) Self {
    const l = self.length();
    if (l == 0) {
        return self;
    }
    const result = self.data / @as(Vec, @splat(l));
    return .{ .data = result };
}

/// Return true if two vectors are equals.
pub fn eql(first_vector: Self, second_vector: Self) bool {
    return @reduce(.And, first_vector.data == second_vector.data);
}

/// Substraction between two given vector.
pub fn sub(first_vector: Self, second_vector: Self) Self {
    const result = first_vector.data - second_vector.data;
    return .{ .data = result };
}

/// Addition betwen two given vector.
pub fn add(first_vector: Self, second_vector: Self) Self {
    const result = first_vector.data + second_vector.data;
    return .{ .data = result };
}

/// Component wise multiplication betwen two given vector.
pub fn mul(first_vector: Self, second_vector: Self) Self {
    const result = first_vector.data * second_vector.data;
    return .{ .data = result };
}

/// Construct vector from the max components in two vectors
pub fn max(first_vector: Self, second_vector: Self) Self {
    const result = @max(first_vector.data, second_vector.data);
    return .{ .data = result };
}

/// Construct vector from the min components in two vectors
pub fn min(first_vector: Self, second_vector: Self) Self {
    const result = @min(first_vector.data, second_vector.data);
    return .{ .data = result };
}

/// Construct new vector after multiplying each components by a given scalar
pub fn scale(self: Self, scalar: f32) Self {
    const result = self.data * @as(Vec, @splat(scalar));
    return .{ .data = result };
}

/// Return the dot product between two given vector.
/// (x1 * x2) + (y1 * y2) + (z1 * z2) ...
pub fn dot(first_vector: Self, second_vector: Self) f32 {
    return @reduce(.Add, first_vector.data * second_vector.data);
}

// Return the cross product between three given vector.
pub fn cross(p: Self, a: Self, b: Self) f32 {
    const ab: Self = .{ .data = .{ b.x() - a.x(), b.y() - a.y() } };
    const ap: Self = .{ .data = .{ p.x() - a.x(), p.y() - a.y() } };

    return ab.x() * ap.y() - ab.y() * ap.x();
}

/// Linear interpolation between two vectors
pub fn lerp(first_vector: Self, second_vector: Self, t: f32) Self {
    const from = first_vector.data;
    const to = second_vector.data;

    const result = from + (to - from) * @as(Vec, @splat(t));
    return .{ .data = result };
}

pub fn offset(first_vector: Self, vx: f32, vy: f32) Self {
    return first_vector.add(new(vx, vy));
}
