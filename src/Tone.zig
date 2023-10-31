const w4 = @import("wasm4.zig");

const Self = @This();

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

// Tone can play itself
pub fn play(t: Self, channel: u32) void {
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
