# Design notes

The Zig implementation deliberately starts from behavior rather than source-code structure.

## Deliberate choices

- The project has no dependency on a CLI framework or external package.
- Filesystem I/O is explicit and uses Zig 0.16's `std.Io` interface.
- Renames use the non-overwriting operation and retry with a numeric suffix on collision.
- Recursive traversal is delegated to the standard library walker.
- Transformation is pure with respect to the filesystem and therefore easy to unit test.
- The first version favors predictable sequential mutation over adding a custom worker pool. Parallelism can be introduced only after profiling demonstrates that it is worthwhile.

## Behavior retained from the earlier generations

- hidden files are skipped
- unchanged names are skipped
- extensions are preserved verbatim
- transformed names never overwrite an existing destination
- dry-run does not mutate the filesystem
- Cyrillic transliteration follows the established Russian mapping
