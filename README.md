![Banner](banner.png)

# SamFWDumper

A free tool that downloads Samsung firmware and pulls out the parts you need. No software to install, it all runs in your browser through GitHub Actions.

## What This Actually Means

You know those big firmware files from SamFW? This tool:
- Downloads that file for you
- Opens it up
- Grabs only what you asked for
- Gives you a direct download link

You don't need a powerful computer. You don't need to install anything. GitHub's servers do all the work.

---

## Before You Start

1. Click the **Fork** button at the top right of this page and fork it to your GitHub account.
2. Go to the **Actions** tab on your fork. If workflows are disabled, click **"I understand my workflows, go ahead and enable them"**.

Done. You only do this once.

---

## How to Get a Firmware Link

Before using this tool, you need a direct download link from SamFW:

1. Go to [samfw.com](https://samfw.com) and search for your device model number (e.g., `SM-S918B`) or device name (e.g., `S23 Ultra`), then pick your region/CSC (e.g., `EUX`).
2. Choose the firmware version, then click the red button **"Download SamFW Server"**.
3. Wait a moment until a **"Download"** button appears. Click it, then **cancel the download immediately**.
4. Right-click the same **"Download"** button (or long-press on mobile) and select **"Copy link address"**.

That link is what you will paste into the workflow input.

---

## Available Workflows (4 Ways to Use It)

| Workflow | What it gets you | Best used for |
|---|---|---|
| **1. Images Extractor** | Raw partition images (`.img` / `.img.xz`) | Flashing, inspecting, or modding raw partition images |
| **2. System Files Extractor** | Entire system folders & key files | Pulling complete folders (APKs, binaries, configs, libs, media, etc.) |
| **3. Special Targeted Extractor** | Selective target lists & app directory listing | Pulling specific curated app/system lists or inspecting all apps with sizes |
| **4. Full FWFetch** | Complete untouched firmware `.zip` | Fast cloud mirroring of full firmware packages directly to GoFile |

### Steps to Run Any Workflow:
1. Go to your fork's **Actions** tab → select the desired workflow on the left sidebar.
2. Click **Run workflow** dropdown on the right.
3. Paste your SamFW direct download link.
4. Configure options (compression level, destination, partition/folder selections).
5. Click **Run workflow**. Wait a few minutes — your download link will appear under GitHub Releases or GoFile.

---

## Partition & File Target Reference

### 1. Images Extractor — Supported Partitions
`boot` | `dtbo` | `init_boot` | `odm` | `odm_dlkm` | `product` | `recovery` | `system` | `system_dlkm` | `system_ext` | `vbmeta` | `vbmeta_system` | `vendor` | `vendor_boot` | `vendor_dlkm`

---

### 2. System Files Extractor — Available Options

| Target Checkbox | Description & Contents |
|---|---|
| `app` | Preinstalled system applications (APKs) |
| `bin` | System executable binaries |
| `cameradata` | Camera tuning & configuration files |
| `etc` | System configs, permissions, & XML files |
| `lib` | 32-bit shared libraries (`.so`) |
| `lib64` | 64-bit shared libraries (`.so`) |
| `media` | Audio files, ringtones, fonts, & boot animations |
| `priv-app` | Privileged system applications |
| `saiv` | Samsung AI Vision data folder |
| `build.prop` | Device fingerprint & system properties |
| `framework-res RRO` | Product overlay APK (`framework-res__auto_generated_rro_product.apk`) |
| `PIT file` | Partition Information Table extracted from CSC archive |
| `wallpaper-res.apk` | System wallpaper resources APK |

---

### 3. Special Targeted Extractor — Features
- **Curated Extraction**: Uses target list files (`targets/system/*.txt`) to pull specific essential apps, configs, media, and libraries.
- **Show All Mode (`show_all`)**: Scans `app` and `priv-app` directories and prints every installed folder along with its size, allowing full discovery of preinstalled packages.
- **Custom Output Naming**: Allows setting a custom name for the resulting package (default: `Apps`).

---

### 4. Full FWFetch — Features
- Downloads the entire firmware archive from SamFW.
- Re-uploads it directly to **GoFile** without extra extraction processing.
- Generates a GitHub Release containing the GoFile download link.

---

## What's Happening Behind the Scenes

1. **Downloads**: Fetches the firmware zip directly via GitHub Actions runners.
2. **Unpacks Archives**: Unzips the package and parses `AP` tar (and `CSC` tar for PIT extraction). Handles both raw `.img` and LZ4-compressed `.img.lz4` files.
3. **Super Image Handling**: Unpacks dynamic partition `super.img` via `lpunpack` (supporting EROFS, EXT4, and F2FS file systems).
4. **Targeted Extraction**: Extracts strictly requested partitions or file trees.
5. **Compression**: Packages outputs using `xz` compression (levels 0 to 9; `0` = uncompressed tar/zip for speed, `9` = maximum compression) or leaves raw binaries as requested.
6. **Delivery**: Uploads resulting assets to **GitHub Releases** or **GoFile** and generates a link in release notes.

Works on both legacy and modern Samsung devices. Supports A/B slot partition schemes (`_a` and `_b`).

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE) - personal and non-commercial use only.

