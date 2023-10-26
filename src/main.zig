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
        clear(3);

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
            s.scene(OVER);
            //s.scene(GAME);

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

    fn draw(self: Over) void {
        clear(2);

        const x = 8;
        const y = 3;

        color(4);
        text("The game is over!", x, y);

        color(1);
        text("The game is over!", x + 1, y + 1);

        self.death();
    }

    fn death(self: Over) void {
        self.cloak();
        self.scythe();
        self.skull();
        self.hand();
    }

    fn cloak(_: Over) void {
        color(0x33);
        rect(69, 40, 25, 106); // middle body

        // top left

        vline(51, 87, 2);
        vline(52, 86, 4);
        vline(53, 85, 5);
        vline(54, 84, 6);
        vline(55, 82, 8);
        vline(56, 80, 11);
        vline(56, 56, 14);
        vline(57, 53, 38);
        vline(58, 51, 40);
        vline(59, 50, 41);
        vline(60, 48, 43);
        vline(61, 47, 44);
        vline(62, 46, 45);
        vline(63, 45, 46);
        vline(64, 44, 46);
        vline(65, 43, 47);
        vline(66, 42, 48);
        vline(67, 41, 49);
        vline(68, 40, 107);

        vline(70, 39, 3);
        vline(71, 38, 3);
        vline(72, 37, 4);
        vline(73, 36, 5);
        vline(74, 35, 6);
        vline(75, 34, 7);
        vline(76, 34, 7);
        vline(77, 33, 8);
        vline(78, 33, 8);
        vline(79, 32, 9);
        vline(80, 32, 9);

        // left sleeve

        vline(60, 111, 5);
        vline(61, 107, 11);
        vline(62, 104, 16);
        vline(63, 102, 18);

        vline(64, 99, 48);
        vline(65, 96, 51);
        vline(66, 93, 54);
        vline(67, 91, 56);

        hline(65, 146, 35);
        hline(70, 147, 25);

        // left hem

        vline(58, 140, 2);
        vline(59, 138, 6);
        vline(60, 135, 10);
        vline(61, 132, 14);
        vline(62, 129, 17);
        vline(63, 124, 22);

        // top right side

        vline(81, 32, 9);
        vline(82, 32, 9);
        vline(83, 32, 9);
        vline(84, 32, 9);
        vline(85, 33, 8);
        vline(86, 33, 8);
        vline(87, 34, 7);
        vline(88, 34, 7);
        vline(89, 35, 6);
        vline(90, 36, 5);
        vline(91, 36, 5);
        vline(92, 37, 4);
        vline(93, 38, 3);

        vline(94, 39, 108); // right of center rect

        // right top

        vline(95, 40, 46);
        vline(96, 41, 44);
        vline(97, 42, 42);
        vline(98, 43, 40);
        vline(99, 44, 38);
        vline(100, 45, 36);
        vline(101, 46, 33);
        vline(102, 47, 30);
        vline(103, 48, 28);
        vline(104, 49, 25);
        vline(105, 51, 20);
        vline(106, 53, 13);
        vline(107, 55, 6);

        // right bottom
        vline(95, 89, 57);
        vline(96, 91, 55);
        vline(97, 93, 53);
        vline(98, 95, 51);
        vline(99, 96, 50);

        vline(100, 98, 26);
        vline(101, 99, 22);
        vline(102, 99, 23);
        vline(103, 100, 22);
        vline(104, 101, 20);
        vline(105, 102, 19);
        vline(106, 103, 16);

        hline(100, 124, 1);
        hline(100, 125, 1);
        hline(100, 126, 1);
        hline(100, 127, 1);
        hline(100, 128, 2);
        hline(100, 129, 2);
        hline(100, 130, 3);
        hline(100, 131, 3);
        hline(100, 132, 4);
        hline(100, 133, 5);

        vline(100, 134, 12);
        vline(101, 134, 11);
        vline(102, 134, 11);
        vline(103, 134, 11);
        vline(104, 134, 11);
        vline(105, 134, 10);
        vline(106, 134, 10);
        vline(107, 135, 9);
        vline(108, 136, 7);
    }

    fn skull(_: Over) void {
        color(0x11);
        oval(60, 42, 40, 36);

        color(0x33);
        oval(65, 58, 12, 14);
        oval(82, 58, 13, 14); // left eye

        color(0x11);
        rect(65, 56, 29, 5); // cut top eyes

        // mouth
        color(0x31);
        oval(70, 75, 6, 6);
        oval(75, 76, 6, 6);
        oval(80, 76, 6, 6);
        oval(85, 75, 6, 6);

        color(0x11);
        rect(70, 75, 21, 2);
        hline(70, 77, 19);

        color(0x11);
        oval(73, 81, 4, 5);
        oval(78, 81, 4, 5);
        oval(83, 81, 4, 5);
        oval(73, 83, 14, 3);

        // nose
        color(0x33);
        line(77, 72, 79, 70);
        line(77, 73, 79, 71);
        line(81, 72, 79, 70);
        line(81, 73, 79, 71);

        // hood
        color(3);

        hline(73, 42, 12);
        hline(72, 43, 16);
        hline(70, 44, 20);
        hline(68, 45, 24);
        hline(67, 46, 26);
        hline(66, 47, 28);
        hline(65, 48, 30);
        hline(64, 49, 32);
        hline(63, 50, 12);
        hline(62, 51, 10);
        hline(62, 52, 8);
        hline(62, 53, 6);
        hline(62, 54, 4);
        hline(62, 55, 2);

        hline(82, 50, 15);
        hline(84, 51, 14);

        hline(86, 52, 12);
        hline(93, 53, 6);
        hline(95, 54, 4);
        hline(97, 55, 2);

        // left side
        vline(62, 51, 8);
        vline(62, 65, 4);
        vline(61, 53, 14);
        vline(60, 56, 8);

        // right side
        vline(99, 56, 8);
        vline(98, 64, 3);
        vline(98, 53, 6);
    }

    fn scythe(_: Over) void {
        color(1);

        line(102, 140, 110, 37);
        line(103, 140, 111, 37);
        line(104, 140, 112, 37);
        line(105, 140, 113, 37);

        // blade
        color(3);
        hline(85, 14, 10);
        hline(79, 15, 19);
        hline(75, 16, 25);
        hline(71, 17, 32);
        hline(66, 18, 40);
        hline(63, 19, 46);
        hline(60, 20, 52);
        hline(58, 21, 57);
        hline(57, 22, 61);
        hline(56, 23, 64);
        hline(55, 24, 67);
        hline(54, 25, 69);
        hline(53, 26, 70);
        hline(53, 27, 70);
        hline(52, 28, 26);

        hline(78, 28, 44); // blade right
        hline(91, 29, 31); // blade right
        hline(96, 30, 25); // blade right
        hline(98, 31, 23); // blade right
        hline(101, 32, 20); // blade right
        hline(104, 33, 17); // blade right
        hline(106, 34, 15); // blade right

        hline(109, 35, 11); // blade right
        hline(110, 36, 10); // blade right
        hline(110, 37, 10); // blade right

        hline(51, 29, 20);
        hline(50, 30, 18);
        hline(49, 31, 14);
        hline(48, 32, 13);
        hline(48, 33, 12);
        hline(47, 34, 11);

        hline(47, 35, 10);
        hline(46, 36, 9);
        hline(45, 37, 9);
        hline(45, 38, 8);
        hline(44, 39, 7);
        hline(44, 40, 6);
        hline(43, 41, 6);
        hline(43, 42, 6);
        hline(42, 43, 5);
        hline(42, 44, 4);
        hline(41, 45, 3);
        hline(41, 46, 1);

        color(1);
        hline(77, 23, 15);
        hline(68, 24, 30);
        hline(66, 25, 35);
        hline(63, 26, 41);
        hline(61, 27, 10);
        hline(93, 27, 14);

        hline(59, 28, 8);
        hline(58, 29, 6);
        hline(56, 30, 5);
        hline(55, 31, 4);
        hline(54, 32, 3);
        hline(53, 33, 3);
        hline(52, 34, 2);
        hline(51, 35, 2);
        hline(50, 36, 2);
        hline(49, 37, 1);
        hline(48, 38, 1);
        hline(47, 39, 1);
        hline(46, 40, 1);

        hline(97, 28, 12);
        hline(100, 29, 11);
        hline(103, 30, 9);
        hline(105, 31, 7);
        hline(107, 32, 5);
        hline(109, 33, 3);
        hline(111, 34, 1);

        // handle
        color(4);
        line(110, 37, 102, 133);
        line(105, 139, 114, 38);
    }

    fn hand(_: Over) void {
        color(0x31);
        oval(103, 106, 8, 6);
        oval(103, 104, 10, 5);
        oval(103, 100, 9, 5);
        oval(100, 100, 5, 9); // thumb
    }
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

// The scene indexes
const INTRO: u2 = 0;
const GAME: u2 = 1;
const OVER: u2 = 2;

// Proxy functions for w4
fn text(str: []const u8, x: i32, y: i32) void {
    w4.text(str, x, y);
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

fn trace(x: []const u8) void {
    w4.trace(x);
}

fn color(c: u8) void {
    w4.DRAW_COLORS.* = c;
}

fn clear(c: u8) void {
    for (w4.FRAMEBUFFER) |*x| {
        x.* = c - 1 | (c - 1 << 2) | (c - 1 << 4) | (c - 1 << 6);
    }
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
