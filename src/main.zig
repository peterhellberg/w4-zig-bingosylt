const std = @import("std");

// WASM-4
const w4 = @import("wasm4.zig");

const rect = w4.rect;
const line = w4.line;
const hline = w4.hline;
const vline = w4.vline;

// 640 ought to be enough for anybody.
var memory: [640]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&memory);
const allocator = fba.allocator();

// Random number generator
var rnd = std.rand.DefaultPrng.init(0);

// 2D Vector implementation
const Vec = @import("Vec.zig");
const V = Vec.new;
const I = Vec.inew;
const T = Vec.tri;

// Particle implementation
const Particle = @import("Particle.zig");
const P = Particle.new;

const Tone = @import("Tone.zig");
const Sprite = @import("Sprite.zig");

// Disk represents what is read and written
// from the persistent storage by the game.
const Disk = struct {
    si: u2,
};

// Global state
var s = State{};

const State = struct {
    fn start(_: *State) void {
        w4.trace(
            \\    ______ _______ _______ _______ _______ _______ ___ ___ _____  _______
            \\   |   __ |_     _|    |  |     __|       |     __|   |   |     ||_     _|
            \\  /|   __ <_|   |_|       |    |  |   -   |__     |\     /|       || #9|\
            \\.::|______|_______|__|____|_______|_______|_______| |___| |_______||___|::.
            \\
        );

        // Transition to the scene loaded from disk
        // defaulting to the OVER scene
        s.transition(s.load(OVER));
    }

    fn load(state: *State, defaultScene: u2) u2 {
        var d: Disk = .{ .si = defaultScene };

        _ = w4.diskr(@ptrCast(&d), @sizeOf(@TypeOf(d)));

        state.disk = d;

        return d.si;
    }

    fn update(state: *State) !void {
        // Update mouse press on this and last frame
        state.btf = state.buttons.* & (state.buttons.* ^ state.blf);
        state.blf = state.buttons.*;

        state.gtf = state.gamepad.* & (state.gamepad.* ^ state.glf);
        state.glf = state.gamepad.*;

        if (state.buttons.* & w4.MOUSE_LEFT != 0) {
            // Update mouse position
            state.x = @intCast(w4.MOUSE_X.*);
            state.y = @intCast(w4.MOUSE_Y.*);

            if (state.x < 0) state.x = 0;
            if (state.y < 0) state.y = 0;
            if (state.x > 160) state.x = 160;
            if (state.y > 160) state.y = 160;

            state.m = V(@floatFromInt(state.x), @floatFromInt(state.y));
            state.lm = state.m;
        }

        // Increment the frame counter
        state.frame +%= 1;

        // Update the scene specific state
        try state.scenes[state.disk.si].update();
    }

    fn draw(state: *State) !void {
        // Draw the scene
        try state.scenes[s.disk.si].draw();
    }

    fn mouseLeft(state: *State) bool {
        return state.btf & w4.MOUSE_LEFT != 0;
    }

    fn mouseMiddle(state: *State) bool {
        return state.btf & w4.MOUSE_MIDDLE != 0;
    }

    fn mouseRight(state: *State) bool {
        return state.btf & w4.MOUSE_RIGHT != 0;
    }

    fn button1(state: *State) bool {
        return state.gtf & w4.BUTTON_1 != 0;
    }

    fn button2(state: *State) bool {
        return state.gtf & w4.BUTTON_2 != 0;
    }

    fn buttonUp(state: *State) bool {
        return state.gtf & w4.BUTTON_UP != 0;
    }

    fn buttonDown(state: *State) bool {
        return state.gtf & w4.BUTTON_DOWN != 0;
    }

    fn buttonLeft(state: *State) bool {
        return state.gtf & w4.BUTTON_LEFT != 0;
    }

    fn buttonRight(state: *State) bool {
        return state.gtf & w4.BUTTON_RIGHT != 0;
    }

    fn mouseLeftHeld(state: *State) bool {
        return state.buttons.* & w4.MOUSE_LEFT != 0;
    }

    fn button1Held(state: *State) bool {
        return state.gamepad.* & w4.BUTTON_1 != 0;
    }

    fn button2Held(state: *State) bool {
        return state.gamepad.* & w4.BUTTON_2 != 0;
    }

    fn buttonUpHeld(state: *State) bool {
        return state.gamepad.* & w4.BUTTON_UP != 0;
    }

    fn buttonDownHeld(state: *State) bool {
        return state.gamepad.* & w4.BUTTON_DOWN != 0;
    }

    fn buttonRightHeld(state: *State) bool {
        return state.gamepad.* & w4.BUTTON_RIGHT != 0;
    }

    fn buttonLeftHeld(state: *State) bool {
        return state.gamepad.* & w4.BUTTON_LEFT != 0;
    }

    fn transition(state: *State, si: u2) void {
        log("🎬 Scene  = {s}\n", .{switch (si) {
            INTRO => "INTRO",
            GAME => "GAME",
            OVER => "OVER",
            else => "UNKNOWN",
        }});

        _ = try state.scenes[si].enter();

        state.disk.si = si;

        state.save();
    }

    fn save(state: *State) void {
        // Save the state disk into persistent storage
        _ = w4.diskw(@ptrCast(&state.disk), @sizeOf(@TypeOf(state.disk)));
    }

    disk: Disk = .{ .si = 0 },

    frame: u32 = 0,

    x: i32 = 80, // Mouse X
    y: i32 = 80, // Mouse Y

    blf: u8 = 0, // Buttons pressed last frame
    btf: u8 = 0, // Buttons pressed this frame

    glf: u8 = 0, // Gamepad pressed last frame
    gtf: u8 = 0, // Gamepad pressed this frame

    // The inputs
    buttons: *const u8 = w4.MOUSE_BUTTONS,
    gamepad: *const u8 = w4.GAMEPAD1,

    m: Vec = Vec.set(80),
    lm: Vec = Vec.set(80),

    scenes: [3]Scene = .{
        .{ .intro = Intro{} },
        .{ .game = Game{} },
        .{ .over = Over{} },
    },
};

