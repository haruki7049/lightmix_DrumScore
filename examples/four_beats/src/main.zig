const std = @import("std");
const lightmix = @import("lightmix");
const lightmix_drum_score = @import("lightmix_drum_score");

const allocator = std.heap.page_allocator;
const Wave = lightmix.Wave;
const DrumScore = lightmix_drum_score.DrumScore;

pub fn main() !void {
    var score: DrumScore = DrumScore.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
        .samples_per_score = 22050,
    });
    defer score.deinit();

    score.register(&[_][]const f32{
        &generate_sinewave_data(),
        &generate_sinewave_data(),
        //&generate_sinewave_data(),
        //&generate_sinewave_data(),
    });

    const mixed: Wave = score.finalize().filter(normalize);
    defer mixed.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try mixed.write(file);
}

fn generate_sinewave_data() [44100]f32 {
    const c_5: f32 = 523.251;
    const volume: f32 = 1.0;
    const sample_rate: f32 = 44100.0;
    const radins_per_sec: f32 = c_5 * 2.0 * std.math.pi;

    var result: [44100]f32 = undefined;
    var i: usize = 0;

    while (i < result.len) : (i += 1) {
        result[i] = std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate) * volume;
    }

    return result;
}

fn normalize(original_wave: Wave) !Wave {
    var result = std.ArrayList(f32).init(original_wave.allocator);

    var max_volume: f32 = 0.0;
    for (original_wave.data) |sample| {
        if (sample > max_volume)
            max_volume = sample;
    }

    for (original_wave.data) |sample| {
        const volume: f32 = 1.0 / max_volume;

        const new_sample: f32 = sample * volume;
        try result.append(new_sample);
    }

    return Wave{
        .data = try result.toOwnedSlice(),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
        .bits = original_wave.bits,
    };
}
