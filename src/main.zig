const std = @import("std");
const fmt = std.fmt;

// 640 ought to be enough for anybody.
var memory: [640]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&memory);
const allocator = fba.allocator();

// 2D Vector implementation
const Vec = @import("Vec.zig");
const V = Vec.new;

// Particle implementation
const Particle = @import("Particle.zig");
const P = Particle.new;

// WASM-4
const w4 = @import("wasm4.zig");

// Global state
var s = State{};

const State = struct {
    si: u2 = 0, // Scene index
    x: i32 = 0, // Mouse X
    y: i32 = 0, // Mouse Y
    lf: u8 = 0, // Pressed last frame
    tf: u8 = 0, // Pressed this frame

    life: i8 = 3, // Life
    score: u8 = 0, // Some sort of game score
    frame: u32 = 0,

    // The input device (gamepad or mouse)
    input: *const u8 = w4.MOUSE_BUTTONS,
    m: Vec = Vec.zero(),

    // Linear congruential generator...
    // for some cheap pseudo randomness
    lcg: LCG = .{
        .a = 1103515245,
        .c = 12345,
        .m = 1 << 31,
        .seed = 478194673,
    },

    // Tangerine Noir
    // https://lospec.com/palette-list/tangerine-noir
    palette: [4]u32 = .{
        0xfcfcfc, // White
        0x393541, // Gray
        0x191a1f, // Black
        0xee964b, // Tangerine
    },

    scenes: [3]Scene = .{
        .{ .intro = Intro{} },
        .{ .game = Game{} },
        .{ .over = Over{} },
    },

    fn start(_: *State) void {
        trace(
            \\ ______ _______ _______ _______ _______ _______ ___ ___ _____  _______
            \\|   __ |_     _|    |  |     __|       |     __|   |   |     ||_     _|
            \\|   __ <_|   |_|       |    |  |   -   |__     |\     /|       ||   |
            \\|______|_______|__|____|_______|_______|_______| |___| |_______||___|
            \\
        );

        w4.PALETTE.* = s.palette;

        var si: u2 = undefined;

        _ = w4.diskr(@ptrCast(&si), @sizeOf(@TypeOf(si)));

        // Transition to the scene loaded
        s.transition(si);
    }

    fn update(self: *State) !void {
        // Update mouse press on this and last frame
        self.tf = self.input.* & (self.input.* ^ self.lf);
        self.lf = self.input.*;

        // Update mouse position
        self.x = @intCast(w4.MOUSE_X.*);
        self.y = @intCast(w4.MOUSE_Y.*);

        self.m = V(@floatFromInt(self.x), @floatFromInt(self.y));

        // Increment the frame counter
        self.frame +%= 1;

        // Update the scene specific state
        try self.scenes[self.si].update();
    }

    fn draw(self: *State) !void {
        // Draw the scene
        try self.scenes[s.si].draw();
    }

    fn btn(self: *State) bool {
        return self.tf & w4.MOUSE_RIGHT != 0;
    }

    fn transition(self: *State, sceneIndex: u2) void {
        w4.tracef("-== TRANSITION TO SCENE: [%d] ==-", @as(u8, sceneIndex));

        _ = try self.scenes[sceneIndex].enter();

        self.si = sceneIndex;
        self.save();
    }

    fn save(self: *State) void {
        // Save the scene index to disk
        _ = w4.diskw(@ptrCast(&self.si), @sizeOf(@TypeOf(self.si)));
    }
};

const Scene = union(enum) {
    intro: Intro,
    game: Game,
    over: Over,

    fn enter(self: *Scene) !void {
        switch (self.*) {
            inline else => |*scene| try scene.enter(),
        }
    }

    fn update(self: *Scene) !void {
        switch (self.*) {
            inline else => |*scene| try scene.update(),
        }
    }

    fn draw(self: *Scene) !void {
        switch (self.*) {
            inline else => |*scene| try scene.draw(),
        }
    }
};