const Intro = struct {
    fn enter(intro: *Intro) !void {
        w4.PALETTE.* = intro.tangerineNoir;
        intro.touchedZaps = .{false} ** 4;
        intro.prevTouchedZaps = .{false} ** 4;
        intro.powerOnFrame = 0;
    }

    fn update(intro: *Intro) !void {
        w4.PALETTE.*[3] = intro.repeating[
            @mod(
                @divFloor(s.frame, 8),
                intro.repeating.len,
            )
        ];

        if (s.button2()) {
            intro.debugEnabled = !intro.debugEnabled;
        }

        if (s.mouseLeftHeld() and intro.towerPos.distance(s.m) < 20) {
            intro.towerPos = intro.towerPos.lerp(s.m, 0.6);

            const tp = intro.towerPos;

            if (tp.distance(V(13, 13)) < 10) intro.touchedZaps[0] = true;
            if (tp.distance(V(146, 11)) < 10) intro.touchedZaps[1] = true;
            if (tp.distance(V(146, 146)) < 10) intro.touchedZaps[2] = true;
            if (tp.distance(V(13, 146)) < 10) intro.touchedZaps[3] = true;

            if (intro.touchedZaps[0] and !intro.prevTouchedZaps[0]) intro.zapConnectedTone.play(2);
            if (intro.touchedZaps[1] and !intro.prevTouchedZaps[1]) intro.zapConnectedTone.play(2);
            if (intro.touchedZaps[2] and !intro.prevTouchedZaps[2]) intro.zapConnectedTone.play(2);
            if (intro.touchedZaps[3] and !intro.prevTouchedZaps[3]) intro.zapConnectedTone.play(2);
        } else {
            const center = V(80, 80);

            intro.towerPos = intro.towerPos.lerp(center, 0.1);

            const tp = intro.towerPos;

            if (s.mouseLeftHeld()) {
                if (tp.distance(center) < 10 and s.m.distance(V(13, 13)) < 10) intro.touchedZaps[0] = false;
                if (tp.distance(center) < 10 and s.m.distance(V(146, 11)) < 10) intro.touchedZaps[1] = false;
                if (tp.distance(center) < 10 and s.m.distance(V(146, 146)) < 10) intro.touchedZaps[2] = false;
                if (tp.distance(center) < 10 and s.m.distance(V(13, 146)) < 10) intro.touchedZaps[3] = false;
            }

            if (!intro.touchedZaps[0] and intro.prevTouchedZaps[0]) intro.powerOffTone.play(2);
            if (!intro.touchedZaps[1] and intro.prevTouchedZaps[1]) intro.powerOffTone.play(2);
            if (!intro.touchedZaps[2] and intro.prevTouchedZaps[2]) intro.powerOffTone.play(2);
            if (!intro.touchedZaps[3] and intro.prevTouchedZaps[3]) intro.powerOffTone.play(2);
        }

        if (intro.powerJustOn()) {
            intro.powerOnTone.play(1);
            intro.powerOnFrame = s.frame;
        }

        if (intro.powerJustOff()) {
            intro.powerOffTone.play(1);
            intro.powerOnFrame = 0;
        }

        intro.prevTouchedZaps = intro.touchedZaps;
    }

    fn draw(intro: *Intro) !void {
        clear(BLACK);

        intro.background();

        const np = ([_]f32{ 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 })[0..];

        intro.catline(V(-20, 70), V(180, 90), 25, np, V(3, 4));
        intro.scrollingTitle(138);
        intro.tower(np);
        intro.zaps();
        intro.topcat();

        color(WHITE);
        if (intro.powerIsOn()) {
            if (intro.easterEggTime()) {
                w4.text("KODSNACK!", 44, 15);
                flyingBirds(s.frame);
            } else {
                w4.text("POWER ON!", 44, 15);
            }
        } else {
            w4.text("NO POWER!", 44, 15);
        }

        try intro.debug(.{
            s.frame,
            s.x,
            s.y,
            intro.powerIsOn(),
            @as(i32, @intFromFloat(s.m.distance(V(80, 80)))),
        });

        if (intro.powerOnFrame > 0) {
            const sincePowerOn = s.frame - intro.powerOnFrame;

            const size: u32 = if (sincePowerOn < 500) sincePowerOn / 2 else 250;
            const step: f32 = @floatFromInt(size);

            const tp = intro.towerPos;

            if (size < 250) color(PRIMARY) else color(BLACK);
            tp.offset(-(@divFloor(step, 2)), -(@divFloor(step, 2))).oval(size, size);

            if (size == 250) {
                title("PRESS\n\x80to\nGAME!", 104, 105, 0, WHITE);

                if (s.button1()) {
                    s.transition(GAME);
                }
            }

            // Font mapping
            ///////////////
            // å -> \xE5 //
            // ä -> \xE4 //
            // ö -> \xF6 //
            // Å -> \xC5 //
            // Ä -> \xC4 //
            // Ö -> \xD6 //
            ///////////////
        }
    }

    fn background(intro: *Intro) void {
        if (intro.powerIsOn()) {
            triangle(T(-1, -1, 161, -1, 161, 161), 0, introBgPowerOn);
            triangle(T(-1, -1, 161, 161, -1, 161), 0, introBgPowerOn);
        }

        const r = rnd.random();

        for (0..160) |y| {
            for (0..160) |x| {
                if (@mod(x ^ y, 5) == 0) {
                    if (intro.powerIsOn()) {
                        const rf = r.float(f32);
                        if (rf < 0.001) {
                            color(0x3310);
                            I(x, y).oval(3, 3);
                        }
                        color(GRAY);
                        upx(x, y);
                    } else {
                        color(GRAY);
                        upx(x, y);
                    }
                }
            }
        }
    }

    fn zaps(_: *Intro) void {
        color(BLACK);
        V(1, 0).oval(21, 21);
        V(1, 137).oval(21, 21);
        V(137, 1).oval(21, 21);
        V(137, 137).oval(21, 21);

        const zap = Sprite.zap;

        color(0x3240);
        zap.blit(140, 5, zap.flags);
        zap.blit(5, 5, zap.flags | w4.BLIT_FLIP_Y);

        zap.blit(138, 138, zap.flags | w4.BLIT_ROTATE);
        zap.blit(5, 139, zap.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_Y);

        color(0x4000);
        zap.blit(139, 5, zap.flags);
        zap.blit(6, 5, zap.flags | w4.BLIT_FLIP_Y);

        zap.blit(138, 137, zap.flags | w4.BLIT_ROTATE);
        zap.blit(5, 137, zap.flags | w4.BLIT_ROTATE | w4.BLIT_FLIP_Y);
    }

    fn tower(intro: *Intro, np: *const [9]f32) void {
        intro.towerLine(V(30, 130), 24, np, 0x33, 0x33);
        intro.towerLine(V(130, 30), 24, np, 0x33, 0x33);
        intro.towerLine(V(30, 30), 24, np, 0x33, 0x33);
        intro.towerLine(V(130, 130), 24, np, 0x33, 0x33);

        const tp = intro.towerPos;

        color(0x33);
        tp.offset(-30, -30).rect(60, 60);

        if (intro.powerIsOn()) color(BLACK) else color(GRAY);
        tp.offset(-25, -25).text(if (intro.touchedZaps[0]) "ON" else "OFF");
        tp.offset(5, -25).text(if (intro.touchedZaps[1]) " ON" else "OFF");
        tp.offset(5, 18).text(if (intro.touchedZaps[2]) " ON" else "OFF");
        tp.offset(-25, 18).text(if (intro.touchedZaps[3]) "ON" else "OFF");
    }

    fn topcat(intro: *Intro) void {
        const tp = intro.towerPos;

        color(0x33);

        if (s.mouseLeftHeld() and tp.distance(s.m) < 20) {
            color(0x33);

            if (tp.distance(V(13, 13)) < 10) color(0x14);
            if (tp.distance(V(146, 11)) < 10) color(0x14);
            if (tp.distance(V(146, 146)) < 10) color(0x14);
            if (tp.distance(V(13, 146)) < 10) color(0x14);
        }

        tp.sub(V(14, 14)).oval(28, 28);

        if (s.mouseLeftHeld() and !s.buttonUpHeld()) {
            color(GRAY);
            s.lm.line(tp);

            color(0x3313);

            if (tp.distance(V(13, 13)) < 10) color(0x44);
            if (tp.distance(V(146, 11)) < 10) color(0x44);
            if (tp.distance(V(146, 146)) < 10) color(0x44);
            if (tp.distance(V(13, 146)) < 10) color(0x44);

            s.lm.sub(V(13, 13)).oval(26, 26);
        }

        color(0x4001);

        var pos = intro.towerPos.offset(-6, -4);

        const cat = Sprite.cat;

        if (pos.x() < 80) {
            cat.vblit(pos, cat.flags | w4.BLIT_FLIP_X);
        } else {
            cat.vblit(pos, cat.flags);
        }
    }

    fn powerIsOn(intro: *Intro) bool {
        return @reduce(.And, intro.touchedZaps);
    }

    fn powerJustOn(intro: *Intro) bool {
        return intro.powerIsOn() and !@reduce(.And, intro.prevTouchedZaps);
    }

    fn powerJustOff(intro: *Intro) bool {
        return !intro.powerIsOn() and @reduce(.And, intro.prevTouchedZaps);
    }

    fn towerLine(intro: *Intro, a: Vec, dotSize: u32, points: []const f32, c1: u16, c2: u16) void {
        const tp = intro.towerPos;

        if (a.eql(V(30, 30))) {
            if (intro.touchedZaps[0]) {
                color(0x34);
                const ao = a.offset(-15, -15);

                ao.line(tp);
                dotline(ao, tp, 6, points);
            }
        }

        if (a.eql(V(130, 30))) {
            if (intro.touchedZaps[1]) {
                color(0x34);
                const ao = a.offset(15, -15);

                ao.line(tp);
                dotline(ao, tp, 6, points);
            }
        }

        if (a.eql(V(130, 130))) {
            if (intro.touchedZaps[2]) {
                color(0x34);
                const ao = a.offset(10, 13);

                ao.line(tp);
                dotline(ao, tp, 6, points);
            }
        }

        if (a.eql(V(30, 130))) {
            if (intro.touchedZaps[3]) {
                color(0x34);
                const ao = a.offset(-13, 14);

                ao.line(tp);
                dotline(ao, tp, 6, points);
            }
        }

        for (0.., points) |i, p| {
            const size = dotSize * i / 4;
            const fsize: f32 = @floatFromInt(size);
            const offset = Vec.set(@divFloor(fsize, 2));

            if (@mod(i, 2) == 0) {
                if (intro.powerIsOn()) color(0x43) else color(c2);

                if (a.eql(V(30, 30)) and intro.touchedZaps[0]) color(0x43);
                if (a.eql(V(130, 30)) and intro.touchedZaps[1]) color(0x43);
                if (a.eql(V(130, 130)) and intro.touchedZaps[2]) color(0x43);
                if (a.eql(V(30, 130)) and intro.touchedZaps[3]) color(0x43);
            } else {
                color(c1);
            }

            a.lerp(tp, p).sub(offset).rect(size, size);
        }
    }

    fn catline(intro: *Intro, a: Vec, b: Vec, size: u32, points: []const f32, catOffset: Vec) void {
        var fframe: f32 = @floatFromInt(s.frame);
        var t: f32 = @abs(@mod(fframe, 1000) - 500) / 500;
        const catPos = a.lerp(b, t).sub(catOffset);
        const fsize: f32 = @floatFromInt(size);
        const offset = Vec.set(@divFloor(fsize, 2));

        for (0.., points) |i, p| {
            if (@mod(i, 2) == 0) {
                if (intro.powerIsOn()) color(0x14) else color(0x33);
            } else {
                if (intro.powerIsOn()) color(0x41) else color(0x33);
            }

            a.lerp(b, p).sub(offset).rect(size, size);
        }

        if (intro.powerIsOn()) color(0x403) else color(0x101);

        const cat = Sprite.cat;

        if (intro.catLastPos.x() < catPos.x()) {
            cat.vblit(catPos, cat.flags | w4.BLIT_FLIP_X);
        } else {
            cat.vblit(catPos, cat.flags);
        }

        intro.catLastPos = catPos;
    }

    fn scrollingTitle(intro: *Intro, down: i32) void {
        var offset: i32 = @intCast(@mod(@divFloor(s.frame, 1), 480));

        color(GRAY);

        if (intro.easterEggTime()) {
            w4.text("- - - - - - -", 180 + -offset - 12, down + 6);
            w4.text("_ _ _ _ _ _ _", 180 + -offset - 13, down + 4);
            title2("P \xC5 S K \xC4 G G", 180 + -offset - 18, down + 6, GRAY, PRIMARY);
        } else {
            w4.text("- - - - - ", 180 + -offset - 12, down + 6);
            w4.text("_ _ _ _ _", 180 + -offset - 13, down + 4);
            title2("I N T R O", 180 + -offset - 18, down + 6, GRAY, PRIMARY);
        }
    }

    fn debug(intro: *Intro, args: anytype) !void {
        if (!intro.debugEnabled) {
            return;
        }

        const cat = Sprite.cat;

        // Gray cat
        color(0x4002);
        cat.vblit(intro.towerPos.offset(10, 10), cat.flags);

        const str = try std.fmt.allocPrint(allocator,
            \\FRAME: {d}
            \\MOUSE: [{d}][{d}]
            \\STATE: {any}
            \\DEBUG: {any}
        , args);
        defer allocator.free(str);

        title(str, 20, 120, GRAY, WHITE);
    }

    fn easterEggTime(intro: *Intro) bool {
        return intro.powerIsOn() and s.frame - intro.powerOnFrame > 270;
    }

    fn introBgPowerOn(wx: i32, p: Vec, c: Vec, _: f32, _: f32, _: f32) u16 {
        _ = wx;
        const d = p.distance(c);
        const x = p.xu();
        const y = p.yu();

        if (d > @abs(@as(f32, @floatFromInt(@mod(s.frame, 60))) / 32 - 16) and @mod(y ^ x, 7) == 0 and @mod(y, 2) == 1) {
            if (d < 11 and @mod(s.frame, 14) < 102) {
                return PRIMARY;
            }

            if (@mod(x * y, 4) < 1) {
                return PRIMARY;
            }

            return BLACK;
        }

        return 0;
    }

    debugEnabled: bool = false,
    catLastPos: Vec = Vec.zero(),
    towerPos: Vec = V(80, 80),

    touchedZaps: @Vector(4, bool) = .{false} ** 4,
    prevTouchedZaps: @Vector(4, bool) = .{false} ** 4,

    powerOnFrame: u32 = 0,

    // Tangerine Noir
    // https://lospec.com/palette-list/tangerine-noir
    tangerineNoir: [4]u32 = .{
        0xfcfcfc, // White
        0x393541, // Gray
        0x191a1f, // Black
        0xee964b, // Tangerine
    },

    // Repeating version of Dream Haze 8
    // https://lospec.com/palette-list/dream-haze-8
    repeating: [15]u32 = .{
        0x3c42c4,
        0x6e51c8,
        0xa065cd,
        0xce79d2,
        0xd68fb8,
        0xdda2a3,
        0xeac4ae,
        0xf4dfbe,
        0xf4dfbe,
        0xeac4ae,
        0xdda2a3,
        0xd68fb8,
        0xce79d2,
        0xa065cd,
        0x6e51c8,
    },

    zapConnectedTone: Tone = Tone{
        .freq1 = 69,
        .freq2 = 120,
        .attack = 0,
        .decay = 0,
        .sustain = 20,
        .release = 10,
        .peak = 16,
        .volume = 10,
        .mode = 2,
    },

    powerOffTone: Tone = Tone{
        .freq1 = 120,
        .freq2 = 69,
        .attack = 0,
        .decay = 0,
        .sustain = 20,
        .release = 10,
        .peak = 16,
        .volume = 10,
        .mode = 2,
    },

    powerOnTone: Tone = Tone{
        .freq1 = 70,
        .freq2 = 70,
        .attack = 51,
        .decay = 127,
        .sustain = 214,
        .release = 45,
        .peak = 10,
        .volume = 6,
        .mode = 2,
    },
};

