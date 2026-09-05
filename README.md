# tidyname

A small, dependency-free command-line utility for cleaning, normalizing, and transliterating file names.

`t i d y n a m e` is the Zig-generation of a project that began life as an experimental Python file-renaming script, became a structured Python package, and was later rewritten in Rust. This repository is intentionally a fresh Zig project with its own Git history.

## Why another implementation?

The goal is not a mechanical Rust-to-Zig port. The earlier implementations provide the behavioral lineage; this project uses that experience to build a smaller, explicit Zig application around the same useful core.

## Features

- filename normalization and separator cleanup
- Russian Cyrillic-to-Latin transliteration
- extension filtering
- recursive directory traversal
- collision-safe renaming
- dry-run preview
- verbose change reporting
- zero third-party runtime dependencies
- macOS, Linux, and Windows targets through Zig's cross-compilation toolchain

## Usage

```text
tidyname [PATH] [OPTIONS]
```

Examples:

```bash
tidyname
tidyname ./downloads --dry-run -v
tidyname ./downloads -r -e csv -e txt
```

`--dry-run` is strongly recommended before applying a batch rename.

## Development

This project targets Zig 0.16.0 or newer.

```bash
zig build
zig build test
zig build run -- --help
zig fmt --check src build.zig
```

The latest stable Zig release is currently 0.16.0. The project uses the 0.16 `std.Io` filesystem APIs rather than the pre-0.16 `std.fs` interfaces.

## Lineage

```text
experimental Python script
        ↓
structured Python package
        ↓
Rust implementation
        ↓
Zig reimplementation (this repository)
```

Previous generation: [`renamex`](https://github.com/avtomatik/renamex).

The earlier repositories remain independent projects. This repository starts at commit 0 and develops as a Zig-native codebase.

## License

MIT. See [LICENSE](LICENSE.md).
