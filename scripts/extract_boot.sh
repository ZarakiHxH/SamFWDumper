#!/bin/bash
# =============================================================================
# SamFWDumper - Automated Samsung Firmware Extraction
# Copyright (C) 2026 Xiatsuma
# Licensed under PolyForm Noncommercial License 1.0.0
# https://polyformproject.org/licenses/noncommercial/1.0.0
#
# You may NOT use this file except in compliance with the License.
# Commercial use, removal of this header, or distribution without attribution
# is strictly prohibited. For permissions: https://github.com/Xiatsuma
# =============================================================================
set -eo pipefail

echo "═══════════════════════════════════════"
echo "   Samsung Boot & Kernel Extractor"
echo "═══════════════════════════════════════"

URL="$1"
[ -z "$URL" ] && { echo "❌ No URL provided"; exit 1; }
if ! echo "$URL" | grep -qE '^https?://'; then
  echo "❌ Invalid URL: must start with http:// or https://"
  exit 1
fi
COMPRESSION_LEVEL="${2:-0}"
SELECTED="$3"

[ -z "$SELECTED" ] && { echo "❌ No partitions selected"; exit 1; }

case "$COMPRESSION_LEVEL" in
  0) XZ_FLAGS="-0" ;;
  3) XZ_FLAGS="-3" ;;
  6) XZ_FLAGS="-6" ;;
  9) XZ_FLAGS="-9" ;;
  *) XZ_FLAGS="-0" ;;
esac

