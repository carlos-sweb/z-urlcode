const std = @import("std");
const Allocator = std.mem.Allocator;
const CharSet = @import("charset.zig").CharSet;
const EncodeError = @import("errors.zig").EncodeError;

const hex_digits = "0123456789ABCDEF";

fn appendPercentByte(list: *std.ArrayList(u8), allocator: Allocator, byte: u8) !void {
    try list.appendSlice(allocator, &.{ '%', hex_digits[byte >> 4], hex_digits[byte & 0xF] });
}

/// ECMA-262 19.2.6.1's Encode(string, unescapedSet). `s` must be valid
/// UTF-8; a lone surrogate (the spec's other URIError case for Encode)
/// can't be represented in UTF-8 to begin with, so it can't reach this
/// function -- see z-urlcode's README for what that means for callers
/// whose string type still allows constructing one some other way.
pub fn encode(allocator: Allocator, s: []const u8, comptime set: CharSet) EncodeError![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    const view = std.unicode.Utf8View.init(s) catch return error.InvalidUtf8;
    var it = view.iterator();
    while (it.nextCodepointSlice()) |slice| {
        if (slice.len == 1 and set.isUnescaped(slice[0])) {
            try out.append(allocator, slice[0]);
        } else {
            for (slice) |byte| try appendPercentByte(&out, allocator, byte);
        }
    }
    return out.toOwnedSlice(allocator);
}
