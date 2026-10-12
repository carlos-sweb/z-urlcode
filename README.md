# z-urlcode

ECMA-262 19.2.6's four URI functions — `encodeURI`, `decodeURI`,
`encodeURIComponent`, `decodeURIComponent` — for Zig. Pure Zig, zero
dependencies beyond `std`.

Requires **Zig 0.17.0**. [Native Zig API documentation](https://carlos-sweb.github.io/z-urlcode/).

Compatibility covers the four URI transformations on valid UTF-8 strings.
JavaScript argument conversion (`ToString`) and mapping Zig errors to
JavaScript exceptions are the host's responsibility.

## Why a separate repo

Same shape as [z-uuid](https://github.com/carlos-sweb/z-uuid): a small,
self-contained, spec-defined algorithm with no need for a JS runtime's
value types. Operates directly on `[]const u8` (UTF-8) in and out, so it's
usable by any host, not just a JS engine.

## API

```zig
const zurlcode = @import("zurlcode");

// encodeURI(s) / encodeURIComponent(s)
const uri = try zurlcode.encode(allocator, "a b", .uri); // "a%20b"
const comp = try zurlcode.encode(allocator, "a/b", .component); // "a%2Fb"

// decodeURI(s) / decodeURIComponent(s)
const s1 = try zurlcode.decode(allocator, "a%20b", true); // "a b", keeps reserved %XY literal
const s2 = try zurlcode.decode(allocator, "a%2Fb", false); // "a/b", unescapes everything
```

`decode` returns `error.MalformedUri` for every case ECMA-262 requires a
`URIError` for: truncated/missing hex digits after `%`, invalid UTF-8
continuation bytes, overlong encodings, codepoints past U+10FFFF, and
encoded surrogate halves (`%ED%A0%80`..`%ED%BF%BF`).

## Known gap: lone surrogates on the `encode` side

The spec's `Encode` algorithm also throws `URIError` when the input string
contains a lone UTF-16 surrogate. `encode` here can't be handed one in the
first place — a lone surrogate isn't representable in valid UTF-8 (that's
what this library's inputs are), so that branch of the spec never triggers.
A host whose string type can smuggle one in some other way (e.g. WTF-8)
would need to reject it before calling `encode`, or accept it'll be
UTF-8-validated away instead of raising `URIError`.

`decode` validates escaped UTF-8 sequences but copies literal bytes unchanged;
callers must uphold the valid-UTF-8 input contract. Full JavaScript UTF-16
string compatibility, including literal lone surrogates, is outside this API's
documented scope.

## Tests and documentation

```sh
zig build test
zig build docs
```

`zig build docs` generates Zig's native API documentation in `zig-out/docs/`.
GitHub Actions tests the library with Zig 0.17.0, generates the documentation,
and publishes it to GitHub Pages on pushes to `master` and version tags.

## Dependency

```zig
// build.zig.zon
.dependencies = .{
    .zurlcode = .{ .path = "../z-urlcode" },
},
```