chmod +x tools/android-tools/* tools/erofs-utils/* 2>/dev/null || true

echo ""; echo "[1/5] Downloading..."
wget -q --tries=3 --timeout=60 --no-check-certificate --content-disposition "$URL"
ZIP_FILE=$(ls -t *.zip 2>/dev/null | head -1)
[ ! -f "$ZIP_FILE" ] && { echo "❌ Download failed"; exit 1; }
FILESIZE=$(stat -c%s "$ZIP_FILE")
[ "$FILESIZE" -eq 0 ] && { echo "❌ Empty file"; exit 1; }
if ! unzip -l "$ZIP_FILE" >/dev/null 2>&1; then
  echo "❌ Downloaded file is not a valid ZIP archive"
  exit 1
fi
echo "✅ Downloaded: $(numfmt --to=iec $FILESIZE)"

CSC_CODE=$(echo "$ZIP_FILE" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z]{3}$' | grep -v -E '^(COM|SAM|FAC)$' | head -1)
AP_CODE=$(echo "$ZIP_FILE" | sed 's/\.zip$//' | tr '_' '\n' | grep -E '^[A-Z][A-Z0-9]{11,}$' | head -1)
echo "$CSC_CODE" > csc_code.txt
echo "$AP_CODE" > ap_code.txt
echo "Firmware: $AP_CODE | CSC: $CSC_CODE"

mv "$ZIP_FILE" firmware.zip

echo ""; echo "[2/5] Extracting ZIP..."
unzip -o "firmware.zip" >/dev/null 2>&1
rm -f "firmware.zip"
echo "✅ Done"

echo ""; echo "[3/5] Extracting AP..."
AP_FILE=$(find . -name "AP_*.tar.md5" -o -name "AP_*.tar" | head -n 1)
[ -z "$AP_FILE" ] && { echo "❌ AP file not found"; exit 1; }
echo "  Extracting: $(basename "$AP_FILE")"

MATCHED=()
while IFS= read -r MEMBER; do
  BASE=$(basename "$MEMBER")
  for PART in $SELECTED; do
    for SUFFIX in "" "_a" "_b"; do
      for EXT in ".img" ".img.lz4"; do
        if [[ "$BASE" == "${PART}${SUFFIX}${EXT}"* ]]; then
          MATCHED+=("$MEMBER")
          break 3
        fi
      done
    done
  done
done < <(tar -tf "$AP_FILE" 2>/dev/null)

if [ ${#MATCHED[@]} -gt 0 ]; then
  tar -xf "$AP_FILE" "${MATCHED[@]}" 2>/dev/null
else
  echo "  ⚠️ No matching images found in AP"
fi

rm -f "$AP_FILE"
echo "✅ Done"

unpack_ramdisk_img() {
  local RD="$1" OUT="$2" LABEL="$3"
  [ -f "$RD" ] || return 0
  local MAGIC
  MAGIC=$(xxd -l 4 -p "$RD" 2>/dev/null)
  local PWD_DIR
  PWD_DIR=$(pwd)
  local RD_ABS="$PWD_DIR/$RD"
  local OUT_ABS="$PWD_DIR/$OUT"
  if [ "$MAGIC" = "e2e1f5e0" ]; then
    if tools/erofs-utils/extract.erofs -i "$RD" -x -o "$OUT/${LABEL}_extracted/" >/dev/null 2>&1; then
      echo "      ✓ $LABEL unpacked (erofs)"
    else
      echo "      ⚠️ $LABEL erofs extraction failed"
    fi
  elif [ "$MAGIC" = "4c5a3430" ]; then
    local RAW="$OUT/${LABEL}.raw"
    lz4 -d "$RD" "$RAW" >/dev/null 2>&1 || true
    if cpio -t < "$RAW" >/dev/null 2>&1; then
      mkdir -p "$OUT/${LABEL}_extracted"
      ( cd "$OUT/${LABEL}_extracted" && cpio -idm < "$RD_ABS" >/dev/null 2>&1 )
      rm -f "$RAW"
      echo "      ✓ $LABEL unpacked (lz4 + cpio)"
    else
      echo "      ⚠️ $LABEL is LZ4 but not cpio"
    fi
  elif cpio -t < "$RD" >/dev/null 2>&1; then
    mkdir -p "$OUT/${LABEL}_extracted"
    ( cd "$OUT/${LABEL}_extracted" && cpio -idm < "$RD_ABS" >/dev/null 2>&1 )
    echo "      ✓ $LABEL unpacked (cpio)"
  else
    echo "      ⚠️ $LABEL format unknown, kept as-is"
  fi
}

echo ""; echo "[4/5] Unpacking boot images..."
mkdir -p processed

for PART in $SELECTED; do
  FILE=$(find . -maxdepth 1 \( -name "${PART}.img.lz4" -o -name "${PART}.img" -o -name "${PART}_a.img.lz4" -o -name "${PART}_a.img" -o -name "${PART}_b.img.lz4" -o -name "${PART}_b.img" \) | head -n 1)
  [ -z "$FILE" ] || [ ! -f "$FILE" ] && { echo "  ⚠️ $PART image not found"; continue; }

  if [[ "$FILE" == *.lz4 ]]; then
    lz4 -d "$FILE" "${FILE%.lz4}" 2>/dev/null || true
    FILE="${FILE%.lz4}"
  fi

  echo ""
  echo "  ► $PART: $(basename "$FILE")"

  if [ "$PART" = "dtbo" ]; then
    echo "    Dumping DTBO contents..."
    if [ -f "tools/android-tools/mkdtboimg" ]; then
      tools/android-tools/mkdtboimg dump "$FILE" --dtb "processed/${PART}.dtb" > "processed/${PART}.info.txt" 2>&1 || true
      [ -f "processed/${PART}.dtb" ] && echo "      ✓ ${PART}.dtb saved"
      [ -s "processed/${PART}.info.txt" ] && echo "      ✓ ${PART}.info.txt saved"
    else
      echo "      ❌ mkdtboimg not found"
    fi
  else
    OUT="processed/${PART}_unpacked"
    mkdir -p "$OUT"
    if [ -f "tools/android-tools/unpack_bootimg" ]; then
      tools/android-tools/unpack_bootimg --boot_img "$FILE" --out "$OUT" >/dev/null 2>&1 || {
        echo "      ❌ unpack_bootimg failed"
        rm -rf "$OUT"
        continue
      }
      echo "      ✓ unpacked by unpack_bootimg"
      for ITEM in "$OUT"/kernel* "$OUT"/dtb "$OUT"/fstab* "$OUT"/second* "$OUT"/bootimg.json "$OUT"/vendor_ramdisk "$OUT"/ramdisk; do
        [ -e "$ITEM" ] && echo "        - $(basename "$ITEM")"
      done
      unpack_ramdisk_img "$OUT/ramdisk" "$OUT" "ramdisk"
      unpack_ramdisk_img "$OUT/vendor_ramdisk" "$OUT" "vendor_ramdisk"
    else
      echo "      ❌ unpack_bootimg not found"
      continue
    fi
  fi

  echo "    Saving AVB info..."
  if [ -f "tools/android-tools/avbtool" ]; then
    tools/android-tools/avbtool info_image --image "$FILE" > "processed/${PART}.avb.txt" 2>&1 || true
    [ -s "processed/${PART}.avb.txt" ] && echo "      ✓ ${PART}.avb.txt saved"
  fi

  rm -f "$FILE"
done

echo ""; echo "[5/5] Packaging..."
for ITEM in processed/*; do
  [ -e "$ITEM" ] || continue
  NAME=$(basename "$ITEM")
  if [ -d "$ITEM" ]; then
    if [ "$COMPRESSION_LEVEL" != "0" ]; then
      tar -cf - -C processed "$NAME" | xz $XZ_FLAGS -T0 2>/dev/null > "processed/${NAME}.tar.xz" && rm -rf "$ITEM"
      echo "    ✓ ${NAME}.tar.xz"
    else
      tar -cf "processed/${NAME}.tar" -C processed "$NAME" && rm -rf "$ITEM"
      echo "    ✓ ${NAME}.tar"
    fi
  elif [ -f "$ITEM" ] && [ "$COMPRESSION_LEVEL" != "0" ] && [[ "$ITEM" != *.xz ]]; then
    xz $XZ_FLAGS -T0 "$ITEM" 2>/dev/null && echo "    ✓ ${NAME}.xz" || true
  fi
done

echo ""; echo "═══════════════════════════════════════"
FILE_COUNT=$(ls -1 processed 2>/dev/null | wc -l)
[ "$FILE_COUNT" -eq 0 ] && { echo "❌ Nothing extracted!"; exit 1; }
(cd processed && sha256sum * > checksums.txt 2>/dev/null || true)
TOTAL_SIZE=$(du -sh processed | cut -f1)
echo "✅ Extracted $FILE_COUNT items"
echo "Total size: $TOTAL_SIZE"
echo ""; echo "Files:"
ls -lh processed
echo "═══════════════════════════════════════"
echo "✅ Done!"
