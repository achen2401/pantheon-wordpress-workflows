#!/bin/bash

SITES=(
    "site-one"
    "site-two"
    "site-three"
)

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for SITE in "${SITES[@]}"; do

    echo ""
    echo "=========================================="
    echo "Processing $SITE"
    echo "=========================================="

    "$SCRIPT_DIR/update-wordpress.sh" "$SITE"

    RESULT=$?

    if [ $RESULT -eq 0 ]; then
        echo "$SITE completed successfully."
    else
        echo "$SITE FAILED with exit code $RESULT."
    fi

done
