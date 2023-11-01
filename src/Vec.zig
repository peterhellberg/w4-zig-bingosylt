const std = @import("std");

const w4 = @import("wasm4.zig");

const Self = @This();

const Vec = @Vector(2, f32);

data: Vec,

pub fn new(vx: f32, vy: f32) Self {
    return .{ .data = [2]f32{ vx, vy } };
}

pub fn inew(vx: anytype, vy: anytype) Self {
    return .{ .data = [2]f32{ @floatFromInt(vx), @floatFromInt(vy) } };
}

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
pub fn getAngle(self: Self, other: Self) f32 {
    const dot_product = dot(norm(self), norm(other));
    return radianToDegree(std.math.acos(dot_product));
}

/// Convert radian to degree
pub inline fn radianToDegree(r: f32) f32 {
    return r * 180.0 / std.math.pi;
}

/// Return the length (magnitude) of given vector.
/// √[x^2 + y^2 + z^2 ...]
pub fn length(self: Self) f32 {
    return @sqrt(self.dot(self));
}

/// Return the distance between two points.
/// √[(x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2 ...]
pub fn distance(self: Self, other: Self) f32 {
    return length(self.sub(other));
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
pub fn eql(self: Self, other: Self) bool {
    return @reduce(.And, self.data == other.data);
}

/// Substraction between two given vector.
pub fn sub(self: Self, other: Self) Self {
    const result = self.data - other.data;
    return .{ .data = result };
}

/// Addition betwen two given vector.
pub fn add(self: Self, other: Self) Self {
    const result = self.data + other.data;
    return .{ .data = result };
}

/// Component wise multiplication betwen two given vector.
pub fn mul(self: Self, other: Self) Self {
    const result = self.data * other.data;
    return .{ .data = result };
}

/// Construct vector from the max components in two vectors
pub fn max(self: Self, other: Self) Self {
    const result = @max(self.data, other.data);
    return .{ .data = result };
}

/// Construct vector from the min components in two vectors
pub fn min(self: Self, other: Self) Self {
    const result = @min(self.data, other.data);
    return .{ .data = result };
}

/// Construct new vector after multiplying each components by a given scalar
pub fn scale(self: Self, scalar: f32) Self {
    const result = self.data * @as(Vec, @splat(scalar));
    return .{ .data = result };
}

/// Return the dot product between two given vector.
/// (x1 * x2) + (y1 * y2) + (z1 * z2) ...
pub fn dot(self: Self, other: Self) f32 {
    return @reduce(.Add, self.data * other.data);
}

// Return the cross product between three given vector.
pub fn cross(a: Self, b: Self, c: Self) f32 {
    const ab: Self = .{ .data = .{ b.x() - a.x(), b.y() - a.y() } };
    const ac: Self = .{ .data = .{ c.x() - a.x(), c.y() - a.y() } };

    return ab.x() * ac.y() - ab.y() * ac.x();
}

/// Linear interpolation between two vectors
pub fn lerp(self: Self, other: Self, t: f32) Self {
    const from = self.data;
    const to = other.data;

    const result = from + (to - from) * @as(Vec, @splat(t));
    return .{ .data = result };
}

pub fn offset(self: Self, vx: f32, vy: f32) Self {
    return self.add(new(vx, vy));
}

pub fn line(self: Self, other: Self) void {
    w4.line(self.xi(), self.yi(), other.xi(), other.yi());
}

pub fn oval(self: Self, width: u32, height: u32) void {
    w4.oval(self.xi(), self.yi(), width, height);
}

pub fn rect(self: Self, width: u32, height: u32) void {
    w4.rect(self.xi(), self.yi(), width, height);
}

pub fn text(self: Self, str: []const u8) void {
    w4.text(str, self.xi(), self.yi());
}
