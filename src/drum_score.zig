const std = @import("std");
const lightmix = @import("lightmix");
const Self = @This();

const Wave = lightmix.Wave;

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

pub fn finalize(self: *Self) Wave {
    if (self.notes.len == 0) {
        const empty_data = self.allocator.alloc(f32, 0) catch @panic("Out of memory");
        return Wave.init(empty_data, self.allocator, .{
            .sample_rate = self.sample_rate,
            .channels = self.channels,
            .bits = self.bits,
        });
    }

    var total_len: usize = 0;
    for (self.notes, 0..) |note, i| {
        const end_pos = i * self.samples_per_score + note.len;
        if (end_pos > total_len)
            total_len = end_pos;
    }

    const data: []f32 = self.allocator.alloc(f32, total_len) catch @panic("Out of memory");
    defer self.allocator.free(data);
    @memset(data, 0);

    for (self.notes, 0..) |note, i| {
        const offset = i * self.samples_per_score;
        for (note, 0..) |sample, j| {
            data[offset + j] += sample;
        }
    }

    const result: Wave = Wave.init(data, self.allocator, .{
        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    });

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

    const mixed: Wave = score.finalize();
    defer mixed.deinit();

    try std.testing.expectEqualSlices(f32, mixed.data, &[_]f32{ 1.0, 2.0, 3.0, 2.0, 1.0 });
}