**Distribution Restriction:** Redistribution of this software, modified or unmodified, is ONLY permitted via GitHub's official fork mechanism from this repository. Direct copying, re-uploading, or creating standalone repositories of this code is prohibited.

See the [LICENSE](LICENSE) file for full terms.
For commercial licensing inquiries, contact the repository owner via GitHub.

---

## Tools Used

This project relies on several open-source tools:

- [nmeum/android-tools](https://github.com/nmeum/android-tools) (Apache-2.0) - simg2img, img2simg, ext2simg, append2simg
- [LonelyFool/lpunpack_and_lpmake](https://github.com/LonelyFool/lpunpack_and_lpmake) (Apache-2.0) - lpunpack, lpdump, lpmake
- [sekaiacg/erofs-utils](https://github.com/sekaiacg/erofs-utils) (GPL-2.0/Apache-2.0) - EROFS filesystem tools
- [AOSP platform/external/avb](https://android.googlesource.com/platform/external/avb) (Apache-2.0) - avbtool
- [AOSP platform/external/e2fsprogs](https://android.googlesource.com/platform/external/e2fsprogs) (Apache-2.0) - e2fsdroid, mke2fs.android
- [AOSP platform/external/f2fs-tools](https://android.googlesource.com/platform/external/f2fs-tools) (Apache-2.0) - make_f2fs, sload_f2fs
- [AOSP platform/system/tools/mkbootimg](https://android.googlesource.com/platform/system/tools/mkbootimg) (Apache-2.0) - mkbootimg, unpack_bootimg, repack_bootimg
- [AOSP platform/system/libufdt](https://android.googlesource.com/platform/system/libufdt) (Apache-2.0) - mkdtboimg
- [tytso/e2fsprogs](https://github.com/tytso/e2fsprogs) (GPL-2.0/LGPL-2.1) - debugfs
- [tukaani/xz](https://github.com/tukaani-project/xz) (LGPL-2.1/GPL-2.0) - xz compression
- [lz4](https://github.com/lz4/lz4) (BSD-2-Clause) - LZ4 compression

Upload integration via [GoFile API](https://gofile.io/api).

---

## Credits

<div align="center">

<a href="https://samfw.com" target="_blank"><img src="https://img.shields.io/badge/🌐_SamFW-Firmware_Source-181717?style=for-the-badge&labelColor=1428A0" alt="SamFW"></a><br>
<sub>The platform that makes firmware accessible to everyone. The backbone this project stands on.</sub>

---

<table>
<tr>
<td colspan="3" align="center">
<br>
<a href="https://github.com/ravindu644" target="_blank">
<img src="https://github.com/ravindu644.png" width="64" height="64" style="border-radius:50%"><br>
<b>Ravindu Deshan</b>
</a><br>
<sub>Senior Developer - For regularly reviewing the entire repository structure, ensuring everything is solid, and bringing seasoned expertise that keeps this project on the right track.</sub>
</td>
</tr>
<tr>
<td align="center" width="200">
<a href="https://github.com/DevCat3" target="_blank">
<img src="https://github.com/DevCat3.png" width="64" height="64" style="border-radius:50%"><br>
<b>DevCatowa</b>
</a><br>
<sub>For helping in writing scripts that shaped the soul of this repo. an inspiring catowa. </sub>
</td>
<td align="center" width="200">
<a href="https://github.com/QOS3" target="_blank">
<img src="https://github.com/QOS3.png" width="64" height="64" style="border-radius:50%"><br>
<b>QOS3</b>
</a><br>
<sub>For being our كطري </sub>
</td>
<td align="center" width="200">
<a href="https://github.com/mrx7014" target="_blank">
<img src="https://github.com/mrx7014.png" width="64" height="64" style="border-radius:50%"><br>
<b>MRX7014</b>
</a><br>
<sub>For the extraordinary commitment of being alive. Truly, it's enough we see you. </sub>
</td>
</tr>
</table>

</div>

---

Copyright © 2026 Xiatsuma
