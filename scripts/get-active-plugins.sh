#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <site1> [site2 ...]"
  exit 1
fi

OUTPUT_FILE="pantheon-active-plugins.csv"

# CSV header
echo '"site","plugin_name","status","version"' > "$OUTPUT_FILE"

for SITE in "$@"; do
  echo "Checking active plugins for: $SITE"

  # Get active plugins as JSON from the Live environment
  terminus wp "${SITE}.live" -- plugin list \
    --status=active \
    --fields=name,status,version \
    --format=json |
  jq -r --arg site "$SITE" '
    .[] |
    [
      $site,
      .name,
      .status,
      .version
    ] |
    @csv
  ' >> "$OUTPUT_FILE"

done

echo
echo "Plugin report saved to: $OUTPUT_FILE"
