#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="src/gamesir-g7-pro-1022.bpf.c"
OUTPUT="$ROOT_DIR/dist/gamesir-g7-pro-1022.bpf.o"
BUILD_DIR="$(mktemp -d)"
UDEV_HID_BPF_COMMIT="bbaad639d4b2efe2a909e8b7c594b91e87704ab8"

cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

need_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'missing required command: %s\n' "$1" >&2
        exit 1
    }
}

for command in clang llvm-strip git; do
    need_command "$command"
done

printf '%s\n' 'Cloning udev-hid-bpf headers...'
git clone --quiet --depth 1 \
    https://gitlab.freedesktop.org/libevdev/udev-hid-bpf.git \
    "$BUILD_DIR/udev-hid-bpf"

# Keep the generated object reproducible instead of depending on moving HEAD.
git -C "$BUILD_DIR/udev-hid-bpf" fetch --quiet --depth 1 origin "$UDEV_HID_BPF_COMMIT"
git -C "$BUILD_DIR/udev-hid-bpf" checkout --quiet --detach "$UDEV_HID_BPF_COMMIT"

mkdir -p "$(dirname -- "$OUTPUT")"

printf '%s\n' 'Compiling HID-BPF object...'
cd "$ROOT_DIR"
clang --target=bpf -O2 -g -fdebug-compilation-dir=/ -D__TARGET_ARCH_x86 \
    -I"$BUILD_DIR/udev-hid-bpf/src/bpf" \
    -c "$SOURCE" \
    -o "$BUILD_DIR/gamesir-g7-pro-1022.full.o"

llvm-strip -g \
    -o "$OUTPUT" \
    "$BUILD_DIR/gamesir-g7-pro-1022.full.o"

if command -v udev-hid-bpf >/dev/null 2>&1; then
    udev-hid-bpf inspect "$OUTPUT"
else
    printf '%s\n' 'udev-hid-bpf not installed; skipping object inspection.'
fi

printf 'Wrote %s\n' "$OUTPUT"
