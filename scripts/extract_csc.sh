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
echo "   Samsung CSC / OMC Extractor"
echo "═══════════════════════════════════════"

URL="$1"
[ -z "$URL" ] && { echo "❌ No URL provided"; exit 1; }
if ! echo "$URL" | grep -qE '^https?://'; then
  echo "❌ Invalid URL: must start with http:// or https://"
  exit 1
fi
COMPRESSION_LEVEL="${2:-0}"
WANT_CSC="${3:-false}"
WANT_OMC="${4:-false}"
WANT_PIT="${5:-false}"
WANT_CP="${6:-false}"

if [ "$WANT_CSC" != "true" ] && [ "$WANT_OMC" != "true" ] && [ "$WANT_PIT" != "true" ] && [ "$WANT_CP" != "true" ]; then
  echo "❌ No targets selected!"
  exit 1
fi

case "$COMPRESSION_LEVEL" in
  0) XZ_FLAGS="-0" ;;
  3) XZ_FLAGS="-3" ;;
  6) XZ_FLAGS="-6" ;;
  9) XZ_FLAGS="-9" ;;
  *) XZ_FLAGS="-0" ;;
esac

echo ""; echo "[1/4] Downloading..."
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

echo ""; echo "[2/4] Extracting ZIP..."
unzip -o "firmware.zip" >/dev/null 2>&1
rm -f "firmware.zip"
echo "✅ Done"

echo ""; echo "[3/4] Finding CSC file..."
CSC_FILE=$(find . -maxdepth 1 \( -name "CSC_*.tar.md5" -o -name "CSC_*.tar" -o -name "HOME_CSC_*.tar.md5" -o -name "HOME_CSC_*.tar" \) | head -n 1)
if [ -z "$CSC_FILE" ]; then
  echo "❌ CSC file not found in firmware zip"
  exit 1
fi
echo "  Found: $(basename "$CSC_FILE")"
CSC_MEMBERS=$(tar -tf "$CSC_FILE" 2>/dev/null)
echo "  Archive contents:"
echo "  ┌─────────────────────────────────────────────┐"
while IFS= read -r M; do
  [ -z "$M" ] && continue
  printf "  │ %-45s\n" "$M"
done <<< "$(echo "$CSC_MEMBERS" | head -25)"
echo "  └─────────────────────────────────────────────┘"

mkdir -p output

echo ""; echo "[4/4] Extracting targets..."

if [ "$WANT_CSC" = "true" ]; then
  if echo "$CSC_MEMBERS" | grep -qE '^(\./)?csc/'; then
    echo "  Extracting csc/ folder..."
    tar -xf "$CSC_FILE" --wildcards './csc/*' 2>/dev/null || tar -xf "$CSC_FILE" --wildcards 'csc/*' 2>/dev/null || true
    if [ -d "csc" ]; then
      cp -r csc output/ && echo "    ✓ csc"
    elif [ -d "./csc" ]; then
      cp -r ./csc output/ && echo "    ✓ csc"
    fi
  else
    echo "  ⚠️ No csc/ folder inside archive"
  fi
fi

if [ "$WANT_OMC" = "true" ]; then
  if echo "$CSC_MEMBERS" | grep -qE '^(\./)?omc/'; then
    echo "  Extracting omc/ folder..."
    tar -xf "$CSC_FILE" --wildcards './omc/*' 2>/dev/null || tar -xf "$CSC_FILE" --wildcards 'omc/*' 2>/dev/null || true
    if [ -d "omc" ]; then
      cp -r omc output/ && echo "    ✓ omc"
    elif [ -d "./omc" ]; then
      cp -r ./omc output/ && echo "    ✓ omc"
    fi
  else
    echo "  ⚠️ No omc/ folder inside archive"
  fi
fi

if [ "$WANT_CP" = "true" ]; then
  CP_FILE=$(find . -maxdepth 1 \( -name "CP_*.tar.md5" -o -name "CP_*.tar" \) | head -n 1)
  if [ -n "$CP_FILE" ]; then
    echo "  Extracting CP modem contents..."
    mkdir -p cp_extracted
    tar -xf "$CP_FILE" -C cp_extracted >/dev/null 2>&1 || true
    if ls cp_extracted/* >/dev/null 2>&1; then
      cp -r cp_extracted/* output/ 2>/dev/null && echo "    ✓ CP files"
    else
      echo "  ⚠️ CP tar empty or failed"
    fi
  else
    echo "  ⚠️ CP file not found"
  fi
fi

if [ "$WANT_PIT" = "true" ]; then
  echo "  Looking for PIT files..."
  PIT_COUNT=0
  while IFS= read -r PIT; do
    [ -z "$PIT" ] && continue
    tar -xf "$CSC_FILE" "$PIT" 2>/dev/null || true
    PIT_BASE=$(basename "$PIT")
    if [ -f "$PIT_BASE" ]; then
      cp "$PIT_BASE" "output/$PIT_BASE" && { echo "    ✓ $PIT_BASE"; PIT_COUNT=$((PIT_COUNT + 1)); }
    fi
  done <<< "$(echo "$CSC_MEMBERS" | grep -i '\.pit$')"
  [ "$PIT_COUNT" -eq 0 ] && echo "  ⚠️ No PIT file found"
fi

rm -rf csc omc cp_extracted 2>/dev/null || true

echo ""; echo "Packaging output..."
for ITEM in output/*; do
  [ -e "$ITEM" ] || continue
  NAME=$(basename "$ITEM")
  if [ -d "$ITEM" ]; then
    if [ "$COMPRESSION_LEVEL" != "0" ]; then
      tar -cf - -C output "$NAME" | xz $XZ_FLAGS -T0 2>/dev/null > "output/${NAME}.tar.xz" && rm -rf "$ITEM"
      echo "    ✓ ${NAME}.tar.xz"
    else
      tar -cf "output/${NAME}.tar" -C output "$NAME" && rm -rf "$ITEM"
      echo "    ✓ ${NAME}.tar"
    fi
  elif [ -f "$ITEM" ] && [ "$COMPRESSION_LEVEL" != "0" ] && [[ "$ITEM" != *.xz ]]; then
    xz $XZ_FLAGS -T0 "$ITEM" 2>/dev/null && echo "    ✓ ${NAME}.xz" || true
  fi
done

echo ""; echo "═══════════════════════════════════════"
FILE_COUNT=$(ls -1 output 2>/dev/null | wc -l)
[ "$FILE_COUNT" -eq 0 ] && { echo "❌ Nothing extracted!"; exit 1; }
(cd output && sha256sum * > checksums.txt 2>/dev/null || true)
TOTAL_SIZE=$(du -sh output | cut -f1)
echo "✅ Extracted $FILE_COUNT items"
echo "Total size: $TOTAL_SIZE"
echo ""; echo "Files:"
ls -lh output
echo "═══════════════════════════════════════"
echo "✅ Done!"
