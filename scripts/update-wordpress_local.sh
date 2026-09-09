#!/bin/zsh

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

# Track whether we switched Dev to Git mode.
DEV_IN_GIT_MODE=false

# --------------------------------------------------
# Cleanup
# --------------------------------------------------

cleanup() {
    if [ "$DEV_IN_GIT_MODE" = true ]; then
        echo ""
        echo "Switching $SITE.dev back to SFTP mode..."

        if terminus connection:set "$SITE.dev" sftp; then
            echo "$SITE.dev is back in SFTP mode."
        else
            echo "WARNING: Could not switch $SITE.dev back to SFTP mode."
        fi
    fi
}

# Run cleanup whenever the script exits.
trap cleanup EXIT

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

DEV_IN_GIT_MODE=true

# --------------------------------------------------
# 2. Refresh upstream update information
# --------------------------------------------------

echo ""
echo "Refreshing upstream update information..."

if ! terminus site:upstream:clear-cache "$SITE"; then
    echo "ERROR: Could not refresh upstream update information for $SITE."
    exit 1
fi

# --------------------------------------------------
# 3. Check for upstream updates
# --------------------------------------------------

echo ""
echo "Checking for upstream updates..."

if ! UPDATES=$(terminus upstream:updates:list "$SITE.dev" --field=hash); then
    echo "ERROR: Could not check upstream updates for $SITE."
    exit 1
fi

if [ -z "$UPDATES" ]; then
    echo "No upstream updates available for $SITE."
    exit 0
fi

echo ""
echo "Upstream update(s) available:"
echo "$UPDATES"

# --------------------------------------------------
# 4. Apply update to Dev
# --------------------------------------------------

echo ""
echo "Applying upstream update to Dev..."

if ! terminus upstream:updates:apply "$SITE.dev"; then
    echo "ERROR: Upstream update failed for $SITE."
    exit 1
fi

echo "Upstream update successfully applied to Dev."

# --------------------------------------------------
# 5. Deploy Dev -> Test
# --------------------------------------------------

echo ""
echo "Deploying Dev -> Test..."

if ! terminus env:deploy "$SITE.test" \
    --note="$NOTE"; then

    echo "ERROR: Deployment to Test failed."
    exit 1
fi

echo "Deployment to Test completed."

# --------------------------------------------------
# 6. Clear Test cache
# --------------------------------------------------

echo ""
echo "Clearing cache on $SITE.test..."

if ! terminus env:clear-cache "$SITE.test"; then
    echo "ERROR: Could not clear cache on $SITE.test."
    exit 1
fi

# --------------------------------------------------
# 7. Test Test environment
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
# 8. Deploy Test -> Live
# --------------------------------------------------

echo ""
echo "Deploying Test -> Live..."

if ! terminus env:deploy "$SITE.live" \
    --note="$NOTE"; then

    echo "ERROR: Deployment to Live failed."
    exit 1
fi

echo "Deployment to Live completed."

# --------------------------------------------------
# 9. Clear Live cache
# --------------------------------------------------

echo ""
echo "Clearing cache on $SITE.live..."

if ! terminus env:clear-cache "$SITE.live"; then
    echo "ERROR: Could not clear cache on $SITE.live."
    exit 1
fi

# --------------------------------------------------
# 10. Check Live
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

echo "Live environment check passed."

# --------------------------------------------------
# Finished
# --------------------------------------------------

echo ""
echo "=========================================="
echo "SUCCESS: $SITE updated successfully."
echo "=========================================="

exit 0
