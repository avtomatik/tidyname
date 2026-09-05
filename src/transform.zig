const std = @import("std");

pub fn transformFilename(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const dot = extensionSeparator(filename);
    const stem = if (dot) |i| filename[0..i] else filename;
    const extension = if (dot) |i| filename[i..] else "";

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    try appendNormalizedStem(&out, allocator, stem);
    try appendLowercaseAscii(&out, allocator, extension);
    return out.toOwnedSlice(allocator);
}

fn appendLowercaseAscii(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    input: []const u8,
) !void {
    for (input) |byte| {
        const lower = if (byte >= 'A' and byte <= 'Z')
            byte + ('a' - 'A')
        else
            byte;
        try out.append(allocator, lower);
    }
}

fn extensionSeparator(filename: []const u8) ?usize {
    if (filename.len == 0 or filename[0] == '.') return null;
    var i = filename.len;
    while (i > 0) {
        i -= 1;
        if (filename[i] == '.') {
            if (i == 0) return null;
            return i;
        }
        if (filename[i] == '/' or filename[i] == '\\') break;
    }
    return null;
}

fn appendNormalizedStem(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    input: []const u8,
) !void {
    var started = false;
    var underscore_pending = false;
    var index: usize = 0;

    while (index < input.len) {
        const sequence_len = std.unicode.utf8ByteSequenceLength(input[index]) catch {
            index += 1;
            underscore_pending = true;
            continue;
        };
        if (index + sequence_len > input.len) {
            index += 1;
            underscore_pending = true;
            continue;
        }
        const cp = std.unicode.utf8Decode(input[index .. index + sequence_len]) catch {
            index += 1;
            underscore_pending = true;
            continue;
        };
        index += sequence_len;

        if (cp == ' ' or cp == '\t' or cp == '\n' or cp == '\r' or isSeparator(cp)) {
            underscore_pending = started;
            continue;
        }

        if (transliteration(cp)) |replacement| {
            if (underscore_pending and started) try out.append(allocator, '_');
            underscore_pending = false;
            try out.appendSlice(allocator, replacement);
            started = true;
            continue;
        }

        if (isAsciiWord(cp) or (cp >= 'A' and cp <= 'Z')) {
            if (underscore_pending and started) try out.append(allocator, '_');
            underscore_pending = false;
            const lower = if (cp >= 'A' and cp <= 'Z')
                cp + ('a' - 'A')
            else
                cp;
            try out.append(allocator, @intCast(lower));
            started = true;
            continue;
        }

        if (cp == '_') {
            if (underscore_pending and started) try out.append(allocator, '_');
            underscore_pending = false;
            try out.append(allocator, '_');
            started = true;
            continue;
        }

        underscore_pending = started;
    }

    while (out.items.len > 0 and out.items[out.items.len - 1] == '_') {
        _ = out.pop();
    }
}

fn isSeparator(cp: u21) bool {
    return cp == '-' or cp == '—' or cp == '–' or cp == '(' or cp == ')' or
        cp == '[' or cp == ']' or cp == '{' or cp == '}' or cp == ',' or
        cp == ';' or cp == ':' or cp == '!' or cp == '?' or cp == '/' or
        cp == '\\' or cp == '@' or cp == '#' or cp == '$' or cp == '%' or
        cp == '^' or cp == '&' or cp == '*' or cp == '=' or cp == '+' or
        cp == '<' or cp == '>' or cp == '|' or cp == '~' or cp == '`' or cp == '"' or cp == '\'';
}

fn isAsciiWord(cp: u21) bool {
    return (cp >= 'a' and cp <= 'z') or
        (cp >= '0' and cp <= '9');
}

fn transliteration(cp: u21) ?[]const u8 {
    return switch (cp) {
        'а', 'А' => "a",
        'б', 'Б' => "b",
        'в', 'В' => "v",
        'г', 'Г' => "g",
        'д', 'Д' => "d",
        'е', 'Е' => "e",
        'ё', 'Ё' => "yo",
        'ж', 'Ж' => "zh",
        'з', 'З' => "z",
        'и', 'И' => "i",
        'й', 'Й' => "y",
        'к', 'К' => "k",
        'л', 'Л' => "l",
        'м', 'М' => "m",
        'н', 'Н' => "n",
        'о', 'О' => "o",
        'п', 'П' => "p",
        'р', 'Р' => "r",
        'с', 'С' => "s",
        'т', 'Т' => "t",
        'у', 'У' => "u",
        'ф', 'Ф' => "f",
        'х', 'Х' => "kh",
        'ц', 'Ц' => "ts",
        'ч', 'Ч' => "ch",
        'ш', 'Ш' => "sh",
        'щ', 'Щ' => "shch",
        'ъ', 'Ъ' => null,
        'ы', 'Ы' => "y",
        'ь', 'Ь' => null,
        'э', 'Э' => "e",
        'ю', 'Ю' => "yu",
        'я', 'Я' => "ya",
        else => null,
    };
}

test "transliterates Russian Cyrillic" {
    const allocator = std.testing.allocator;
    const got = try transformFilename(allocator, "отчёт_январь.csv");
    defer allocator.free(got);
    try std.testing.expectEqualStrings("otchyot_yanvar.csv", got);
}

test "cleans separators and repeated boundaries" {
    const allocator = std.testing.allocator;
    const got = try transformFilename(allocator, "hello - world!.txt");
    defer allocator.free(got);
    try std.testing.expectEqualStrings("hello_world.txt", got);
}

test "normalizes extension case" {
    const allocator = std.testing.allocator;
    const got = try transformFilename(allocator, "Пример.TXT");
    defer allocator.free(got);
    try std.testing.expectEqualStrings("primer.txt", got);
}
