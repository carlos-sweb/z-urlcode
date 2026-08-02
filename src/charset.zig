//! ECMA-262 19.2.6.1's character sets, expressed as membership predicates.

/// `uriUnescaped`: alphanumerics plus `-_.!~*'()` -- never percent-encoded
/// by either `encodeURI` or `encodeURIComponent`.
pub fn isUriUnescaped(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '!', '~', '*', '\'', '(', ')' => true,
        else => false,
    };
}

/// `uriReserved`: delimiters with syntactic meaning in a URI --
/// `encodeURI` leaves these alone, `encodeURIComponent` percent-encodes
/// them.
pub fn isUriReserved(c: u8) bool {
    return switch (c) {
        ';', '/', '?', ':', '@', '&', '=', '+', '$', ',' => true,
        else => false,
    };
}

/// Which characters a given encode function leaves untouched.
pub const CharSet = enum {
    /// `encodeURI`'s unescapedURISet: uriReserved + uriUnescaped + "#".
    uri,
    /// `encodeURIComponent`'s unescapedURIComponentSet: uriUnescaped only.
    component,

    pub fn isUnescaped(self: CharSet, c: u8) bool {
        return switch (self) {
            .uri => isUriUnescaped(c) or isUriReserved(c) or c == '#',
            .component => isUriUnescaped(c),
        };
    }
};
