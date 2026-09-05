const std = @import("std");
const cli = @import("cli.zig");
const filesystem = @import("filesystem.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var args = init.minimal.args.iterate();
    _ = args.next();

    const parsed = cli.parse(args, allocator) catch |err| {
        cli.printHelp();
        return err;
    };

    switch (parsed) {
        .help => cli.printHelp(),
        .options => |options| {
            if (options.path.len == 0) return error.InvalidDirectory;

            var root = std.Io.Dir.cwd();
            const stat = root.statFile(init.io, options.path, .{}) catch return error.InvalidDirectory;
            if (stat.kind != .directory) return error.InvalidDirectory;

            const report = try filesystem.process(allocator, init.io, options.path, .{
                .recursive = options.recursive,
                .verbose = options.verbose,
                .dry_run = options.dry_run,
                .extensions = options.extensions,
            });

            std.debug.print(
                "Processed: {d}, unchanged: {d}, skipped: {d}, failed: {d}\n",
                .{ report.renamed, report.unchanged, report.skipped, report.failed },
            );
        },
    }
}

test {
    _ = @import("transform.zig");
}
