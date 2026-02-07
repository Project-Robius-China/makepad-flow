#!/usr/bin/env bash
set -euo pipefail

# sync-upstream.sh — Sync origin/main with upstream/main
# Usage: ./scripts/sync-upstream.sh [--dry-run]

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] Will show what would happen without making changes"
fi

echo "==> Fetching upstream..."
git fetch upstream

echo "==> Fetching origin..."
git fetch origin

# Check divergence
UPSTREAM_MAIN=$(git rev-parse upstream/main)
ORIGIN_MAIN=$(git rev-parse origin/main)
MERGE_BASE=$(git merge-base upstream/main origin/main)

UPSTREAM_AHEAD=$(git rev-list --count origin/main..upstream/main)
ORIGIN_AHEAD=$(git rev-list --count upstream/main..origin/main)

echo ""
echo "=== Sync Status ==="
echo "upstream/main: $UPSTREAM_MAIN"
echo "origin/main:   $ORIGIN_MAIN"
echo "merge-base:    $MERGE_BASE"
echo "upstream ahead by: $UPSTREAM_AHEAD commits"
echo "origin ahead by:   $ORIGIN_AHEAD commits"
echo ""

if [[ "$UPSTREAM_AHEAD" -eq 0 ]]; then
    echo "origin/main is up-to-date with (or ahead of) upstream/main. No sync needed."
    exit 0
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would rebase origin changes on top of upstream/main"
    echo "New commits from upstream:"
    git log --oneline origin/main..upstream/main
    exit 0
fi

echo "==> Checking out main..."
git checkout main

echo "==> Rebasing origin changes on top of upstream/main..."
if ! git rebase upstream/main; then
    echo "ERROR: Rebase conflicts detected. Resolve manually:"
    echo "  1. Fix conflicts"
    echo "  2. git rebase --continue"
    echo "  3. git push origin main --force-with-lease"
    exit 1
fi

echo "==> Pushing rebased main to origin..."
git push origin main --force-with-lease

echo "Sync complete. origin/main is now rebased on upstream/main."
