#!/usr/bin/env bash
set -euo pipefail

TARGET_REF="${1:-2.19.0}"

# 1. Enforce remote safety
"$(dirname "$0")/guard_remotes.sh"

# 2. Fetch upstream tags and refs
echo "Fetching latest tags and commits from upstream..."
git fetch upstream --tags

# 3. Check out main
git checkout main

# 4. Reset main to target release ref
echo "Syncing main to upstream target ref: $TARGET_REF"
git reset --hard "$TARGET_REF"

# 5. Push updated main to origin (never upstream)
echo "Pushing synced main to origin/main..."
git push origin main

echo "main is now synced to $(git rev-parse --short HEAD) ($TARGET_REF) and pushed to origin/main."
