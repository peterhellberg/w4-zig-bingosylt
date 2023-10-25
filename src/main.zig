const w4 = @import("wasm4.zig");

// Global state
var s = State{};

const State = struct {
    si: u2 = 0, // Scene index
    x: i32 = 0, // Mouse X
    y: i32 = 0, // Mouse Y
    lf: u8 = 0, // Pressed last frame
    tf: u8 = 0, // Pressed this frame

    life: i8 = 5, // Life
    score: u8 = 0, // Some sort of game score

    // The input device (gamepad or mouse)
    p: *const u8 = w4.MOUSE_BUTTONS,

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
    }

    fn update(self: *State) void {
        // Update what was pressed on the gamepad
        self.tf = self.p.* & (self.p.* ^ self.lf);
        self.lf = self.p.*;

        // Update the scene specific state
        self.scenes[s.si].update();
    }

    fn draw(self: *State) void {
        clear(2);

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
        self.life = 5;
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

    fn update(self: Scene) void {
        switch (self) {
            inline else => |scene| return scene.update(),
        }
    }

    fn draw(self: Scene) void {
        switch (self) {
            inline else => |scene| return scene.draw(),
        }
    }
};

const Intro = struct {
    fn update(_: Intro) void {
        if (s.btn()) {
            s.reset();
            beep.play();
            s.scene(GAME);
        }
    }

    fn draw(_: Intro) void {
        color(0x21);
        text("INTRO", 8, 6);
    }
};

const Game = struct {
    fn update(_: Game) void {
        if (s.btn()) {
            s.life -= 1;
            s.score += 1;

            w4.tracef("life %d score %d", s.life, s.score);
        }

        if (s.life == 0) {
            s.scene(OVER);
        }
    }

    fn draw(_: Game) void {
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
    fn update(_: Over) void {
        if (s.btn()) {
            s.scene(INTRO);
        }
    }

    fn draw(_: Over) void {
        color(0x41);
        text("GAME OVER!", 8, 6);
    }
};

// The scene indexes
const INTRO: u2 = 0;
const GAME: u2 = 1;
const OVER: u2 = 2;

// Proxy functions for w4

fn text(str: []const u8, x: i32, y: i32) void {
    w4.text(str, x, y);
}

fn color(c: u8) void {
    w4.DRAW_COLORS.* = c;
}

fn rect(x: i32, y: i32, width: u32, height: u32) void {
    w4.rect(x, y, width, height);
}

fn trace(x: []const u8) void {
    w4.trace(x);
}

fn clear(c: u8) void {
    for (w4.FRAMEBUFFER) |*x| {
        x.* = c | (c << 2) | (c << 4) | (c << 6);
    }
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
    channel: u32 = 0,
    mode: u32 = 0,
    pan: u32 = 0,

    fn play(self: Tone) void {
        const frequency = self.freq1 | (self.freq2 << 16);
        const duration = (self.attack << 24) | (self.decay << 16) | self.sustain | (self.release << 8);
        const volume = (self.peak << 8) | self.volume;
        const flags = self.channel | (self.mode << 2) | (self.pan << 4);

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
    .channel = 1,
    .mode = 0,
};

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
