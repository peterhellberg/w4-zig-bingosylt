const w4 = @import("wasm4.zig");

// Global state
var s = State{};

const State = struct {
    si: u2 = 0, // Scene index
    x: i32 = 0, // Mouse X
    y: i32 = 0, // Mouse Y
    lf: u8 = 0, // Pressed last frame
    tf: u8 = 0, // Pressed this frame

    life: i8 = 10, // Life
    score: u8 = 0, // Some sort of game score
    frame: i32 = 0,

    // The input device (gamepad or mouse)
    p: *const u8 = w4.MOUSE_BUTTONS,

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

        w4.tracef("Scene: %d", @as(u8, si));

        s.si = si;

        // Random positions for the snow particles
        for (0.., s.scenes[2].over.snowParticles) |i, _| {
            s.scenes[2].over.snowParticles[i] = Particle{
                .x = intn(160),
                .y = intn(160),
            };
        }
    }

    fn update(self: *State) void {
        // Update what was pressed on the gamepad
        self.tf = self.p.* & (self.p.* ^ self.lf);
        self.lf = self.p.*;

        s.frame += 1;

        // Update the scene specific state
        self.scenes[s.si].update();
    }

    fn draw(self: *State) void {
        // Draw the scene
        self.scenes[s.si].draw();
    }

    fn btn(self: *State) bool {
        return self.tf & w4.MOUSE_LEFT != 0;
    }

    fn scene(self: *State, sceneIndex: u2) void {
        self.si = sceneIndex;
        self.save();
    }

    fn reset(self: *State) void {
        self.life = 10;
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

    fn update(self: *Scene) void {
        switch (self.*) {
            inline else => |*scene| scene.update(),
        }
    }

    fn draw(self: *Scene) void {
        switch (self.*) {
            inline else => |*scene| scene.draw(),
        }
    }
};

