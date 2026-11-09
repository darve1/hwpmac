#!/bin/sh
# Builds rhwp's native FFI with Skia rendering and stages it as a dylib that
# the app embeds in Contents/Frameworks and shares with its Quick Look
# extensions (one copy of the engine instead of one per binary).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RHWP="$ROOT/third_party/rhwp"
OUT="$ROOT/build/native/lib"
LIB=librhwp_native_ffi.dylib

export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
# Must match the app's deployment target in project.yml; C/asm objects from
# cc-built dependencies otherwise target the host SDK.
export MACOSX_DEPLOYMENT_TARGET=14.0

cd "$RHWP"
cargo build --locked -p rhwp-native-ffi --features native-skia --profile release-test

# Only the dylib in the staging directory, so the linker never picks the .a.
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$RHWP/target/release-test/$LIB" "$OUT/"
install_name_tool -id "@rpath/$LIB" "$OUT/$LIB"
codesign --force --sign - "$OUT/$LIB"
echo "staged $OUT/$LIB"