const Game = struct {
    fn enter(game: *Game) !void {
        w4.PALETTE.* = game.palette;

        game.charges = 5;
        game.distance = 0;
        game.ship.energy = 15;

        game.startup.play(0);
        game.startup.play(1);
        game.startup.play(2);

        const r = rnd.random();

        for (game.stars, 0..) |_, i| {
            game.stars[i][0] = r.intRangeLessThan(u8, 10, 160);
            game.stars[i][1] = r.intRangeLessThan(u8, 25, 160);
            game.stars[i][2] = if (r.boolean()) 1 else 0;
        }

        for (game.mountains, 0..) |_, i| {
            game.mountains[i][0] = r.intRangeLessThan(i14, 1, 3); // Z-axis
            game.mountains[i][1] = r.intRangeLessThan(i14, -4096, 4096); // World X
            game.mountains[i][2] = r.intRangeLessThan(i14, 15, 60); // Width
            game.mountains[i][3] = r.intRangeLessThan(i14, 4, 75); // Height
        }

        for (game.stalactites, 0..) |_, i| {
            game.stalactites[i][0] = r.intRangeLessThan(i14, -4096, 4096); // World X
            game.stalactites[i][1] = r.intRangeLessThan(i14, 5, 30); // Width
            game.stalactites[i][2] = r.intRangeLessThan(i14, 4, 50); // Height
        }
    }

    fn update(game: *Game) !void {
        game.ship.update(game);

        if (game.isDead()) {
            game.died.play(2);
            s.transition(OVER);
        }

        if (game.hudRechargeBtnClicked() or s.button2()) {
            game.ship.energy +|= 5;
            game.charges -|= 1;
        }
    }

    fn isDead(game: *Game) bool {
        return game.charges == 0 and game.ship.energy == 0 and game.ship.offset == -64;
    }

    fn draw(game: *Game) !void {
        clear(BLACK);

        const wx: i32 = -@divFloor(game.worldX, 15);

        { // Background
            const r = rnd.random();

            { // Stars
                for (game.stars) |sp| {
                    const rf = r.float(f32);

                    color(if (rf < 0.01) WHITE else GRAY);

                    if (sp[2] == 1) {
                        pixel(sp[0] - 1, sp[1]);
                        pixel(sp[0] + 1, sp[1]);
                        pixel(sp[0], sp[1] - 1);
                        pixel(sp[0], sp[1] + 1);
                    } else {
                        pixel(sp[0], sp[1]);
                    }
                }
            }

            game.mountain(wx, 2, 100, 20, 50);
            game.mountain(wx, 3, 140, 60, 70);
            game.mountain(wx, 2, 200, 30, 50);

            game.stalactite(wx, 0, 25, 30);
            game.stalactite(wx, 150, 25, 60);

            { // Mountains
                for (game.mountains) |m| {
                    if (m[3] > 1) {
                        game.mountain(wx, m[0], m[1], m[2], m[3]);
                    }
                }
            }

            { // Stalactites
                for (game.stalactites) |st| {
                    game.stalactite(wx, st[0], st[1], st[2]);
                }
            }
        }

        game.ground(wx);

        game.ship.draw(wx, 90);

        { // Foreground
            game.stalactite(wx, 50, 25, 40);
            game.stalactite(wx, 100, 25, 50);
            game.stalactite(wx, 200, 25, 70);

            game.stalactite(wx, 30, 20, 5);

            { // Mountains
                for (game.mountains) |m| {
                    if (m[0] < 2) {
                        game.mountain(wx, m[0], m[1], m[2], m[3]);
                    }
                }
            }
        }

        game.hud();
    }

    fn mountainColor1(wx: i32, p: Vec, c: Vec, _: f32, _: f32, gamma: f32) u16 {
        if (gamma > 0.2 and p.distance(c) > 25) {
            return WHITE;
        }
        return @intCast(@divFloor(@mod((wx - p.xi()) ^ p.yi(), 3), 1) + 2);
    }

    fn mountainColor2(wx: i32, p: Vec, c: Vec, _: f32, _: f32, gamma: f32) u16 {
        if (gamma > 0.2 and p.distance(c) > 25) {
            return WHITE;
        }

        return @intCast(@divFloor(@mod((@divFloor(wx, 2) - p.xi()) ^ p.yi(), 6), 2) + 1);
    }

    fn mountainColor3(wx: i32, p: Vec, c: Vec, _: f32, _: f32, gamma: f32) u16 {
        if (gamma > 0.2 and p.distance(c) > 25) {
            return WHITE;
        }

        return @intCast(@divFloor(@mod((@divFloor(wx, 3) - p.xi()) ^ p.yi(), 8), 2) + 1);
    }

    fn mountain(_: *Game, wx: i32, FOO: i32, x: i32, width: i32, height: i32) void {
        triangle(.{
            I(@divFloor(wx, FOO) + x, 150),
            I(@divFloor(wx, FOO) + x + @divFloor(width, 2), 150 - height),
            I(@divFloor(wx, FOO) + x + width, 150),
        }, wx, switch (FOO) {
            1 => mountainColor1,
            2 => mountainColor2,
            3 => mountainColor3,
            else => triBLACK,
        });
    }

    fn ground(_: *Game, wx: i32) void {
        _ = wx;
        color(WHITE);

        I(10, 140).rect(150, 20);
    }

    fn stalactiteColor(wx: i32, p: Vec, c: Vec, _: f32, _: f32, _: f32) u16 {
        const d = p.distance(c);
        const x = wx - p.xu();
        const y = p.yu();

        if (d == 3) {
            return BLACK;
        }

        if (@mod(x, 5) == 0 and @mod(y ^ x, 4) == 1) {
            if (d < 11 and @mod(s.frame, 24) < 12) {
                return PRIMARY;
            }

            if (@mod(x * y, 4) < 1) {
                return WHITE;
            }

            return BLACK;
        } else {
            return GRAY;
        }
    }

    fn stalactite(_: *Game, wx: i32, x: i32, width: i32, height: i32) void {
        const w: i32 = @intCast(width);
        const o = @divFloor(w, 3);

        triangle(.{
            I(wx + x - o, 19),
            I(wx + x + (w - o), 19),
            I(wx + x + @divFloor(w, 4), 19 + height),
        }, wx, stalactiteColor);
    }

    fn hud(game: *Game) void {
        // Background of the HUD
        {
            color(BLACK);
            rect(0, 0, 160, 20);
            rect(0, 20, 10, 140);

            { // background pattern
                color(GRAY);
                for (0..8) |x| {
                    for (0..160) |y| {
                        if (@mod(x ^ y, 5) == 0) upx(x, y);
                    }
                }

                for (8..142) |x| {
                    for (0..19) |y| {
                        if (@mod(x ^ y, 5) == 0) upx(x, y);
                    }
                }
            }

            { // Orange border line
                color(PRIMARY);
                line(8, 160, 8, 22);
                line(8, 21, 11, 18);
                line(12, 18, 135, 18);
            }

            { //Sylt logo
                const sylt = Sprite.sylt;

                color(0x0003);
                sylt.blit(88, 4, sylt.flags);

                color(0x4301);
                sylt.blit(87, 3, sylt.flags);
            }
        }

        game.hudInputBar(4, 142);
        game.hudEnergyBar();
        game.hudInfoBar();
        game.hudRechargeBtn();
    }

    fn hudRechargeBtnClicked(_: *Game) bool {
        return s.mouseLeft() and s.x > 2 and s.y > 2 and s.x < 80 and s.y < 15;
    }

    fn hudRechargeBtn(game: *Game) void {
        color(0x13);
        if (game.hudRechargeBtnClicked() or s.button2()) {
            rect(3, 3, 78, 14);
            title("\x81RECHARGE", 5, 6, GRAY, WHITE);
        } else {
            rect(2, 2, 78, 14);
            title("\x81RECHARGE", 4, 5, GRAY, PRIMARY);
        }

        const dots: usize = @intCast(game.charges);

        for (0..dots) |i| {
            const dy = 55 + 13 * @as(i32, @intCast(i));

            color(WHITE);
            line(2, 16, 2, dy + 3);

            color(0x41);
            w4.oval(5, dy, 8, 8);
            hline(2, dy + 3, 5);

            color(0x01);
            w4.text("C", 5, 55 + 13 * @as(i32, @intCast(i)));
        }
    }

    fn hudInputBar(_: *Game, x: i32, y: i32) void {
        color(0x31);
        rect(x, y, 9, 9);

        {
            color(0x43);
            rect(x + 2, y + 2, 2, 2);
            rect(x + 5, y + 2, 2, 2);
            pixel(x + 3, y + 3);
            pixel(x + 6, y + 3);

            pixel(x + 2, y + 5);
            pixel(x + 6, y + 5);
            pixel(x + 3, y + 6);
            pixel(x + 4, y + 6);
            pixel(x + 5, y + 6);
        }
        {
            inputBarButton("\x80", x, y, s.button1Held());
            inputBarButton("\x81", x, y, s.button2Held());
            inputBarButton("\x84", x, y, s.buttonLeftHeld());
            inputBarButton("\x85", x, y, s.buttonRightHeld());
            inputBarButton("\x86", x, y, s.buttonUpHeld());
            inputBarButton("\x87", x, y, s.buttonDownHeld());
        }
        {
            color(BLACK);
            pixel(x + 1, y + 1);
            pixel(x + 1, y + 7);
            pixel(x + 7, y + 1);
            pixel(x + 7, y + 7);
        }
        {
            color(GRAY);
            pixel(x, y);
            pixel(x, y + 8);
            color(PRIMARY);
            hline(x + 4, y - 1, 4);
            pixel(x + 8, y);
            vline(x + 9, y + 1, 7);
            pixel(x + 8, y + 8);
            hline(x + 4, y + 9, 4);
        }
    }

    fn inputBarButton(str: []const u8, x: i32, y: i32, held: bool) void {
        if (!held) {
            return;
        }

        color(0x3431);
        w4.text(str, x + 1, y + 1);
    }

    fn hudEnergyBar(game: *Game) void {
        const ship = game.ship;

        color(0x23);
        rect(143, 0, 18, 21 + (6 * @as(u32, ship.energy)));

        var eo: i32 = 0;

        if (ship.energy < 10) eo += 5;

        if (anyString(ship.energy)) |energyStr| {
            color(WHITE);
            w4.text(energyStr, 144 + eo, 3);
        } else |_| {}

        color(if (every(30)) 0x1320 else 0x4320);

        const zap = Sprite.zap;
        zap.blit(133, 10, zap.flags);

        for (0..ship.energy) |i| {
            const yo = @as(i32, @intCast(i)) * 6;

            color(GRAY);
            hline(148, 14 + yo, 8);
            hline(148, 17 + yo, 8);
            color(PRIMARY);
            hline(147, 15 + yo, 10);
            hline(147, 16 + yo, 10);
        }
    }

    fn hudInfoBar(game: *Game) void {
        if (anyString(game.distance)) |scoreStr| {
            title(CURRENCY, 9, 20, BLACK, PRIMARY);
            title(scoreStr, 18, 20, BLACK, WHITE);
        } else |_| {} // Nothing to do really if we get an error

        if (anyString(game.worldX)) |xStr| {
            title("@", 9, 28, BLACK, PRIMARY);
            title(xStr, 18, 28, BLACK, WHITE);
        } else |_| {} // Nothing to do really if we get an error
    }

    fn scoreString(arg: anytype) ![]u8 {
        const str = try std.fmt.allocPrint(allocator, "{any}", .{arg});
        defer allocator.free(str);

        return str;
    }

    // Tangerine Noir
    // https://lospec.com/palette-list/tangerine-noir
    palette: [4]u32 = .{
        0xfcfcfc, // White
        0x393541, // Gray
        0x191a1f, // Black
        0xee964b, // Tangerine
    },

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

    stars: [80][3]u8 = .{.{ 0, 0, 0 }} ** 80,
    stalactites: [128][3]i14 = .{.{ 0, 0, 0 }} ** 128,
    mountains: [64][4]i14 = .{.{ 0, 0, 0, 0 }} ** 64,

    ship: Ship = .{},

    worldX: i32 = 0,
    distance: i32 = 0,
    charges: u3 = 5,
};