const Intro = struct {
    fn enter(_: *Intro) !void {}

    fn update(_: *Intro) !void {
        if (s.btn()) {
            s.transition(GAME);
        }
    }

    fn draw(i: *Intro) !void {
        clear(BLACK);
        i.bottom();

        color(GRAY);
        line(0, 0, s.x, s.y);
        line(0, 159, s.x, s.y);
        line(159, 0, s.x, s.y);
        line(159, 159, s.x, s.y);

        var center = V(80, 80);

        var d: i32 = @intFromFloat(s.m.distance(center));

        i.target(d);

        title("INTRO", 8, 6, GRAY, TANGERINE);

        // Gray cat
        color(0x4002);
        image(cat, 117, 21, cat.flags | w4.BLIT_FLIP_X);

        // White cat
        color(0x4001);

        var w: f32 = @floatFromInt(cat.width);
        var h: f32 = @floatFromInt(cat.height);

        var l = s.m.lerp(center, 0.8).sub(V(@divFloor(w, 4), @divFloor(h, 2)));

        img(cat, l, cat.flags);

        dotline(s.m, center, ([_]f32{
            0.1,
            0.2,
            0.3,
            0.4,
            0.5,
            0.6,
            0.7,
        })[0..], 3, TANGERINE);

        try i.debug(.{ s.frame, s.x, s.y, d });
    }

    fn debug(_: *Intro, args: anytype) !void {
        const str = try fmt.allocPrint(allocator,
            \\FRAME: {d}
            \\MOUSE: [{d}][{d}]
            \\DEBUG: {any}
        , args);
        defer allocator.free(str);

        trace(str);
        title(str, 20, 20, GRAY, WHITE);
    }

    fn target(_: *Intro, d: i32) void {
        color(0x13);

        var w: i32 = @intCast(70 - d);
        var h: i32 = @intCast(65 - d);

        if (d < 65) {
            oval(s.x - @divFloor(w, 2), s.y - @divFloor(h, 2), @intCast(w), @intCast(h));
        }
    }

    fn bottom(_: *Intro) void {
        color(0x4332);

        image(death, -30, 99, death.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_X);
        image(death, 0, 99, death.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_X);
        image(death, 30, 99, death.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_X);
        image(death, 60, 99, death.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_X);
        image(death, 90, 99, death.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_X);
        image(death, 120, 99, death.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_X);
    }
};

const Game = struct {
    startup: Tone = Tone{
        .freq1 = 240,
        .freq2 = 680,
        .attack = 0,
        .decay = 35,
        .sustain = 51,
        .release = 117,
        .peak = 26,
        .volume = 6,
        .mode = 0,
    },

    died: Tone = Tone{
        .freq1 = 90,
        .freq2 = 40,
        .attack = 10,
        .decay = 0,
        .sustain = 15,
        .release = 25,
        .peak = 0,
        .volume = 90,
        .mode = 1,
    },

    fn enter(g: *Game) !void {
        s.life = 3;

        g.startup.play(0);
        g.startup.play(1);
        g.startup.play(2);
    }

    fn update(g: *Game) !void {
        if (s.btn()) {
            s.life -= 1;
            s.score += 1;

            w4.tracef("life %d score %d", s.life, s.score);
        }

        if (s.life == 0) {
            g.died.play(2);
            s.transition(OVER);
        }
    }

    fn draw(_: *Game) !void {
        clear(BLACK);

        color(0x31);
        text("GAME", 8, 6);

        var i: i32 = 0;

        while (i <= s.life) : (i += 1) {
            color(0x31);
            rect(10, 30 - i, 10, 10);
        }
    }
};

const Over = struct {
    deathFlipped: bool = false,
    pressFlipped: bool = false,

    snowParticles: [256]Particle = [_]Particle{.{}} ** 256,
    //snowParticles: [1]Particle = [_]Particle{.{}} ** 1,
    sound: Tone = Tone{
        .freq1 = 50,
        .freq2 = 40,
        .attack = 25,
        .decay = 168,
        .sustain = 0,
        .release = 25,
        .peak = 0,
        .volume = 2,
        .mode = 3,
    },

    fn enter(o: *Over) !void {
        // Random positions for the snow particles
        for (0.., o.snowParticles) |i, _| {
            o.snowParticles[i] = P(
                @floatFromInt(intn(160)),
                @floatFromInt(intn(160)),
                @floatFromInt(45),
                @floatFromInt(5 + intn(15)),
                10,
            );
        }
    }

    fn update(o: *Over) !void {
        if (s.btn()) {
            s.transition(INTRO);
        }

        o.updateSnow();

        if (every(120)) o.deathFlipped = !o.deathFlipped;
        if (every(30)) o.pressFlipped = !o.pressFlipped;
        if (every(400)) o.sound.play(2);
    }

    fn draw(o: *Over) !void {
        clear(GRAY);

        var flags = death.flags;

        if (o.deathFlipped) {
            flags |= w4.BLIT_FLIP_X;
        }

        color(0x4321);
        image(death, 40, 15, flags);

        color(0x4321);
        image(coffee, 68, 150, coffee.flags);

        o.snow();

        title("The game is over!!", 8, 3, TANGERINE, WHITE);

        const fg: u16 = if (o.pressFlipped) TANGERINE else WHITE;

        title("Press key to restart", 0, 143, BLACK, fg);
    }

    fn snow(o: *Over) void {
        for (0.., o.snowParticles) |i, p| {
            if (@mod(i, 5) == 0) {
                color(GRAY);
                ppx(p.add(V(1, 1)));

                color(WHITE);
                ppx(p.add(V(1, -1)));
                if (@mod(i, 4) == 0) {
                    ppx(p.add(V(-1, -1)));
                    ppx(p.add(V(-1, 1)));

                    if (@mod(i, 3) == 0) {
                        ppx(p.add(V(1, 1)));
                    }
                }
            }

            ppx(p);

            color(WHITE);
            vpx(p.newpos(-0.1));
            vpx(p.newpos(-0.15));

            color(GRAY);
            vpx(p.newpos(-0.2));
        }
    }

    fn updateSnow(o: *Over) void {
        for (0.., o.snowParticles) |i, p| {
            var n = p.update(0.1);

            n.position.data[0] = @mod(n.position.data[0], 165);
            n.position.data[1] = @mod(n.position.data[1], 165);

            if (n.life < 0) {
                n.life = @floatFromInt(intn(10));
            }

            o.snowParticles[i] = n;
        }
    }
};

