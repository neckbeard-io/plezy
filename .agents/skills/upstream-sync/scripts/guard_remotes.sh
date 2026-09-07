#!/usr/bin/env bash
set -euo pipefail

# Verify upstream push is disabled
UPSTREAM_PUSH=$(git remote get-url --push upstream 2>/dev/null || echo "")
if [[ "$UPSTREAM_PUSH" != *"DISABLED"* && "$UPSTREAM_PUSH" != *"no_push"* ]]; then
  echo "WARNING: upstream push URL was not disabled ($UPSTREAM_PUSH). Disabling now..."
  git remote set-url --push upstream DISABLED_no_push_to_upstream
fi

echo "Remote safety check passed:"
git remote -v