const Ship = struct {
    facingRight: bool = true,
    offset: i7 = 0,
    speed: i6 = 2,
    lastSpeed: i6 = 0,
    energy: u4 = 0,

    fn update(ship: *Ship, game: *Game) void {
        if (ship.offset > -64 and @abs(ship.speed) > 0) {
            ship.facingRight = (ship.speed > 0);
        }

        if (s.button1()) {
            // TODO: Should we have some debug info?
        }

        if (s.button2()) {}

        var shouldLog = false;

        if (ship.offset > -64) {
            if (every(6) and s.buttonRightHeld()) {
                ship.speed +|= if (ship.speed < 0) 2 else 1;
                shouldLog = true;
            }

            if (every(6) and s.buttonLeftHeld()) {
                ship.speed -|= if (ship.speed > 0) 2 else 1;
                shouldLog = true;
            }

            if (every(2) and s.buttonDownHeld()) {
                ship.offset -|= 1;
                shouldLog = true;
            }
        } else {
            if (ship.facingRight) {
                if (ship.speed > 0) ship.speed -|= 1 else ship.speed = 0;
            } else {
                if (ship.speed < 0) ship.speed +|= 1 else ship.speed = 0;
            }
        }

        if (ship.energy > 0) {
            if (every(2) and s.buttonUpHeld() and ship.energy > 0) {
                ship.offset +|= 1;
                shouldLog = true;
            }
        }

        if (shouldLog) log(
            \\🌎 Distance | {d}
            \\🔋 Charges  | {d}
            \\⚡ Energy   | {d}
            \\🚀 Speed    | {d}
            \\   Offset   | {d}
            \\
        , .{
            game.distance,
            game.charges,
            ship.energy,
            ship.speed,
            ship.offset,
        });

        ship.lastSpeed = ship.speed;

        game.worldX +|= ship.speed;
        game.distance +|= @abs(ship.speed);

        if (ship.offset > -64) {
            if (every(100) and @abs(ship.speed) > 2) ship.energy -|= 1;
            if (every(200)) ship.energy -|= 1;

            if (ship.energy == 0 and every(3)) {
                ship.offset -|= 1;
            }
        }
    }

    fn draw(ship: *Ship, wx: i32, x: i32) void {
        const y = 80 - @as(i32, ship.offset);
        const f = @as(i32, @intCast(@mod(s.frame, 8)));

        if (ship.energy > 0) {
            const xo: i32 = if (ship.facingRight) 60 else 100;

            if ((ship.speed > 0 and ship.facingRight) or
                (ship.speed < 0 and !ship.facingRight))
            {
                const v1 = I(xo - f * @as(i32, ship.speed) - 3, y);
                const v2 = I(xo - f - 1 * @as(i32, ship.speed), y - 1);
                const v3 = I(xo - f * @as(i32, ship.speed), y);

                color(GRAY);
                v1.line(v2);
                v1.offset(1, 3).line(v2.offset(1, 3));
                color(WHITE);
                v3.line(v2);
                v3.offset(1, 3).line(v2.offset(1, 3));
                v1.offset(-2, -2).oval(4, 3);
                v1.offset(4, 2).oval(4, 3);
            }

            if (ship.speed == 0 and ship.offset > -64) {
                if (ship.facingRight) {
                    pixel(xo + 10, y + f);
                    pixel(xo + 8, y + f * 2);
                    pixel(xo + 6, y + f);
                } else {
                    pixel(xo - 10, y + f);
                    pixel(xo - 8, y + f * 2);
                    pixel(xo - 6, y + f);
                }
            }
        }

        if (ship.facingRight) {
            color(BLACK);
            line(x - 24, y - 5, x, y);

            triangle(.{
                I(x - 25, y - 5),
                I(x, y),
                I(x - 20, y + 6),
            }, wx, triPRIMARY);

            triangle(.{
                I(x - 21, y - 6),
                I(x - 5, y + 1),
                I(x - 18, y + 1),
            }, wx, triWHITE);

            color(GRAY);
            line(x - 18, y, x - 20, y - 5);

            color(GRAY);
            line(x - 19, y + 6, x, y);

            if (ship.speed > 0) {
                color(GRAY);
                vpx(I(78 - f * @as(i32, ship.speed), y - 3));
            }
        } else {
            color(BLACK);
            line(-20 + x + 25, y - 5, x, y);

            triangle(.{
                I(-20 + x, y),
                I(-20 + x + 25, y - 5),
                I(-20 + x + 20, y + 6),
            }, wx, triPRIMARY);

            triangle(.{
                I(-20 + x + 5, y),
                I(-20 + x + 21, y - 6),
                I(-20 + x + 18, y + 1),
            }, wx, triWHITE);

            color(GRAY);
            line(x - 20, y, x, y + 6);

            if (ship.speed < 0) {
                color(GRAY);
                vpx(I(78 - f * @as(i32, ship.speed), y - 3));
            }
        }
    }
};