const Intro = struct {
    snowParticles: [200]Particle = [_]Particle{.{}} ** 200,

    fn update(_: *Intro) void {
        if (s.btn()) {
            s.reset();
            beep.play(1);
            s.scene(GAME);
        }
    }

    fn draw(_: *Intro) void {
        clear(BLACK);

        title("INTRO", 8, 6, GRAY, TANGERINE);

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
    fn update(_: *Game) void {
        if (s.btn()) {
            s.life -= 1;
            s.score += 1;

            w4.tracef("life %d score %d", s.life, s.score);
        }

        if (s.life == 0) {
            boop.play(2);
            s.scene(OVER);
        }
    }

    fn draw(_: *Game) void {
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

    snowParticles: [200]Particle = [_]Particle{.{}} ** 200,
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

    fn update(self: *Over) void {
        self.handleInput();
        self.updateSnow();

        if (@mod(s.frame, 120) == 0) {
            self.deathFlipped = !self.deathFlipped;
        }

        if (@mod(s.frame, 30) == 0) {
            self.pressFlipped = !self.pressFlipped;
        }

        if (@mod(s.frame, 400) == 0) {
            self.sound.play(2);
        }
    }

    fn handleInput(self: *Over) void {
        if (s.btn()) {
            s.scene(INTRO);
        }

        if (s.tf & w4.MOUSE_LEFT != 0) {
            beep.play(0);
            beep.play(1);
            beep.play(2);
            beep.play(3);
        }

        if (s.tf & w4.MOUSE_MIDDLE != 0) {
            self.sound.play(2);
        }

        if (s.tf & w4.MOUSE_RIGHT != 0) {
            beep.play(0);
            //boop.play(1);
            boop.play(2);
            //boop.play(3);
        }
    }

    fn updateSnow(self: *Over) void {
        for (0.., self.snowParticles) |i, p| {
            self.snowParticles[i] = Particle{
                .x = @mod(p.x + intn(4), 160),
                .y = @mod(p.y + intn(3), 160),
            };
        }
    }

    fn draw(self: *Over) void {
        clear(GRAY);

        color(0x4321);

        var flags = death.flags;

        if (self.deathFlipped) {
            flags |= w4.BLIT_FLIP_X;
        }

        image(death, 40, 15, flags);

        self.snow();

        title("The game is over!!", 8, 3, TANGERINE, WHITE);

        const fg: u16 = if (self.pressFlipped) TANGERINE else WHITE;

        title("press key to restart", 0, 143, BLACK, fg);
    }

    fn snow(self: *Over) void {
        for (0.., self.snowParticles) |i, p| {
            if (@mod(i, 5) == 0) {
                color(GRAY);
                pixel(p.x - 1, p.y - 1);

                color(WHITE);

                pixel(p.x + 1, p.y - 1);
                if (@mod(i, 4) == 0) {
                    pixel(p.x + 1, p.y + 1);
                    pixel(p.x - 1, p.y + 1);
                }
            }

            color(WHITE);
            pixel(p.x, p.y);
        }

        // for (0..20) |i| {
        //     const y: i32 = @intCast(i * 16);
        //     _ = y;

        //     for (0..20) |j| {
        //         const x: i32 = @intCast(j * 16);
        //         _ = x;
        //     }
        // }
    }
};

const Particle = struct {
    x: i32 = 0,
    y: i32 = 0,
};

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

    fn play(self: Tone, channel: u32) void {
        const frequency = self.freq1 | (self.freq2 << 16);
        const duration = (self.attack << 24) | (self.decay << 16) | self.sustain | (self.release << 8);
        const volume = (self.peak << 8) | self.volume;
        const flags = channel | (self.mode << 2) | (self.pan << 4);

        w4.tone(
            frequency,
            duration,
            volume,
            flags,
        );
    }
};

var beep = Tone{
    .freq1 = 240,
    .freq2 = 680,
    .attack = 0,
    .decay = 35,
    .sustain = 51,
    .release = 117,
    .peak = 26,
    .volume = 6,
    .mode = 0,
};

var boop = Tone{
    .freq1 = 90,
    .freq2 = 40,
    .attack = 10,
    .decay = 0,
    .sustain = 15,
    .release = 25,
    .peak = 0,
    .volume = 90,
    .mode = 1,
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

fn color(c: u16) void {
    w4.DRAW_COLORS.* = c;
}

fn clear(c: u8) void {
    for (w4.FRAMEBUFFER) |*x| {
        x.* = c - 1 | (c - 1 << 2) | (c - 1 << 4) | (c - 1 << 6);
    }
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
    s.update();

    // Draw the state
    s.draw();
}

const LCG = struct {
    a: u32,
    c: u32,
    m: u32,
    seed: u32,
    r: u32 = 0,

    fn next(self: *LCG) u32 {
        self.r = (self.a * self.r + self.c) % self.m;

        return self.r;
    }

    fn intn(self: *LCG, n: u32) u32 {
        return self.next() % n;
    }
};

const Sprite = struct {
    sprite: [*]const u8,
    width: u32,
    height: u32,
    flags: u32,
};

pub var death = Sprite{
    .sprite = ([2856]u8{ 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x80, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x56, 0xaa, 0xa0, 0x00, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x5a, 0xaa, 0x00, 0x2a, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x6a, 0xa8, 0x02, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0x80, 0x00, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0x95, 0x55, 0x55, 0x55, 0x56, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x6a, 0xa8, 0x00, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0xaa, 0x80, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0xaa, 0x80, 0xaa, 0xaa, 0x95, 0x55, 0x56, 0xaa, 0x0a, 0xa5, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x5a, 0xa8, 0xaa, 0xaa, 0x95, 0x55, 0x56, 0xa8, 0x2a, 0x95, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0x55, 0x55, 0x5a, 0xa0, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0x55, 0x55, 0x6a, 0x8a, 0xa5, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x5e, 0xaa, 0xaa, 0x55, 0x55, 0x6a, 0x2a, 0x95, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0xa8, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0xa2, 0xa5, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x56, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x56, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x5a, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x5a, 0xa5, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x70, 0x35, 0x55, 0x55, 0x6a, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x70, 0x35, 0x55, 0x55, 0x65, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xa8, 0x00, 0x0a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0xa9, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa9, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0x70, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x0a, 0xaa, 0xaa, 0x00, 0x02, 0xaa, 0xaa, 0xa0, 0x02, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x02, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x02, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa0, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa9, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa5, 0xc0, 0xd5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x2a, 0xaa, 0xaa, 0x80, 0x0a, 0xaa, 0xaa, 0xa8, 0x0a, 0xaa, 0xa5, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x0a, 0xaa, 0xaa, 0x00, 0x02, 0xaa, 0xaa, 0xa0, 0x0a, 0xaa, 0xa7, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xa8, 0x02, 0xaa, 0xa8, 0x00, 0x00, 0xaa, 0xaa, 0x80, 0x2a, 0xaa, 0xa7, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x00, 0xaa, 0xa0, 0x02, 0x00, 0x2a, 0xaa, 0x00, 0xaa, 0xaa, 0xa7, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0x80, 0x2a, 0x80, 0x0a, 0x80, 0x0a, 0xa8, 0x02, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa0, 0x00, 0x00, 0x28, 0xa0, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xa8, 0x00, 0x00, 0x20, 0x20, 0x00, 0x00, 0x2a, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xaa, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa9, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0xa5, 0x57, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xa8, 0x02, 0x00, 0x80, 0x20, 0x0a, 0xaa, 0xaa, 0xa5, 0x57, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0x0a, 0x00, 0x80, 0x28, 0x2a, 0xaa, 0xaa, 0x95, 0x57, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x82, 0xa0, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0xa8, 0x2a, 0x0a, 0xaa, 0xaa, 0xaa, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x20, 0x08, 0x02, 0xaa, 0xaa, 0xa9, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0xa5, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x00, 0x00, 0x02, 0xaa, 0xaa, 0x95, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x00, 0x00, 0x0a, 0xaa, 0xaa, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x5c, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x5c, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x5c, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x5c, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa5, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x70, 0x35, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x6a, 0xa5, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa2, 0x80, 0x09, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x02, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x09, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x02, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x80, 0x00, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa2, 0x80, 0x02, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x2a, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x00, 0x09, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x80, 0x25, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xea, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xc3, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xab, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x9b, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x03, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x97, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xac, 0x0d, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x39, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x3a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa0, 0x0a, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x6a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x95, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x5a, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xa9, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55 })[0..],
    .width = 84,
    .height = 136,
    .flags = w4.BLIT_2BPP,
};