fn every(f: u32) bool {
    return @mod(s.frame, f) == 0;
}

// Tone that can play itself
const Tone = struct {
    freq1: u32 = 0,
    freq2: u32 = 0,
    attack: u32 = 0,
    decay: u32 = 0,
    sustain: u32 = 0,
    release: u32 = 0,
    peak: u32 = 0,
    volume: u32 = 0,
    mode: u32 = 0,
    pan: u32 = 0,

    fn play(t: Tone, channel: u32) void {
        const frequency = t.freq1 | (t.freq2 << 16);
        const duration = (t.attack << 24) | (t.decay << 16) | t.sustain | (t.release << 8);
        const volume = (t.peak << 8) | t.volume;
        const flags = channel | (t.mode << 2) | (t.pan << 4);

        w4.tone(
            frequency,
            duration,
            volume,
            flags,
        );
    }
};

// The colors
const WHITE: u16 = 1;
const GRAY: u16 = 2;
const BLACK: u16 = 3;
const TANGERINE: u16 = 4;

// The scene indexes
const INTRO: u2 = 0;
const GAME: u2 = 1;
const OVER: u2 = 2;

// Proxy functions for w4
fn text(str: []const u8, x: i32, y: i32) void {
    w4.text(str, x, y);
}

fn title(str: []const u8, x: i32, y: i32, bg: u16, fg: u16) void {
    color(bg);
    text(str, x, y);
    color(fg);
    text(str, x + 1, y + 1);
}

fn line(x1: i32, y1: i32, x2: i32, y2: i32) void {
    w4.line(x1, y1, x2, y2);
}

fn hline(x: i32, y: i32, len: u32) void {
    w4.hline(x, y, len);
}

fn vline(x: i32, y: i32, len: u32) void {
    w4.vline(x, y, len);
}

fn oval(x: i32, y: i32, width: u32, height: u32) void {
    w4.oval(x, y, width, height);
}

fn rect(x: i32, y: i32, width: u32, height: u32) void {
    w4.rect(x, y, width, height);
}

fn blit(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, flags: u32) void {
    w4.blit(sprite, x, y, width, height, flags);
}

fn image(m: Sprite, x: i32, y: i32, flags: u32) void {
    w4.blit(m.sprite, x, y, m.width, m.height, flags);
}

fn img(m: Sprite, v: Vec, flags: u32) void {
    w4.blit(m.sprite, v.X(), v.Y(), m.width, m.height, flags);
}

fn color(c: u16) void {
    w4.DRAW_COLORS.* = c;
}

fn clear(c: u8) void {
    for (w4.FRAMEBUFFER) |*x| {
        x.* = c - 1 | (c - 1 << 2) | (c - 1 << 4) | (c - 1 << 6);
    }
}

fn vpx(v: Vec) void {
    pixel(v.X(), v.Y());
}

fn ppx(p: Particle) void {
    vpx(p.position);
}

fn pixel(x: i32, y: i32) void {
    if ((x < 0) or (x > 160) or (y < 0) or (y > 160)) {
        return;
    }

    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    const idx: usize = (uy * 160 + ux) >> 2;
    const sx: u3 = @intCast(x);
    const shift = (sx & 0b11) * 2;
    const mask = @as(u8, 0b11) << shift;
    const palette_color: u8 = @intCast(w4.DRAW_COLORS.* & 0b1111);

    if (palette_color == 0) {
        return;
    }

    const c = (palette_color - 1) & 0b11;

    w4.FRAMEBUFFER[idx] = (c << shift) | (w4.FRAMEBUFFER[idx] & ~mask);
}

fn dotline(a: Vec, b: Vec, points: []const f32, dotSize: u32, dotColor: u16) void {
    for (points) |p| {
        const pos = a.lerp(b, p);

        color(dotColor);
        oval(pos.X(), pos.Y(), dotSize, dotSize);
    }
}

