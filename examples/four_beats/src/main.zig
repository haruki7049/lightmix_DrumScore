const std = @import("std");
const lightmix = @import("lightmix");
const lightmix_drum_score = @import("lightmix_drum_score");

const Wave = lightmix.Wave;
const DrumScore = lightmix_drum_score.DrumScore;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var score: DrumScore = DrumScore.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
        .samples_per_score = 22050,
    });
    defer score.deinit();

    const sinewave: Wave = Sinewave.generate(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,

        .frequency = 440.0,
        .initial_volume = 1.0,
        .length = 22050,
    });
    defer sinewave.deinit();

    score.register(&[_]Wave{
        sinewave,
        sinewave,
        sinewave,
        sinewave,
    });

    const mixed: Wave = score.finalize().filter(normalize);
    defer mixed.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try mixed.write(file);
}

const Sinewave = struct {
    const initOptions = struct {
        sample_rate: usize,
        channels: usize,
        bits: usize,

        frequency: f32,
        initial_volume: f32,
        length: usize,
    };

    fn generate(allocator: std.mem.Allocator, options: initOptions) Wave {
        const data: []const f32 = generate_sinewave_data(allocator, options);
        return Wave.init(data, allocator, .{
            .sample_rate = options.sample_rate,
            .channels = options.channels,
            .bits = options.bits,
        });
    }

    fn generate_sinewave_data(allocator: std.mem.Allocator, options: initOptions) []f32 {
        const radins_per_sec: f32 = options.frequency * 2.0 * std.math.pi;

        var result: []f32 = allocator.alloc(f32, options.length) catch @panic("Out of memory");
        var i: usize = 0;

        while (i < result.len) : (i += 1) {
            const progress = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(result.len));
            const current_volume = options.initial_volume * (1.0 - progress);

            const sin_value = std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / @as(f32, @floatFromInt(options.sample_rate)));
            result[i] = sin_value * current_volume;
        }

        return result;
    }
};

fn normalize(original_wave: Wave) !Wave {
    var result: std.array_list.Aligned(f32, null) = .empty;

    var max_volume: f32 = 0.0;
    for (original_wave.data) |sample| {
        if (sample > max_volume)
            max_volume = sample;
    }

    for (original_wave.data) |sample| {
        const volume: f32 = 1.0 / max_volume;

        const new_sample: f32 = sample * volume;
        try result.append(original_wave.allocator, new_sample);
    }

    return Wave{
        .data = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
        .bits = original_wave.bits,
    };
}
