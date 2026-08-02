const std = @import("std");
const testing = std.testing;
const zurlcode = @import("zurlcode");

fn expectEncode(expected: []const u8, s: []const u8, comptime set: zurlcode.CharSet) !void {
    const got = try zurlcode.encode(testing.allocator, s, set);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

fn expectDecode(expected: []const u8, s: []const u8, keep_reserved: bool) !void {
    const got = try zurlcode.decode(testing.allocator, s, keep_reserved);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

fn expectDecodeError(s: []const u8, keep_reserved: bool) !void {
    try testing.expectError(error.MalformedUri, zurlcode.decode(testing.allocator, s, keep_reserved));
}

// -- encodeURI: uriUnescaped + uriReserved + "#" pass through -------------

test "encodeURI leaves uriUnescaped alone" {
    try expectEncode("azAZ09-_.!~*'()", "azAZ09-_.!~*'()", .uri);
}

test "encodeURI leaves uriReserved and '#' alone" {
    try expectEncode(";/?:@&=+$,#", ";/?:@&=+$,#", .uri);
}

test "encodeURI percent-encodes a space and non-ASCII" {
    try expectEncode("a%20b", "a b", .uri);
    try expectEncode("%C3%A9", "é", .uri); // U+00E9, 2-byte UTF-8
    try expectEncode("%F0%9F%98%80", "\u{1F600}", .uri); // U+1F600, 4-byte UTF-8 (non-BMP)
}

// -- encodeURIComponent: only uriUnescaped passes through -----------------

test "encodeURIComponent still escapes uriReserved" {
    try expectEncode("%3B%2F%3F%3A%40%26%3D%2B%24%2C%23", ";/?:@&=+$,#", .component);
}

test "encodeURIComponent leaves uriUnescaped alone" {
    try expectEncode("azAZ09-_.!~*'()", "azAZ09-_.!~*'()", .component);
}

// -- decodeURIComponent: unescapes everything ------------------------------

test "decodeURIComponent unescapes reserved characters too" {
    try expectDecode(";/?:@&=+$,#", "%3B%2F%3F%3A%40%26%3D%2B%24%2C%23", false);
}

test "decodeURIComponent round-trips non-ASCII" {
    try expectDecode("é", "%C3%A9", false);
    try expectDecode("\u{1F600}", "%F0%9F%98%80", false);
}

test "decodeURIComponent passes non-percent characters through" {
    try expectDecode("hello world", "hello world", false);
}

// -- decodeURI: reserved %XY sequences stay percent-encoded ----------------

test "decodeURI keeps a reserved-set %XY literal" {
    try expectDecode("%2F", "%2F", true); // '/' is reserved -- stays as "%2F"
    try expectDecode("%23", "%23", true); // '#' likewise
}

test "decodeURI still unescapes a non-reserved %XY" {
    try expectDecode("a b", "a%20b", true);
}

// -- round-trip -------------------------------------------------------------

test "encode then decode round-trips arbitrary UTF-8" {
    const inputs = [_][]const u8{ "hello world", "a=1&b=2", "café \u{1F600} 你好", "" };
    for (inputs) |s| {
        const encoded = try zurlcode.encode(testing.allocator, s, .component);
        defer testing.allocator.free(encoded);
        const decoded = try zurlcode.decode(testing.allocator, encoded, false);
        defer testing.allocator.free(decoded);
        try testing.expectEqualStrings(s, decoded);
    }
}

// -- decode: URIError cases (ECMA-262 test262's throw-URIError.js) --------

test "decode throws on an encoded surrogate half" {
    try expectDecodeError("%ED%BF%BF", false); // U+DFFF, a low surrogate
    try expectDecodeError("%ED%A0%80", false); // U+D800, a high surrogate
}

test "decode throws on overlong encoding" {
    try expectDecodeError("%C0%AF", false); // overlong encoding of '/'
}

test "decode throws on invalid continuation byte" {
    try expectDecodeError("%ED%7F%BF", false);
}

test "decode throws on incomplete sequence" {
    try expectDecodeError("%ED%BF", false);
}

test "decode throws on a codepoint beyond U+10FFFF" {
    try expectDecodeError("%F4%90%80%80", false);
}

// -- decode: malformed %-escape shape --------------------------------------

test "decode throws when '%' has fewer than 2 following characters" {
    try expectDecodeError("%", false);
    try expectDecodeError("%A", false);
    try expectDecodeError("%1", false);
    try expectDecodeError("% ", false);
}

test "decode throws on non-hex digits after '%'" {
    try expectDecodeError("%ZZ", false);
    try expectDecodeError("%2G", false);
}
