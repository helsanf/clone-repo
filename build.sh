#!/usr/bin/env bash
# Local build (Linux / WSL, Ubuntu 22.04 recommended — NOT macOS).
# Builds Sakura ginkgo kernel (4.14.245, the crDroid 11 kernel) with
# CONFIG_MODULE_SIG_FORCE off + CONFIG_MODULE_FORCE_LOAD on, packaged as a
# flashable AnyKernel3 zip. Boots crDroid 11 (Android 11); load the target
# .ko with `insmod -f` (force, bypasses vermagic/CRC).
set -euo pipefail

KERNEL_REPO="https://github.com/Sakura-Devices/kernel_xiaomi_ginkgo"
KERNEL_BRANCH="11"
DEFCONFIG="vendor/ginkgo-perf_defconfig"
ROOT="$(cd "$(dirname "$0")" && pwd)"

[ "$(uname -s)" = "Linux" ] || { echo "Run on Linux/WSL, not $(uname -s)."; exit 1; }

# 1. deps
if command -v apt-get >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y bc bison flex libssl-dev make gcc git zip curl python3 libncurses-dev ccache
fi

# 2. kernel source
[ -d kernel ] || git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" kernel

# 3. toolchains
if [ ! -x clang/bin/clang ]; then rm -rf clang
  git clone --depth=1 https://github.com/kdrag0n/proton-clang clang; fi
if [ ! -x gcc64/bin/aarch64-linux-android-as ]; then rm -rf gcc64
  git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 gcc64; fi
if [ ! -x gcc32/bin/arm-linux-androideabi-as ]; then rm -rf gcc32
  git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 gcc32; fi

# 4. patch defconfig
cfg="kernel/arch/arm64/configs/$DEFCONFIG"
sed -i 's/^CONFIG_MODULE_SIG_FORCE=y/# CONFIG_MODULE_SIG_FORCE is not set/' "$cfg"
sed -i 's/^CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' "$cfg"
sed -i 's/^CONFIG_EFI=y/# CONFIG_EFI is not set/' "$cfg"
grep -q '^# CONFIG_EFI is not set$' "$cfg" || echo '# CONFIG_EFI is not set' >> "$cfg"
grep -q '^CONFIG_MODULE_FORCE_LOAD=y' "$cfg" || echo 'CONFIG_MODULE_FORCE_LOAD=y' >> "$cfg"
# 32-bit compat vDSO needs a GNU ARM32 assembler that AOSP gcc doesn't expose cleanly;
# disable it (32-bit apps still run via CONFIG_COMPAT, just no vDSO accel)
sed -i 's/^CONFIG_COMPAT_VDSO=y/# CONFIG_COMPAT_VDSO is not set/' "$cfg"
echo "----- config after patch -----"
grep -E "MODULE_SIG_FORCE|MODVERSIONS|CONFIG_EFI|MODULE_FORCE_LOAD|LOCALVERSION=" "$cfg" || true

# 5. build
export PATH="$ROOT/clang/bin:$PATH"
export ARCH=arm64 SUBARCH=arm64
GCC64="$ROOT/gcc64/bin/aarch64-linux-android-"
GCC32="$ROOT/gcc32/bin/arm-linux-androideabi-"
HOSTCFLAGS="-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -std=gnu89 -fcommon"
cd kernel
make O=out ARCH=arm64 "$DEFCONFIG"
make O=out ARCH=arm64 HOSTCFLAGS="$HOSTCFLAGS" olddefconfig
make -j"$(nproc)" O=out ARCH=arm64 \
  CC=clang \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  CROSS_COMPILE="$GCC64" \
  CROSS_COMPILE_ARM32="$GCC32" \
  LD=ld.lld \
  AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
  HOSTCFLAGS="$HOSTCFLAGS" \
  Image.gz-dtb
cd "$ROOT"

# 6. package
IMG="kernel/out/arch/arm64/boot/Image.gz-dtb"
[ -f "$IMG" ] || { echo "build failed: $IMG missing"; exit 1; }
cp "$IMG" anykernel/Image.gz-dtb
( cd anykernel && zip -r9 "../ginkgo-sakura-4.14.245-$(date +%Y%m%d).zip" . -x ".git*" )
echo "DONE: $ROOT/ginkgo-sakura-4.14.245-$(date +%Y%m%d).zip"
