#!/usr/bin/env bash
set -euo pipefail

# push-to-upstream.sh — Create a PR from origin/main to upstream/main
# Usage: ./scripts/push-to-upstream.sh [--title "PR Title"] [--body "PR Body"]

TITLE="Sync from Project-Robius-China fork"
BODY="Accumulated changes from Project-Robius-China/makepad-flow fork."

while [[ $# -gt 0 ]]; do
    case $1 in
        --title) TITLE="$2"; shift 2 ;;
        --body) BODY="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "==> Fetching latest from both remotes..."
git fetch upstream
git fetch origin

UPSTREAM_MAIN=$(git rev-parse upstream/main)
ORIGIN_MAIN=$(git rev-parse origin/main)

ORIGIN_AHEAD=$(git rev-list --count upstream/main..origin/main)

if [[ "$ORIGIN_AHEAD" -eq 0 ]]; then
    echo "No new commits to push upstream."
    exit 0
fi

echo "==> $ORIGIN_AHEAD commits to push upstream:"
git log --oneline upstream/main..origin/main
echo ""

# Create a branch for the upstream PR
BRANCH_NAME="sync/robius-china-$(date +%Y%m%d)"
echo "==> Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME" origin/main

echo "==> Pushing branch to origin..."
git push origin "$BRANCH_NAME"

echo "==> Creating PR on upstream..."
gh pr create --repo mofa-org/makepad-flow \
  --base main \
  --head "Project-Robius-China:$BRANCH_NAME" \
  --title "$TITLE" \
  --body "$BODY"

echo "PR created on upstream. Switch back to main:"
echo "  git checkout main"
