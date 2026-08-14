#!/bin/bash

set -u

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SITE="${1:-}"

if [ -z "$SITE" ]; then
    echo "Usage: $0 <pantheon-site-name>"
    echo ""
    echo "Example:"
    echo "  $0 wordpressdev-nursing"
    exit 1
fi

NOTE="Automated WordPress upstream update $(date '+%Y-%m-%d')"

echo "=========================================="
echo "Pantheon WordPress Update"
echo "Site: $SITE"
echo "=========================================="

# --------------------------------------------------
# 1. Switch Dev to Git mode
# --------------------------------------------------

echo ""
echo "Switching $SITE.dev to Git mode..."

if ! terminus connection:set "$SITE.dev" git; then
    echo "ERROR: Could not switch $SITE.dev to Git mode."
    exit 1
fi

# --------------------------------------------------
# 2. Check for upstream updates
# --------------------------------------------------

echo ""
echo "Checking for upstream updates..."

UPDATES=$(terminus upstream:updates:list "$SITE.dev" --format=list --field=id 2>/dev/null)

if [ -z "$UPDATES" ]; then
    echo "No upstream updates available for $SITE."

    echo ""
    echo "Switching $SITE.dev back to SFTP mode..."

    if ! terminus connection:set "$SITE.dev" sftp; then
        echo "ERROR: Could not switch $SITE.dev to SFTP mode."
        exit 1
    fi

    exit 0
fi

echo "Upstream update available:"
echo "$UPDATES"

# --------------------------------------------------
# 3. Apply update to Dev
# --------------------------------------------------

echo ""
echo "Applying upstream update to Dev..."

if ! terminus upstream:updates:apply "$SITE.dev" --updatedb; then
    echo "ERROR: Upstream update failed for $SITE."
    exit 1
fi

# --------------------------------------------------
# 4. Deploy Dev -> Test
# --------------------------------------------------

echo ""
echo "Deploying Dev -> Test..."

if ! terminus env:deploy "$SITE.test" \
    --note="$NOTE"; then

    echo "ERROR: Deployment to Test failed."
    exit 1
fi

# --------------------------------------------------
# 5. Test Test environment
# --------------------------------------------------

TEST_URL="https://test-${SITE}.pantheonsite.io"

echo ""
echo "Checking Test environment:"
echo "$TEST_URL"

if ! curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "$TEST_URL" > /dev/null; then

    echo "ERROR: Test environment health check failed."
    echo "Live deployment has been cancelled."
    exit 1
fi

echo "Test environment check passed."

# --------------------------------------------------
# 6. Deploy Test -> Live
# --------------------------------------------------

echo ""
echo "Deploying Test -> Live..."

if ! terminus env:deploy "$SITE.live" \
    --note="$NOTE"; then

    echo "ERROR: Deployment to Live failed."
    exit 1
fi

# --------------------------------------------------
# 7. Check Live
# --------------------------------------------------

LIVE_URL="https://live-${SITE}.pantheonsite.io"

echo ""
echo "Checking Live environment:"
echo "$LIVE_URL"

if ! curl \
    --fail \
    --silent \
    --show-error \
    --location \
    "$LIVE_URL" > /dev/null; then

    echo "WARNING: Live deployment completed, but health check failed."
    exit 1
fi

echo ""
echo "=========================================="
echo "SUCCESS: $SITE updated successfully."
echo "=========================================="


echo ""
echo "Clearing cache on $SITE.live..."

if ! terminus env:clear-cache "$SITE.live"; then
    echo "ERROR: Could not clear cache on $SITE.live."
    exit 1
fi


echo ""
echo "Switching $SITE.dev to SFTP mode..."

if ! terminus connection:set "$SITE.dev" sftp; then
    echo "ERROR: Could not switch $SITE.dev to SFTP mode."
    exit 1
fi

exit 0