const Over = struct {
    // Tangerine Noir
    // https://lospec.com/palette-list/tangerine-noir
    palette: [4]u32 = .{
        0xfcfcfc, // White
        0x393541, // Gray
        0x191a1f, // Black
        0xee964b, // Tangerine
    },

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

    birdSound: Tone = Tone{
        .freq1 = 980,
        .freq2 = 800,
        .attack = 10,
        .decay = 0,
        .sustain = 5,
        .release = 20,
        .peak = 8,
        .volume = 6,
        .mode = 2,
    },

    snowParticlesOver: [64]Particle = [_]Particle{.{}} ** 64,
    snowParticlesBehind: [128]Particle = [_]Particle{.{}} ** 128,

    deathFlipped: bool = false,
    pressFlipped: bool = false,

    fn enter(over: *Over) !void {
        w4.PALETTE.* = over.palette;

        const r = rnd.random();

        // Random positions for the snow particles over
        for (0.., over.snowParticlesOver) |i, _| {
            over.snowParticlesOver[i] = P(
                r.float(f32) * 160,
                r.float(f32) * 160,
                @floatFromInt(45),
                5 + r.float(f32) * 15,
                10,
            );
        }

        // Random positions for the snow particles behind
        for (0.., over.snowParticlesBehind) |i, _| {
            over.snowParticlesBehind[i] = P(
                r.float(f32) * 160,
                r.float(f32) * 160,
                @floatFromInt(45),
                5 + r.float(f32) * 15,
                10,
            );
        }
    }

    fn update(over: *Over) !void {
        if (s.button1()) {
            s.transition(INTRO);
        }

        over.updateSnow();

        if (every(120)) over.deathFlipped = !over.deathFlipped;
        if (every(30)) over.pressFlipped = !over.pressFlipped;
        if (every(400)) over.sound.play(2);

        if (s.mouseLeftHeld()) {
            const v1 = V(20, 128).offset(10, 5);
            const v2 = V(134, 138).offset(5, 10);

            if (s.m.distance(v1) < 8) over.birdSound.play(0);
            if (s.m.distance(v2) < 8) over.birdSound.play(1);
        }
    }

    fn draw(over: *Over) !void {
        clear(GRAY);

        color(WHITE);
        V(0, 130).rect(160, 30);

        const death = Sprite.death;

        var flags = death.flags;

        if (over.deathFlipped) {
            flags |= w4.BLIT_FLIP_X;
        }

        over.snowBehind();

        flyingBirds(s.frame);

        eatingBird(s.frame, 24, 128);
        idleBird(s.frame, 134, 138);

        const fg: u16 = if (over.pressFlipped) PRIMARY else WHITE;

        title("PRESS\n\x80to\nINTRO", 104, 105, BLACK, fg);

        const fir = Sprite.fir;

        color(0x20);
        fir.blit(142, 107, fir.flags | w4.BLIT_FLIP_X);

        color(0x10);
        fir.blit(142, 106, fir.flags | w4.BLIT_FLIP_X);

        title("|:.:* .*.,*_*", -4, 125, GRAY, GRAY);
        title("*_*,.**,.|::", -7, 123, GRAY, GRAY);

        color(0x4301);
        death.blit(40, 15, flags);

        const coffee = Sprite.coffee;

        color(0x4302);
        coffee.blit(38, 134, coffee.flags);
        color(BLACK);
        V(43, 137).rect(2, 2);

        triangle(T(30, 95, 40, 129, 16, 132), 0, triFir);

        color(0x20);
        fir.blit(-10, 116, fir.flags);

        color(0x10);
        fir.blit(-12, 115, fir.flags);

        over.snowOver();

        title("The SYLT is OVER!!", 8, 3, PRIMARY, WHITE);
    }

    fn snowBehind(over: *Over) void {
        for (0.., over.snowParticlesBehind) |i, p| {
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

    fn snowOver(over: *Over) void {
        for (0.., over.snowParticlesOver) |i, p| {
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

    fn updateSnow(over: *Over) void {
        const r = rnd.random();

        for (0.., over.snowParticlesOver) |i, p| {
            var n = p.update(0.1);

            n.position.data[0] = @mod(n.position.data[0], 165);
            n.position.data[1] = @mod(n.position.data[1], 165);

            if (n.life < 0) {
                n.life = r.float(f32) * 10;
            }

            over.snowParticlesOver[i] = n;
        }

        for (0.., over.snowParticlesBehind) |i, p| {
            var n = p.update(0.1);

            n.position.data[0] = @mod(n.position.data[0], 165);
            n.position.data[1] = @mod(n.position.data[1], 165);

            if (n.life < 0) {
                n.life = r.float(f32) * 10;
            }

            over.snowParticlesBehind[i] = n;
        }
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

fn every(f: u32) bool {
    return @mod(s.frame, f) == 0;
}

const TM = "\xAE";
const CURRENCY = "\xA4";

// The colors
const WHITE: u16 = 0x0001;
const GRAY: u16 = 0x0002;
const BLACK: u16 = 0x0003;
const PRIMARY: u16 = 0x0004;

fn triWHITE(wx: i32, _: Vec, _: Vec, _: f32, _: f32, _: f32) u16 {
    _ = wx;
    return WHITE;
}

fn triGRAY(wx: i32, _: Vec, _: Vec, _: f32, _: f32, _: f32) u16 {
    _ = wx;
    return GRAY;
}

fn triBLACK(wx: i32, _: Vec, _: Vec, _: f32, _: f32, _: f32) u16 {
    _ = wx;
    return BLACK;
}

fn triPRIMARY(wx: i32, _: Vec, _: Vec, _: f32, _: f32, _: f32) u16 {
    _ = wx;
    return PRIMARY;
}

fn triFir(wx: i32, p: Vec, _: Vec, _: f32, _: f32, _: f32) u16 {
    _ = wx;
    const x = p.xu();
    const y = p.yu();

    const f: u16 = @intCast(@abs(@mod(s.frame, 64) / 32) + 1);

    if (@mod(y, 4) == 0) {
        return WHITE;
    }

    return if ((@mod((y ^ x) ^ f, 8) / 3) > 0) WHITE else GRAY;
}

// The scene indexes
const INTRO: u2 = 0;
const GAME: u2 = 1;
const OVER: u2 = 2;

// Proxy functions for w4

fn title(str: []const u8, x: i32, y: i32, bg: u16, fg: u16) void {
    color(bg);
    w4.text(str, x, y);
    color(fg);
    w4.text(str, x + 1, y + 1);
}

fn title2(str: []const u8, x: i32, y: i32, bg: u16, fg: u16) void {
    color(bg);
    w4.text(str, x, y);
    color(fg);
    w4.text(str, x - 1, y);
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
    pixel(v.xi(), v.yi());
}

fn ppx(p: Particle) void {
    vpx(p.position);
}

fn upx(x: usize, y: usize) void {
    pixel(@intCast(x), @intCast(y));
}

fn pixel(x: i32, y: i32) void {
    if (x < 0 or x > 160 or y < 0 or y > 160) {
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

fn centroid(t: [3]Vec) Vec {
    return V(
        (t[0].x() + t[1].x() + t[2].x()) / 3,
        (t[0].y() + t[1].y() + t[2].y()) / 3,
    );
}

const ColorFn = fn (wx: i32, p: Vec, c: Vec, alpha: f32, beta: f32, gamma: f32) u16;

fn triangle(t: [3]Vec, wx: i32, colorFn: *const ColorFn) void {
    const area = Vec.cross(t[0], t[1], t[2]);
    const center = centroid(t);

    const bias0: f32 = if (isTopLeft(t[1], t[2])) 0 else -0.0001;
    const bias1: f32 = if (isTopLeft(t[2], t[0])) 0 else -0.0001;
    const bias2: f32 = if (isTopLeft(t[0], t[1])) 0 else -0.0001;

    const xMin: usize = @intFromFloat(@min(@min(t[0].x(), t[1].x()), t[2].x()));
    const xMax: usize = @intFromFloat(@max(@max(t[0].x(), t[1].x()), t[2].x()));

    const yMin: usize = @intFromFloat(@min(@min(t[0].y(), t[1].y()), t[2].y()));
    const yMax: usize = @intFromFloat(@max(@max(t[0].y(), t[1].y()), t[2].y()));

    for (yMin..yMax) |y| {
        for (xMin..xMax) |x| {
            var pos = V(@floatFromInt(x), @floatFromInt(y));

            const w0 = pos.cross(t[0], t[1]) + bias0;
            const w1 = pos.cross(t[1], t[2]) + bias1;
            const w2 = pos.cross(t[2], t[0]) + bias2;

            if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                const alpha = w0 / area;
                const beta = w1 / area;
                const gamma = w2 / area;

                color(colorFn(wx, pos, center, alpha, beta, gamma));
                pixel(@intCast(x), @intCast(y));
            }
        }
    }
}

fn isTopLeft(a: Vec, b: Vec) bool {
    var edge = V(b.x() - a.x(), b.y() - a.y());
    var is_top_edge = (edge.y() == 0) and (edge.x() > 0);
    var is_left_edge = edge.y() < 0;

    return is_top_edge or is_left_edge;
}

fn dotline(a: Vec, b: Vec, dotSize: u32, points: []const f32) void {
    const fsize: f32 = @floatFromInt(dotSize);
    const offset = Vec.set(@divFloor(fsize, 2));

    for (points) |p| {
        a.lerp(b, p).sub(offset).rect(dotSize, dotSize);
    }
}

fn anyString(arg: anytype) ![]u8 {
    const str = try std.fmt.allocPrint(allocator, "{any}", .{arg});
    defer allocator.free(str);

    return str;
}

fn any(arg: anytype, x: i32, y: i32, bg: u16, fg: u16) !void {
    const str = try std.fmt.allocPrint(allocator, "{any}", .{arg});
    defer allocator.free(str);

    title(str, x, y, bg, fg);
}

pub fn log(comptime format: []const u8, args: anytype) void {
    const str = std.fmt.allocPrint(allocator, format, args) catch return;
    defer allocator.free(str);
    w4.trace(str);
}

// Animations

fn flyingBirds(f: u32) void {
    const bird = Sprite.bird_flying;
    const birdFrame = @as(u32, @mod(f, 14) / 2);
    color(0x3340);
    w4.blitSub(bird.sprite, @intCast(592 - @mod(f, 592) - 32), 30, 16, 16, birdFrame * 16, 0, bird.width, bird.flags);
    w4.blitSub(bird.sprite, @intCast(@mod(f, 692) - 32), 10, 16, 16, birdFrame * 16, 0, bird.width, bird.flags | w4.BLIT_FLIP_X);
}

fn eatingBird(f: u32, x: i32, y: i32) void {
    const bird = Sprite.bird_eating;
    const birdFrame = @as(u32, @mod(f, 128) / 64);
    color(0x3340);
    w4.blitSub(bird.sprite, x, y, 16, 16, birdFrame * 16, 0, bird.width, bird.flags | w4.BLIT_FLIP_X);
}

fn idleBird(f: u32, x: i32, y: i32) void {
    const bird = Sprite.bird_idle;
    const birdFrame = @as(u32, @mod(f, 256) / 128);
    color(0x3340);
    w4.blitSub(bird.sprite, x, y, 16, 16, birdFrame * 16, 0, bird.width, bird.flags);
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
