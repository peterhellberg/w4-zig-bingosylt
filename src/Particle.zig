const std = @import("std");

const Vec = @import("Vec.zig");

const Self = @This();

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
    const angleInRadians = angle * std.math.pi / 180;

    return Vec.new(
        speed * std.math.cos(angleInRadians),
        speed * std.math.sin(angleInRadians),
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
