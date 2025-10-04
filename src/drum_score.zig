const std = @import("std");
const lightmix = @import("lightmix");
const Self = @This();

allocator: std.mem.Allocator,
sample_rate: usize,
channels: usize,
bits: usize,
samples_per_score: usize,
notes: [][]const f32,

const initOptions = struct {
    sample_rate: usize,
    channels: usize,
    bits: usize,
    samples_per_score: usize,
};

pub fn init(allocator: std.mem.Allocator, options: initOptions) Self {
    return Self{
        .allocator = allocator,
        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
        .samples_per_score = options.samples_per_score,
        .notes = &[_][]const f32{},
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.notes);
}

pub fn register(self: *Self, notes: []const []const f32) void {
    const owned_notes = self.allocator.alloc([]const f32, notes.len) catch @panic("Out of memory");
    @memcpy(owned_notes, notes);

    self.notes = owned_notes;
}

pub fn finalize(self: *Self) []f32 {
    if (self.notes.len == 0) return &[_]f32{};

    const note_len = self.notes[0].len;
    const total_len = note_len + (self.notes.len - 1) * self.samples_per_score;
    const result = self.allocator.alloc(f32, total_len) catch @panic("Out of memory");
    @memset(result, 0);

    for (self.notes, 0..) |note, i| {
        const offset = i * self.samples_per_score;
        for (note, 0..) |sample, j| {
            result[offset + j] += sample;
        }
    }

    return result;
}

test "init" {
    const allocator = std.testing.allocator;
    _ = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
        .samples_per_score = 22050,
    });
}

test "init & deinit" {
    const allocator = std.testing.allocator;
    const score = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
        .samples_per_score = 22050,
    });
    defer score.deinit();
}

test "register" {
    const allocator = std.testing.allocator;
    var score: Self = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
        .samples_per_score = 22050,
    });
    defer score.deinit();

    score.register(&[_][]const f32{
        &[_]f32{ 1.0, 1.0, 1.0 },
        &[_]f32{ 1.0, 1.0, 1.0 },
        &[_]f32{ 1.0, 1.0, 1.0 },
    });

    try std.testing.expectEqualSlices(f32, score.notes[0], &[_]f32{ 1.0, 1.0, 1.0 });
    try std.testing.expectEqualSlices(f32, score.notes[1], &[_]f32{ 1.0, 1.0, 1.0 });
    try std.testing.expectEqualSlices(f32, score.notes[2], &[_]f32{ 1.0, 1.0, 1.0 });
}

test "finalize" {
    const allocator = std.testing.allocator;
    var score = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
        .samples_per_score = 1,
    });
    defer score.deinit();

    score.register(&[_][]const f32{
        &[_]f32{ 1.0, 1.0, 1.0 },
        &[_]f32{ 1.0, 1.0, 1.0 },
        &[_]f32{ 1.0, 1.0, 1.0 },
    });

    const mixed = score.finalize();
    defer allocator.free(mixed);

    try std.testing.expectEqualSlices(f32, mixed, &[_]f32{ 1.0, 2.0, 3.0, 2.0, 1.0 });
}
