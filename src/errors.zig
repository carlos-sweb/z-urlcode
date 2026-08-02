const std = @import("std");

/// `decode`'s failure mode -- every malformed-input case ECMA-262's Decode
/// algorithm requires a `URIError` for (bad/missing hex digits, truncated
/// `%XY`, invalid UTF-8 continuation bytes, overlong encodings, codepoints
/// past U+10FFFF, encoded surrogate halves) collapses to this one variant;
/// the caller (a host mapping this onto a real `URIError`) doesn't need to
/// distinguish which.
pub const DecodeError = error{MalformedUri} || std.mem.Allocator.Error;

/// `encode`'s failure mode. `InvalidUtf8` is defensive, not spec-driven --
/// a caller whose string type upholds a valid-UTF-8 invariant (as z-value's
/// `ZString` does) should never trigger it.
pub const EncodeError = error{InvalidUtf8} || std.mem.Allocator.Error;
