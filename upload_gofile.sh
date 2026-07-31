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

FILE="$1"
if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

echo "Uploading to GoFile..."

# Optional pre-authenticated token (higher limits), falls back to guest token
TOKEN="${GOFILE_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  TOKEN_RESPONSE=$(curl -s -X POST https://api.gofile.io/accounts)
  TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.data.token' 2>/dev/null)
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "❌ Failed to get GoFile token"
  exit 1
fi

SERVER=$(curl -s "https://api.gofile.io/servers?token=$TOKEN" | jq -r '.data.servers[0].name' 2>/dev/null)
[ -z "$SERVER" ] && SERVER="store1"

RESPONSE=""
for ATTEMPT in 1 2 3; do
  RESPONSE=$(curl -s --retry 2 --retry-delay 3 --retry-all-errors -X POST \
    -F "file=@$FILE" \
    -F "token=$TOKEN" \
    "https://${SERVER}.gofile.io/uploadFile")

  if echo "$RESPONSE" | grep -q '"status":"ok"'; then
    DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r '.data.downloadPage')
    echo "✅ Upload successful!"
    echo "$DOWNLOAD_URL"
    echo "$DOWNLOAD_URL" > download_url.txt
    exit 0
  fi

  echo "⚠️ Upload attempt $ATTEMPT failed, retrying..." >&2
  sleep 5
done

echo "❌ Upload failed after multiple attempts"
echo "Response: $RESPONSE"
exit 1
