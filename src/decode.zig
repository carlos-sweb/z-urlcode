const std = @import("std");
const Allocator = std.mem.Allocator;
const isUriReserved = @import("charset.zig").isUriReserved;
const UrlcodeError = @import("errors.zig").DecodeError;

fn hexDigit(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'A'...'F' => c - 'A' + 10,
        'a'...'f' => c - 'a' + 10,
        else => null,
    };
}

fn hexByte(hi: u8, lo: u8) UrlcodeError!u8 {
    const h = hexDigit(hi) orelse return error.MalformedUri;
    const l = hexDigit(lo) orelse return error.MalformedUri;
    return (h << 4) | l;
}

/// How many bytes (including this leading one) the UTF-8 sequence starting
/// with `b0` should have -- null for a byte that can't lead a sequence
/// (0x80-0xBF: stray continuation byte; 0xF8-0xFF: not valid UTF-8).
fn utf8SeqLen(b0: u8) ?u3 {
    if (b0 & 0x80 == 0) return 1;
    if (b0 & 0xE0 == 0xC0) return 2;
    if (b0 & 0xF0 == 0xE0) return 3;
    if (b0 & 0xF8 == 0xF0) return 4;
    return null;
}

/// Reads one `%XY` triplet at `s[pos..]`, returning the decoded byte.
/// Bounds-checked: a truncated triplet or a missing `%` is `MalformedUri`,
/// matching the spec's "k + 2 >= length" check.
fn readPercentByte(s: []const u8, pos: usize) UrlcodeError!u8 {
    if (pos + 3 > s.len or s[pos] != '%') return error.MalformedUri;
    return hexByte(s[pos + 1], s[pos + 2]);
}

/// ECMA-262 19.2.6.6's Decode operation. `reservedSet` is
/// `uriReserved + "#"` when `keep_reserved` is true (`decodeURI`) or empty
/// when false (`decodeURIComponent`) -- a reserved-set `%XY` is copied
/// through verbatim instead of being unescaped.
/// Input must be valid UTF-8; literal bytes are copied without validation.
/// Returns an owned slice; the caller must free it with `allocator`.
/// Invalid escapes return `error.MalformedUri`; allocation can return `error.OutOfMemory`.
pub fn decode(allocator: Allocator, s: []const u8, keep_reserved: bool) UrlcodeError![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < s.len) {
        if (s[i] != '%') {
            try out.append(allocator, s[i]);
            i += 1;
            continue;
        }

        const b0 = try readPercentByte(s, i);
        const n = utf8SeqLen(b0) orelse return error.MalformedUri;

        if (n == 1) {
            if (keep_reserved and (isUriReserved(b0) or b0 == '#')) {
                try out.appendSlice(allocator, s[i .. i + 3]);
            } else {
                try out.append(allocator, b0);
            }
            i += 3;
            continue;
        }

        var octets: [4]u8 = undefined;
        octets[0] = b0;
        var pos = i + 3;
        var k: u3 = 1;
        while (k < n) : (k += 1) {
            octets[k] = try readPercentByte(s, pos);
            if (octets[k] & 0xC0 != 0x80) return error.MalformedUri;
            pos += 3;
        }

        // Rejects overlong encodings, codepoints > U+10FFFF, and encoded
        // surrogate halves (U+D800-U+DFFF) -- the exact set the spec's
        // Decode algorithm requires URIError for, all validated by
        // std.unicode's decoders rather than hand-rolled here.
        _ = switch (n) {
            2 => std.unicode.utf8Decode2(octets[0..2].*),
            3 => std.unicode.utf8Decode3(octets[0..3].*),
            4 => std.unicode.utf8Decode4(octets[0..4].*),
            else => unreachable,
        } catch return error.MalformedUri;

        try out.appendSlice(allocator, octets[0..n]);
        i = pos;
    }

    return out.toOwnedSlice(allocator);
}