fn trace(x: []const u8) void {
    w4.trace(x);
}

fn intn(n: u32) i32 {
    return @intCast(s.lcg.intn(n));
}

//
// Exported functions for the WASM-4 game loop
//

export fn start() void {
    s.start();
}

export fn update() void {
    // Update the state
    s.update() catch unreachable;

    // Draw the state
    s.draw() catch unreachable;
}

const LCG = struct {
    a: u32,
    c: u32,
    m: u32,
    seed: u32,
    r: u32 = 0,

    fn next(lcg: *LCG) u32 {
        lcg.r = (lcg.a * lcg.r + lcg.c) % lcg.m;

        return lcg.r;
    }

    fn intn(lcg: *LCG, n: u32) u32 {
        return lcg.next() % n;
    }
};

const Sprite = struct {
    sprite: [*]const u8,
    width: u32,
    height: u32,
    flags: u32 = w4.BLIT_2BPP,
};

pub const death = Sprite{
    .sprite = ([2856]u8{ 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x80, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x56, 0xaa, 0xa0, 0x00, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x5a, 0xaa, 0x00, 0x2a, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x6a, 0xa8, 0x02, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0x80, 0x00, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0x95, 0x55, 0x55, 0x55, 0x56, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x6a, 0xa8, 0x00, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0xaa, 0x80, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0xaa, 0x80, 0xaa, 0xaa, 0x95, 0x55, 0x56, 0xaa, 0x0a, 0xa5, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x5a, 0xa8, 0xaa, 0xaa, 0x95, 0x55, 0x56, 0xa8, 0x2a, 0x95, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0x55, 0x55, 0x5a, 0xa0, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0x55, 0x55, 0x6a, 0x8a, 0xa5, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x5e, 0xaa, 0xaa, 0x55, 0x55, 0x6a, 0x2a, 0x95, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0xa8, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0xa2, 0xa5, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x56, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x56, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x5a, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x5a, 0xa5, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x70, 0x35, 0x55, 0x55, 0x6a, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x70, 0x35, 0x55, 0x55, 0x65, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xa8, 0x00, 0x0a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0xa9, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa9, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0x70, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x0a, 0xaa, 0xaa, 0x00, 0x02, 0xaa, 0xaa, 0xa0, 0x02, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x02, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x02, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa5, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa5, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x0a, 0xaa, 0xaa, 0x00, 0x02, 0xaa, 0xaa, 0xa0, 0x0a, 0xaa, 0xa7, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x02, 0xaa, 0xa8, 0x00, 0x00, 0xaa, 0xaa, 0x80, 0x2a, 0xaa, 0xa7, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x00, 0xaa, 0xa0, 0x02, 0x00, 0x2a, 0xaa, 0x00, 0xaa, 0xaa, 0xa7, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x80, 0x2a, 0x80, 0x0a, 0x80, 0x0a, 0xa8, 0x02, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa0, 0x00, 0x00, 0x28, 0xa0, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa8, 0x00, 0x00, 0x20, 0x20, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa9, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xa5, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa8, 0x02, 0x00, 0x80, 0x20, 0x0a, 0xaa, 0xaa, 0xa5, 0x57, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0x0a, 0x00, 0x80, 0x28, 0x2a, 0xaa, 0xaa, 0x95, 0x57, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x82, 0xa0, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0xa8, 0x2a, 0x0a, 0xaa, 0xaa, 0xaa, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x20, 0x08, 0x02, 0xaa, 0xaa, 0xa9, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa5, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0x95, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x5c, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x5c, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x5c, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x6a, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa2, 0x80, 0x09, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x02, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x09, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x02, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x00, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa2, 0x80, 0x02, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x2a, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x00, 0x09, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x25, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xea, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x9b, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x39, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x0a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55 })[0..],
    .width = 84,
    .height = 136,
};

pub const cat = Sprite{
    .sprite = ([27]u8{ 0x51, 0x45, 0x55, 0x40, 0x05, 0x55, 0x11, 0x05, 0x51, 0x0c, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x44, 0x54, 0x45 })[0..],
    .width = 12,
    .height = 9,
};

pub const coffee = Sprite{
    .sprite = ([40]u8{ 0x55, 0x54, 0x15, 0x55, 0x55, 0x54, 0x45, 0x55, 0x55, 0x40, 0x01, 0x55, 0x55, 0x14, 0x00, 0x55, 0x55, 0xd4, 0x00, 0x55, 0x55, 0xeb, 0x03, 0x55, 0x5a, 0xaf, 0xfe, 0xa9, 0xaa, 0xaa, 0xaa, 0xa5, 0x5a, 0x6a, 0xaa, 0x55, 0x6a, 0xa9, 0x55, 0x55 })[0..],
    .width = 16,
    .height = 10,
};
