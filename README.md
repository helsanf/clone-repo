# Ginkgo Custom Kernel 4.14.117

Custom kernel for **Redmi Note 8 (ginkgo/willow)**.

- **Base:** MiCode `Xiaomi_Kernel_OpenSource` branch `ginkgo-q-oss` → Linux **4.14.117** (stock, cocok dengan modul vendor stock)
- **Change:** `CONFIG_MODULE_SIG_FORCE` disabled (modul unsigned bisa di-load; `CONFIG_MODULE_SIG=y` tetap, jadi modul vendor yang signed tetap terverifikasi)
- **Packaging:** AnyKernel3 (template dari Yuki Kernel 4.14.117), flashable via TWRP/OrangeFox

## Kenapa gak bisa build di macOS
Kernel Linux butuh filesystem case-sensitive + cross-toolchain. macOS FS case-insensitive → gagal. Build di **Linux/WSL** atau **GitHub Actions**.

## Opsi A — GitHub Actions (paling gampang)
1. Bikin repo GitHub baru, push isi folder ini:
   ```bash
   cd ginkgo-custom-kernel
   git init && git add . && git commit -m "init ginkgo custom kernel"
   git branch -M main
   git remote add origin git@github.com:<user>/<repo>.git
   git push -u origin main
   ```
2. Tab **Actions** → workflow "Build ginkgo kernel 4.14.117" jalan otomatis (atau Run workflow manual).
3. Selesai build (~15–25 mnt), download artifact **ginkgo-custom-kernel-zip**. Itu zip flashable.

## Opsi B — Linux / WSL lokal
```bash
cd ginkgo-custom-kernel
./build.sh
```
Output: `ginkgo-custom-4.14.117-YYYYMMDD.zip`

## Flash (TWRP/OrangeFox)
1. **Backup boot** dulu (Backup → Boot).
2. Copy zip ke HP.
3. Install → pilih zip → swipe.
4. Reboot. Cek: `adb shell su -c 'uname -r'` → harus `4.14.117-...`

Kalau bootloop: restore backup boot dari recovery.

## Verifikasi module sig setelah boot
```bash
adb shell su -c 'zcat /proc/config.gz | grep MODULE_SIG'
# CONFIG_MODULE_SIG_FORCE is not set   ← target
CONFIG_MODULE_SIG=y
```

## Struktur
```
ginkgo-custom-kernel/
├── .github/workflows/build.yml   # CI: clone source + patch + build + zip
├── build.sh                      # build lokal (Linux/WSL)
├── anykernel/                    # AnyKernel3 template (dari Yuki 117)
│   ├── anykernel.sh              # block=/dev/block/bootdevice/by-name/boot
│   ├── tools/ (ak3-core.sh, magiskboot, busybox, magiskpolicy)
│   └── META-INF/...
└── README.md
```
> `anykernel/Image.gz-dtb` diisi oleh proses build (belum ada di template).
