const std = @import("std");
const transform = @import("transform.zig");

pub const Options = struct {
    recursive: bool,
    verbose: bool,
    dry_run: bool,
    extensions: []const []const u8,
};

pub const Report = struct {
    renamed: usize = 0,
    unchanged: usize = 0,
    skipped: usize = 0,
    failed: usize = 0,
};

pub fn process(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    options: Options,
) !Report {
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var report = Report{};
    if (options.recursive) {
        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next(io)) |entry| {
            if (entry.kind != .file) continue;
            const relative = entry.path;
            if (!acceptFile(relative, options.extensions)) {
                report.skipped += 1;
                continue;
            }
            switch (try processOne(allocator, io, dir, relative, options)) {
                .renamed => report.renamed += 1,
                .unchanged => report.unchanged += 1,
                .skipped => report.skipped += 1,
            }
        }
    } else {
        var iterator = dir.iterate();
        while (try iterator.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!acceptFile(entry.name, options.extensions)) {
                report.skipped += 1;
                continue;
            }
            switch (try processOne(allocator, io, dir, entry.name, options)) {
                .renamed => report.renamed += 1,
                .unchanged => report.unchanged += 1,
                .skipped => report.skipped += 1,
            }
        }
    }
    return report;
}

const Result = enum { renamed, unchanged, skipped };

fn acceptFile(path: []const u8, extensions: []const []const u8) bool {
    if (extensions.len == 0) return true;

    const base = std.fs.path.basename(path);
    const dot = std.mem.lastIndexOfScalar(u8, base, '.') orelse return false;
    if (dot == 0 or dot + 1 >= base.len) return false;

    const extension = base[dot + 1 ..];
    for (extensions) |wanted_raw| {
        const wanted = if (wanted_raw.len > 0 and wanted_raw[0] == '.') wanted_raw[1..] else wanted_raw;
        if (std.mem.eql(u8, extension, wanted)) return true;
    }
    return false;
}

fn processOne(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    relative_path: []const u8,
    options: Options,
) !Result {
    const base_name = std.fs.path.basename(relative_path);
    if (base_name.len > 0 and base_name[0] == '.') return .skipped;

    const new_name = try transform.transformFilename(allocator, base_name);
    defer allocator.free(new_name);

    if (std.mem.eql(u8, base_name, new_name)) return .unchanged;

    const parent = std.fs.path.dirname(relative_path) orelse ".";
    var candidate = try std.fs.path.join(allocator, &.{ parent, new_name });

    var suffix: usize = 1;
    while (true) {
        if (options.verbose or options.dry_run) {
            std.debug.print("{s} -> {s}\n", .{ relative_path, candidate });
        }

        if (options.dry_run) {
            allocator.free(candidate);
            return .renamed;
        }

        dir.renamePreserve(relative_path, dir, candidate, io) catch |err| switch (err) {
            error.PathAlreadyExists, error.DirNotEmpty => {
                allocator.free(candidate);
                candidate = try collisionName(allocator, parent, new_name, suffix);
                suffix += 1;
                continue;
            },
            else => {
                allocator.free(candidate);
                return err;
            },
        };
        allocator.free(candidate);
        return .renamed;
    }
}

fn collisionName(
    allocator: std.mem.Allocator,
    parent: []const u8,
    filename: []const u8,
    suffix: usize,
) ![]u8 {
    const ext_start = extensionSeparator(filename);
    const stem = if (ext_start) |i| filename[0..i] else filename;
    const ext = if (ext_start) |i| filename[i..] else "";

    var suffix_buf: [32]u8 = undefined;
    const suffix_text = try std.fmt.bufPrint(&suffix_buf, "_{d}", .{suffix});
    const name = try std.mem.concat(allocator, u8, &.{ stem, suffix_text, ext });
    defer allocator.free(name);
    return std.fs.path.join(allocator, &.{ parent, name });
}

fn extensionSeparator(filename: []const u8) ?usize {
    if (filename.len == 0 or filename[0] == '.') return null;
    var i = filename.len;
    while (i > 0) {
        i -= 1;
        if (filename[i] == '.') return if (i == 0) null else i;
    }
    return null;
}
