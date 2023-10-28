const std = @import("std");
const math = std.math;
const Self = @This();

const Vec = @import("Vec.zig");

position: Vec = Vec.zero(),
velocity: Vec = Vec.zero(),
life: f32 = 0,

pub fn new(x: f32, y: f32, angle: f32, speed: f32, life: f32) Self {
    return .{
        .position = Vec.new(x, y),
        .velocity = velocity(angle, speed),
        .life = life,
    };
}

pub fn velocity(angle: f32, speed: f32) Vec {
    const angleInRadians = angle * math.pi / 180;

    return Vec.new(
        speed * math.cos(angleInRadians),
        speed * math.sin(angleInRadians),
    );
}

pub fn newpos(self: Self, dt: f32) Vec {
    return self.position.add(self.velocity.scale(dt));
}

pub fn update(self: Self, dt: f32) Self {
    return .{
        .position = self.newpos(dt),
        .velocity = self.velocity,
        .life = self.life - (dt / 10),
    };
}

pub fn add(self: Self, v: Vec) Self {
    return .{
        .position = self.position.add(v),
        .velocity = self.velocity,
        .life = self.life,
    };
}

pub fn X(self: Self) i32 {
    return @intFromFloat(self.position.x());
}

pub fn Y(self: Self) i32 {
    return @intFromFloat(self.position.y());
}
