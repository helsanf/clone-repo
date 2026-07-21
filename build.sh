#!/usr/bin/env bash
# Local build (Linux / WSL only — NOT macOS).
# Produces a flashable AnyKernel3 zip for Redmi Note 8 (ginkgo), kernel 4.14.117,
# with CONFIG_MODULE_SIG_FORCE disabled.
set -euo pipefail

KERNEL_REPO="https://github.com/MiCode/Xiaomi_Kernel_OpenSource"
KERNEL_BRANCH="ginkgo-q-oss"
DEFCONFIG="vendor/ginkgo-perf_defconfig"
ROOT="$(cd "$(dirname "$0")" && pwd)"

# 0. sanity
[ "$(uname -s)" = "Linux" ] || { echo "Run on Linux/WSL, not $(uname -s)."; exit 1; }

# 1. deps (Debian/Ubuntu)
if command -v apt-get >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y bc bison flex libssl-dev make gcc git zip curl python3 libncurses-dev
fi

# 2. kernel source (4.14.117 base)
[ -d kernel ] || git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" kernel

# 3. toolchain
[ -d clang ] || git clone --depth=1 https://github.com/kdrag0n/proton-clang clang

# 4. disable module sig force (keep CONFIG_MODULE_SIG=y so signed vendor modules still verify)
cfg="kernel/arch/arm64/configs/$DEFCONFIG"
sed -i 's/^CONFIG_MODULE_SIG_FORCE=y/# CONFIG_MODULE_SIG_FORCE is not set/' "$cfg"
echo "----- module config after patch -----"
grep -E "CONFIG_MODULES|CONFIG_MODULE_SIG" "$cfg" || true

# 5. build
export PATH="$ROOT/clang/bin:$PATH"
export ARCH=arm64 SUBARCH=arm64
cd kernel
# keep vermagic "4.14.117-perf" (no trailing "+") so stock vendor modules match
: > .scmversion
make O=out ARCH=arm64 "$DEFCONFIG"
make -j"$(nproc)" O=out ARCH=arm64 \
  CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm \
  OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  Image.gz-dtb
cd "$ROOT"

# 6. package
IMG="kernel/out/arch/arm64/boot/Image.gz-dtb"
[ -f "$IMG" ] || { echo "build failed: $IMG missing"; exit 1; }
cp "$IMG" anykernel/Image.gz-dtb
( cd anykernel && zip -r9 "../ginkgo-custom-4.14.117-$(date +%Y%m%d).zip" . -x ".git*" )
echo "DONE: $ROOT/ginkgo-custom-4.14.117-$(date +%Y%m%d).zip"
