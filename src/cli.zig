const std = @import("std");

pub const Options = struct {
    path: []const u8 = ".",
    extensions: []const []const u8 = &.{},
    recursive: bool = false,
    verbose: bool = false,
    dry_run: bool = false,
};

pub const ParseResult = union(enum) {
    options: Options,
    help,
};

pub fn parse(args: anytype, allocator: std.mem.Allocator) !ParseResult {
    var it = args;
    var options = Options{};
    var extensions = std.ArrayList([]const u8).empty;
    defer extensions.deinit(allocator);

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) return .help;
        if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--recursive")) {
            options.recursive = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            options.verbose = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--dry-run")) {
            options.dry_run = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "-e") or std.mem.eql(u8, arg, "--extensions")) {
            const value = it.next() orelse return error.MissingValue;
            try extensions.append(allocator, normalizeExtension(value));
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--extensions=")) {
            try extensions.append(allocator, normalizeExtension(arg[13..]));
            continue;
        }
        if (std.mem.startsWith(u8, arg, "-e=")) {
            try extensions.append(allocator, normalizeExtension(arg[3..]));
            continue;
        }
        if (arg.len > 0 and arg[0] == '-') return error.UnknownOption;
        if (!std.mem.eql(u8, options.path, ".")) return error.InvalidOption;
        options.path = arg;
    }

    options.extensions = try extensions.toOwnedSlice(allocator);
    return .{ .options = options };
}

fn normalizeExtension(value: []const u8) []const u8 {
    return value;
}

pub fn printHelp() void {
    std.debug.print(
        "Usage: tidyname [PATH] [OPTIONS]\n\n" ++
            "Clean, normalize, and transliterate file names.\n\n" ++
            "Arguments:\n" ++
            "  PATH                 Directory to process (default: .)\n\n" ++
            "Options:\n" ++
            "  -e, --extensions EXT Process only files with this extension; repeatable\n" ++
            "  -r, --recursive      Process subdirectories recursively\n" ++
            "  -v, --verbose        Print planned changes\n" ++
            "      --dry-run        Preview changes without renaming\n" ++
            "  -h, --help           Show this help\n\n" ++
            "Examples:\n" ++
            "  tidyname\n" ++
            "  tidyname ./downloads --dry-run -v\n" ++
            "  tidyname ./downloads -r -e csv -e txt\n",
        .{},
    );
}
