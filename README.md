![Banner](banner.png)

# SamFWDumper

A free tool that downloads Samsung firmware and pulls out the parts you need. No software to install, it all runs in your browser through GitHub Actions.

## What This Actually Means

You know those big firmware files from SamFW? This tool:
- Downloads that file for you
- Opens it up
- Grabs only what you asked for
- Gives you a download link

You don't need a powerful computer. You don't need to install anything. GitHub's servers do all the work.

***

## Before You Start

1. Click the **Fork** button at the top right of this page and fork it to your GitHub account.
2. Go to the **Actions** tab on your fork. If workflows are disabled, click **"I understand my workflows, go ahead and enable them"**.

Done. You only do this once.

***

## How to Get a Firmware Link

Before using this tool, you need a direct download link from SamFW:

1. Go to [samfw.com](https://samfw.com) and search for your device model number (e.g., `SM-S918B`) or device name (e.g., `S23 Ultra`), then pick your region/CSC (e.g., `EUX`).
2. Choose the firmware version, then click the red button **"Download SamFW Server"**.
3. Wait a moment until a **"Download"** button appears. Click it, then **cancel the download immediately**.
4. Right-click the same **"Download"** button (or long-press on mobile) and select **"Copy link address"**.

That link is what you will paste into the workflow.

***

## Available Workflows (4 Ways to Use It)

| Workflow | What it gets you | Use it when |
|---|---|---|
| **1. Images Extractor** | Raw partition images (`.img` or `.img.xz`) | You want raw partition images (like `boot.img` or `system.img`) to flash, inspect, or mod |
| **2. System Files Extractor** | Entire system folders and files | You want folders like apps, libraries, media, configs, or build properties |
| **3. Special Targeted Extractor** | Specific app lists or full app directory scan | You want specific pre-selected apps/files, or want to view all installed apps and their sizes |
| **4. Full FWFetch** | Complete unchanged firmware `.zip` | You just want the original full firmware uploaded to GoFile for a fast mirror link |

### Quick Guide to Each Workflow

#### 1. Images Extractor
Extracts partition images directly out of the firmware. You can pick any combination of these partitions:

`boot` `dtbo` `init_boot` `odm` `odm_dlkm` `product` `recovery` `system` `system_dlkm` `system_ext` `vbmeta` `vbmeta_system` `vendor` `vendor_boot` `vendor_dlkm`

#### 2. System Files Extractor
Pulls complete file categories directly out of the system partitions. Here are the options you can check:

| Checkbox | What you get |
|---|---|
| `app` | Preinstalled system apps (APKs) |
| `bin` | System binary tools and scripts |
| `cameradata` | Camera tuning and config files |
| `etc` | System configuration and permission files |
| `lib` | 32-bit system libraries (`.so`) |
| `lib64` | 64-bit system libraries (`.so`) |
| `media` | System sounds, ringtones, fonts, and boot animation |
| `priv-app` | Privileged system apps |
| `saiv` | Samsung AI Vision folder |
| `build.prop` | Device fingerprint and system properties |
| `framework-res RRO` | Product overlay APK (`framework-res__auto_generated_rro_product.apk`) |
| `PIT file` | Partition Information Table from the CSC file |
| `wallpaper-res.apk` | System wallpaper resources APK |

#### 3. Special Targeted Extractor
Use this if you don't want whole folders and only need specific items.
- **Pre-set target lists**: Uses text files in `targets/system/` to pick out key apps, framework files, media, and libraries.
- **`show_all` mode**: If enabled, it lists every single app folder inside `app` and `priv-app` along with its exact size in the workflow logs.
- **Custom folder name**: Lets you change the output folder name (defaults to `Apps`).

#### 4. Full FWFetch
The simplest option. It downloads the whole firmware zip from SamFW and uploads it to GoFile as a direct mirror link. No extraction or processing is done on the files.

***

## How to Run Any Workflow

1. Go to the **Actions** tab in your repository fork.
2. Select the workflow you want from the left side list.
3. Click **Run workflow** on the right.
4. Paste your SamFW link.
5. Pick your compression level (0 = fast/uncompressed, 9 = maximum compression) and upload destination (GoFile or GitHub Releases).
6. Check the items you want and click **Run workflow**.

Wait a few minutes for the workflow to complete. Your download link will show up under GitHub Releases or in the step output for GoFile.

***

## What's Happening Behind the Scenes

1. Downloads the firmware zip from SamFW on GitHub Actions servers.
2. Unzips the main package to get the AP and CSC tar files, and decompresses any `.lz4` files.
3. If the device uses a `super.img` dynamic partition, it unpacks it using `lpunpack`. It supports EROFS, EXT4, and F2FS filesystems.
4. Extracts only the partitions, folders, or specific files you selected.
5. Compresses the output using `xz` (or builds a standard `.tar`/`.zip` if compression level is set to 0).
6. Uploads the finished files to GoFile or GitHub Releases and provides your download link.

Works on legacy and modern Samsung devices, including devices with A/B slot partition layouts (`_a` and `_b`).

***

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE) for personal and non-commercial use.

**Distribution Restriction:** Redistribution of this software, modified or unmodified, is ONLY permitted via GitHub's official fork mechanism from this repository. Direct copying, re-uploading, or creating standalone repositories of this code is prohibited.

See the [LICENSE](LICENSE) file for full terms.

***

## Tools Used & Credits

This project relies on several open-source tools to handle Android images, filesystems, and compression.

### Bundled Binaries (inside `tools/`)
- [nmeum/android-tools](https://github.com/nmeum/android-tools) (Apache-2.0) - `simg2img`, `img2simg`, `ext2simg`, `append2simg` for sparse image conversion.
- [LonelyFool/lpunpack_and_lpmake](https://github.com/LonelyFool/lpunpack_and_lpmake) (Apache-2.0) - `lpunpack` used to extract Samsung `super.img` dynamic partitions.
- [sekaiacg/erofs-utils](https://github.com/sekaiacg/erofs-utils) (GPL-2.0/Apache-2.0) - `extract.erofs` used to read EROFS partition images.
- [AOSP Tools](https://android.googlesource.com/) (Apache-2.0) - Android build binaries (`mkbootimg`, `unpack_bootimg`, `repack_bootimg`, `avbtool`, `mkdtboimg`).

### System Dependencies (installed during workflow execution)
- [e2fsprogs](https://github.com/tytso/e2fsprogs) (GPL-2.0/LGPL-2.1) - `debugfs` used to read EXT4 images without root mounting.
- [f2fs-tools](https://git.kernel.org/pub/scm/linux/kernel/git/jaegeuk/f2fs-tools.git) (GPL-2.0/LGPL-2.1) - Linux kernel tools used for F2FS partition mounts.
- [lz4](https://github.com/lz4/lz4) (BSD-2-Clause) - LZ4 decompression tool for Samsung `.lz4` partition files.
- [xz-utils](https://github.tukaani.org/xz-utils/) (LGPL-2.1/GPL-2.0) - XZ compression utility for output archives.
- [curl](https://curl.se/) & [jq](https://jqlang.github.io/jq/) - API request and JSON formatting tools for GoFile uploads.

Upload integration powered by [GoFile API](https://gofile.io/api).

***

## Credits

<div align="center">

<a href="https://samfw.com" target="_blank"><img src="https://img.shields.io/badge/🌐_SamFW-Firmware_Source-181717?style=for-the-badge&labelColor=1428A0" alt="SamFW"></a><br>
<sub>The platform that makes firmware accessible to everyone. The backbone this project stands on.</sub>

***

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

***

Copyright © 2026 Xiatsuma
