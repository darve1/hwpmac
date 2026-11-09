#!/bin/sh
# Builds rhwp's native FFI with Skia rendering and stages the static library
# where the Xcode targets link it. The staging directory holds only the .a, so
# the linker never picks the dylib that cargo also produces.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RHWP="$ROOT/third_party/rhwp"
OUT="$ROOT/build/native/lib"

export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
# Must match the app's deployment target in project.yml; C/asm objects from
# cc-built dependencies otherwise target the host SDK.
export MACOSX_DEPLOYMENT_TARGET=14.0

cd "$RHWP"
cargo build --locked -p rhwp-native-ffi --features native-skia --profile release-test

mkdir -p "$OUT"
cp "$RHWP/target/release-test/librhwp_native_ffi.a" "$OUT/"
echo "staged $OUT/librhwp_native_ffi.a"
