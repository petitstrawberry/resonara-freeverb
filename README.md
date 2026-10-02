# Freeverb Scarlet

A stereo Freeverb reverb delivered as a native CLAP plugin for Scarlet OS.
The repository, Rust crate and plugin file use `freeverb-scarlet`; the displayed
name is **Freeverb Scarlet** and the CLAP identifier is
`org.scarlet.freeverb-scarlet`.

The DSP is adapted from [trevyn/freeverb](https://github.com/trevyn/freeverb/tree/d89365ce8381751bea6b0e85294b7f6da3ad98ef)
(MIT, copyright 2018 Ian Hobson). The original reference source and license are
preserved in `vendor/freeverb`. The CLAP adapter originated in
[Resonara](https://github.com/petitstrawberry/resonara); its MIT freestanding ABI
bindings are included in `vendor/clap-sys`. This checkout builds independently
of Resonara and Scarlet source checkouts.

## Install

Download the archive matching your Scarlet CPU from
[Releases](https://github.com/petitstrawberry/freeverb-scarlet/releases).
Copy `freeverb-scarlet.clap` and `freeverb-scarlet.LICENSE.txt` to
`/system/plugins/` in Scarlet. In Resonara, choose an empty Insert →
Installed CLAP effects… → Rescan → Freeverb Scarlet.

AArch64 and RISC-V64 archives contain native Scarlet ELF binaries. They are not
macOS or Linux plugins. Older development builds used `scarlet-freeverb.clap`
and `org.scarlet.freeverb`; existing projects using those identifiers must be
updated or keep that older plugin installed.

## Parameters

| Parameter | Range | Default |
| --- | --- | --- |
| Wet | 0–1 | 0.3 |
| Dry | 0–1 | 1 |
| Room size | 0–1 | 0.5 |
| Damping | 0–1 | 0.5 |
| Width | 0–1 | 1 |

For an Aux send reverb, set Wet=1 and Dry=0.

Stereo float32, zero latency, 8–96 kHz. Changes support CLAP sample-offset
events. A versioned 48-byte state stores all parameters. Reset clears the tail
and preserves parameters; the host controls bypass. Keep feeding silence after
the input ends to hear the full tail. Freeze mode is omitted.

Audio process/flush/reset allocate no memory and use no locks, threads, TLS or
OS imports. Fixed delay storage is allocated before processing, occupying about
6 MiB per library, with up to eight simultaneous instances per loaded library.

## GUI and Resonara integration

This version uses the host's generic parameter editor. Resonara supplies rotary
knobs and exact numeric fields: drag vertically or use arrows (Shift for fine
adjustment); Home/double-click restores the opening value. Apply commits the
edits and state; Cancel leaves the plugin unchanged.

The intended next integration is a bundled Resonara reverb with a dedicated
ScarletUI editor shared by its macOS and Scarlet builds. A plugin-owned,
independent CLAP GUI additionally requires platform window/event-loop adapters;
that GUI is not implemented in this release. macOS and Scarlet require separate
native binaries even when their UI source is shared.

## Build

The pinned Nix shell includes the Scarlet Rust compiler, rust-src and LLVM ELF
tools. From this checkout:

```sh
nix develop --accept-flake-config
python3 build.py --arch aarch64 --output artifacts/aarch64
python3 build.py --arch riscv64 --output artifacts/riscv64
```

Each build writes the audited plugin and license notices under
`artifacts/<arch>/staging/system/plugins/`, plus a `build.json` audit report.
The builder derives a temporary PIC/shared-library target from Scarlet's native
target, rebuilds only core/compiler_builtins, and leaves the installed compiler
and target definitions unchanged. Scarlet linking uses `-Bsymbolic-functions`;
`-Bsymbolic` emits loader-rejected DF_SYMBOLIC.

An existing Scarlet toolchain can also be used without Nix:

```sh
python3 build.py --arch aarch64 --toolchain /path/to/scarlet-toolchain \
  --output artifacts/aarch64
```

Supply rust-src and `readelf` or `llvm-readelf` on PATH. An optional
`--arch linux` build supports x86-64 Linux with a Linux host toolchain; it does
not create a native Scarlet plugin.

## Verify

```sh
nix develop .#host --command cargo test --locked
nix develop .#host --command cargo fmt --all -- --check
python3 test-build.py
```

Tests compare every DSP output sample against the original implementation at
8, 44.1, 48 and 96 kHz. They also exercise CLAP lifecycle, sample-offset events,
in-place processing, reset/tail, partial state I/O, corrupt-state rejection,
instance capacity and allocation-free audio processing. The ABI regression
compares vendored bindings with registry clap-sys 0.5.0. Native build audits
reject external dependencies/imports, TLS, unsupported flags and relocations.

The original port was exercised in a Scarlet AArch64 guest through Resonara:
real dynamic loading, wet impulse/tail, state/save/reopen, export, exact bypass,
SAS playback and generic knobs. RISC-V64 runtime has not been exercised; it is
cross-built and ELF-audited. Renaming does not change the DSP or parameter/state
formats. Build/ELF checks alone do not verify audible guest output.

## License

MIT. The adapter license is `LICENSE`; upstream DSP, clap-sys and CLAP licenses
remain in their vendor directories and are bundled with every native artifact.
