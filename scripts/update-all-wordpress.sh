#!/bin/bash

SITES=(
    "wordpressdev-nursing"
)

for SITE in "${SITES[@]}"; do

    echo ""
    echo "=========================================="
    echo "Processing $SITE"
    echo "=========================================="

    ./update-wordpress.sh "$SITE"

    RESULT=$?

    if [ $RESULT -eq 0 ]; then
        echo "$SITE completed successfully."
    else
        echo "$SITE FAILED with exit code $RESULT."
    fi

done
