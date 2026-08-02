//! `z-urlcode`: ECMA-262 19.2.6's four URI functions --
//! `encodeURI`/`decodeURI`/`encodeURIComponent`/`decodeURIComponent` --
//! implemented as pure `[]const u8` (UTF-8) transforms. No z-value/z-string
//! dependency: works directly on UTF-8 bytes, which is what a host's string
//! type is expected to hand in and get back.
pub const CharSet = @import("charset.zig").CharSet;
pub const EncodeError = @import("errors.zig").EncodeError;
pub const DecodeError = @import("errors.zig").DecodeError;
pub const encode = @import("encode.zig").encode;
pub const decode = @import("decode.zig").decode;

test {
    _ = @import("charset.zig");
    _ = @import("errors.zig");
    _ = @import("encode.zig");
    _ = @import("decode.zig");
}
