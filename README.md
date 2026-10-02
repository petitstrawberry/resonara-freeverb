# Resonara Freeverb

Resonara’s bundled stereo reverb: a freestanding CLAP DSP and a dedicated
ScarletUI editor shared by the macOS and Scarlet applications.
The repository, Rust crate and plugin file use `resonara-freeverb`; the displayed
name is **Resonara Freeverb** and the CLAP identifier is
`org.resonara.freeverb`.

The DSP is adapted from [trevyn/freeverb](https://github.com/trevyn/freeverb/tree/d89365ce8381751bea6b0e85294b7f6da3ad98ef)
(MIT, copyright 2018 Ian Hobson). The original reference source and license are
preserved in `vendor/freeverb`. The CLAP adapter originated in
[Resonara](https://github.com/petitstrawberry/resonara); its MIT freestanding ABI
bindings are included in `vendor/clap-sys`. This checkout builds independently
of Resonara and Scarlet source checkouts.

## Use in Resonara

Choose an empty Insert → **Resonara Freeverb**, then open that slot’s editor.
Resonara builds and bundles the host DSP automatically on macOS/Linux; its
Scarlet image builder stages the native DSP in `/system/plugins/`. No separate
plugin installation or catalog scan is needed for the bundled effect.

The `editor/` crate supplies five rotary knobs, numeric fields and
Default / Room / Hall / Aux send presets. Numeric display and edits use
0.01 increments (exactly two decimal places, with trailing zeros). Changes remain drafts until **Apply**;
**Cancel**, Escape or an outside click discards them. Apply saves CLAP state in
the project and makes one Undo step while playback continues. Aux send sets
Wet=1 / Dry=0. Vertical drag and arrows adjust a knob, Shift makes fine steps,
and Home/double-click restores its opening value.

The editor is a host-integrated ScarletUI component, rendered inside Resonara’s
popup. It has no independent window or event loop and is not a `clap.gui`
extension. Other CLAP hosts can use their generic parameter editor. The DSP
library contains no GUI dependencies; macOS and Scarlet still need different
native DSP binaries. See [editor/README.md](editor/README.md) for the host API.

## Standalone DSP install

Download the archive matching your OS/CPU from
[Releases](https://github.com/petitstrawberry/resonara-freeverb/releases).
On Scarlet, copy `resonara-freeverb.clap` and its license notices to
`/system/plugins/`. On macOS, copy the `.clap` **bundle** to
`~/Library/Audio/Plug-Ins/CLAP/`. The macOS archive is arm64 and ad-hoc signed,
not notarized; it contains the DSP only. Scarlet AArch64/RISC-V64 archives are
Scarlet ELF binaries and cannot be loaded by macOS/Linux hosts.

Version 0.2 uses `org.resonara.freeverb`. Projects saved with the earlier
`scarlet-freeverb.clap` / `org.scarlet.freeverb` or `freeverb-scarlet.clap` /
`org.scarlet.freeverb-scarlet` identities must keep their old DSP installed or
replace the insert. This release does not silently rewrite old project state.

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

For a macOS CLAP bundle using the host shell:

```sh
nix develop .#host --command python3 build.py --arch macos --output artifacts/macos
```

This builds for the current macOS toolchain architecture, writes a CLAP bundle
with Info.plist, checks exported `clap_entry` and its libSystem dependency, and
applies/verifies an ad-hoc signature. Use Xcode command-line tools for this build.

Supply rust-src and `readelf` or `llvm-readelf` on PATH for native builds. An optional
`--arch linux` build supports x86-64 Linux with a Linux host toolchain; it does
not create a native Scarlet plugin.

## Verify

```sh
nix develop .#host --command cargo test --locked
nix develop .#host --command cargo fmt --all -- --check
python3 test-build.py
nix develop .#host --command cargo test --locked --manifest-path editor/Cargo.toml
```

Tests compare every DSP output sample against the original implementation at
8, 44.1, 48 and 96 kHz. They also exercise CLAP lifecycle, sample-offset events,
in-place processing, reset/tail, partial state I/O, corrupt-state rejection,
instance capacity and allocation-free audio processing. Editor tests cover
normalized values, presets, two-decimal padding, fine steps and cancelled knob
gestures. The ABI regression
compares vendored bindings with registry clap-sys 0.5.0. Native build audits
reject external dependencies/imports, TLS, unsupported flags and relocations.

Version 0.2 was loaded through Resonara in a Scarlet AArch64 guest: wet tail
energy 2.3789181011455605, state/save/reopen/export/exact bypass and SAS playback
passed. The dedicated editor rendered in Scarlet (virgl) and macOS (wgpu);
knob drag and draft presets were exercised. Host integration tests cover Apply,
Cancel/Escape, invalid input, state persistence, Undo and continued playback.
The final two-decimal resolution/padding is covered by editor tests and both
Scarlet cross-builds. RISC-V64 runtime is not verified.

The original port was exercised in a Scarlet AArch64 guest through Resonara:
real dynamic loading, wet impulse/tail, state/save/reopen, export, exact bypass,
SAS playback and generic knobs. RISC-V64 runtime has not been exercised; it is
cross-built and ELF-audited. Renaming does not change the DSP or parameter/state
formats. Build/ELF checks alone do not verify audible guest output.

## License

MIT. The adapter license is `LICENSE`; upstream DSP, clap-sys and CLAP licenses
remain in their vendor directories and are bundled with every native artifact.
