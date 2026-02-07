# Fork Self-Managed Workflow Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up a self-managed fork workflow where Project-Robius-China/makepad-flow operates independently with self-merged PRs, while maintaining the ability to sync with upstream mofa-org/makepad-flow.

**Architecture:** Two-tier git workflow. origin (Project-Robius-China) is the "working upstream" where PRs are self-created and self-merged. upstream (mofa-org) is the "true upstream" synced periodically. Feature branches follow the existing naming convention and are merged via GitHub PRs for traceability.

**Tech Stack:** Git, GitHub CLI (`gh`), shell scripts

---

## Current State Summary

| Item | Detail |
|------|--------|
| origin | `git@github.com:Project-Robius-China/makepad-flow.git` |
| upstream | `git@github.com:mofa-org/makepad-flow.git` |
| origin/main == upstream/main | Yes, both at `2594bef` |
| Existing feature branches (origin) | 4 branches, all merge cleanly |
| Open PRs on upstream (mofa-org) | #2, #3, #4, #5 — all OPEN, slow to merge |
| Open PRs on origin (Robius-China) | #1 (fix/macos-toolbar-padding) |

### Existing Feature Branches & Merge Order

Tested: all 4 merge cleanly in this order (no conflicts):

1. `fix/macos-toolbar-padding` — 1 commit, touches `examples/dora-viewer/src/app.rs`
2. `refactor/extract-constants` — 1 commit, touches `crates/makepad-flow/src/constants.rs`, `flow_canvas.rs`, `lib.rs`
3. `fix/hierarchical-layout` — 1 commit, touches `examples/dora-viewer/src/app.rs`
4. `refactor/api-improvements` — 2 commits, touches `crates/makepad-flow/src/flow_canvas.rs`

---

## Task 1: Create Missing PRs on Origin (Robius-China)

Currently only `fix/macos-toolbar-padding` has a PR (#1) on origin. Create PRs for the other 3 branches targeting `origin/main`.

**Step 1: Create PR for refactor/extract-constants**

```bash
gh pr create --repo Project-Robius-China/makepad-flow \
  --base main --head refactor/extract-constants \
  --title "Extract magic numbers into constants module" \
  --body "Extracts hardcoded values from flow_canvas.rs into a dedicated constants module for maintainability."
```

**Step 2: Create PR for fix/hierarchical-layout**

```bash
gh pr create --repo Project-Robius-China/makepad-flow \
  --base main --head fix/hierarchical-layout \
  --title "Implement hierarchical layout with barycenter optimization" \
  --body "Adds hierarchical layout algorithm with barycenter heuristic for node ordering."
```

**Step 3: Create PR for refactor/api-improvements**

```bash
gh pr create --repo Project-Robius-China/makepad-flow \
  --base main --head refactor/api-improvements \
  --title "Add FlowCanvasRef and live properties for DSL configuration" \
  --body "Adds FlowCanvasRef for type-safe widget access and converts visual properties to #[live] for DSL configuration."
```

**Step 4: Verify all 4 PRs exist**

```bash
gh pr list --repo Project-Robius-China/makepad-flow --state open
```

Expected: 4 open PRs targeting main.

---

## Task 2: Merge Existing PRs into Origin Main (in order)

Merge the 4 PRs in the tested conflict-free order. Use merge commits (not squash) to preserve history for upstream contribution later.

**Step 1: Merge PR #1 (fix/macos-toolbar-padding)**

```bash
gh pr merge 1 --repo Project-Robius-China/makepad-flow --merge
```

**Step 2: Merge PR for refactor/extract-constants**

```bash
gh pr merge <PR_NUMBER> --repo Project-Robius-China/makepad-flow --merge
```

(Use the PR number from Task 1 Step 1)

**Step 3: Merge PR for fix/hierarchical-layout**

```bash
gh pr merge <PR_NUMBER> --repo Project-Robius-China/makepad-flow --merge
```

**Step 4: Merge PR for refactor/api-improvements**

```bash
gh pr merge <PR_NUMBER> --repo Project-Robius-China/makepad-flow --merge
```

**Step 5: Sync local main**

```bash
git checkout main
git pull origin main
```

**Step 6: Verify**

```bash
git log --oneline -10 main
```

Expected: main now contains all 4 feature branches merged.

---

## Task 3: Create Upstream Sync Script

Create a reusable script for periodic upstream sync operations.

**Files:**
- Create: `scripts/sync-upstream.sh`

**Step 1: Write the sync script**

```bash
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
    echo "✓ origin/main is up-to-date with (or ahead of) upstream/main. No sync needed."
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

echo "✓ Sync complete. origin/main is now rebased on upstream/main."
```

**Step 2: Make executable**

```bash
chmod +x scripts/sync-upstream.sh
```

**Step 3: Commit**

```bash
git add scripts/sync-upstream.sh
git commit -m "chore: add upstream sync script"
```

---

## Task 4: Create Upstream Push Script

Create a script for when you're ready to push accumulated changes to upstream.

**Files:**
- Create: `scripts/push-to-upstream.sh`

**Step 1: Write the push script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# push-to-upstream.sh — Create a PR from origin/main to upstream/main
# Usage: ./scripts/push-to-upstream.sh [--title "PR Title"] [--body "PR Body"]

TITLE="${1:-Sync from Project-Robius-China fork}"
BODY="${2:-Accumulated changes from Project-Robius-China/makepad-flow fork.}"

echo "==> Fetching latest from both remotes..."
git fetch upstream
git fetch origin

UPSTREAM_MAIN=$(git rev-parse upstream/main)
ORIGIN_MAIN=$(git rev-parse origin/main)

ORIGIN_AHEAD=$(git rev-list --count upstream/main..origin/main)

if [[ "$ORIGIN_AHEAD" -eq 0 ]]; then
    echo "✓ No new commits to push upstream."
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

echo "✓ PR created on upstream. Switch back to main:"
echo "  git checkout main"
```

**Step 2: Make executable**

```bash
chmod +x scripts/push-to-upstream.sh
```

**Step 3: Commit**

```bash
git add scripts/push-to-upstream.sh
git commit -m "chore: add upstream push script"
```

---

## Task 5: Handle Upstream PR Deduplication

When upstream eventually merges your PRs (#2-#5), you need to avoid duplicate commits. This task documents the procedure.

**Files:**
- Create: `docs/FORK_WORKFLOW.md`

**Step 1: Write the workflow documentation**

```markdown
# Fork Workflow: Project-Robius-China/makepad-flow

## Remotes

| Remote | Repository | Role |
|--------|-----------|------|
| origin | Project-Robius-China/makepad-flow | Self-managed fork (fast iteration) |
| upstream | mofa-org/makepad-flow | True upstream (slow merge) |

## Daily Workflow

1. Create feature branches from `main`
2. Push to `origin`, create PR targeting `origin/main`
3. Self-review and merge PR on origin
4. Upstream PRs (#2-#5 on mofa-org) remain open for eventual merge

## Syncing FROM Upstream

Run periodically (weekly or when upstream has new changes):

```bash
./scripts/sync-upstream.sh --dry-run  # Preview first
./scripts/sync-upstream.sh            # Execute
```

This rebases your origin/main on top of upstream/main.

## Pushing TO Upstream

When ready to contribute accumulated changes:

```bash
./scripts/push-to-upstream.sh --title "Batch update from Robius-China fork"
```

## When Upstream Merges Your Old PRs

If upstream merges PR #2-#5 (which you've already merged into origin/main):

1. Run `./scripts/sync-upstream.sh --dry-run` to preview
2. Git rebase will automatically skip duplicate changes (same patches)
3. If conflicts arise, they're likely due to upstream modifying your code during merge
4. Resolve conflicts, then `git rebase --continue`

## When Upstream Rejects Your PRs

1. Your changes are already in origin/main — no action needed
2. Optionally close the upstream PR with a comment
3. Changes will be included in future batch pushes via push-to-upstream.sh
```

**Step 2: Commit**

```bash
git add docs/FORK_WORKFLOW.md
git commit -m "docs: add fork workflow guide"
```

---

## Task 6: Clean Up and Final Verification

**Step 1: Delete merged local feature branches**

```bash
git branch -d fix/hierarchical-layout fix/macos-toolbar-padding refactor/api-improvements refactor/extract-constants
```

**Step 2: Verify final state**

```bash
git log --oneline -15 main
echo "---"
git remote -v
echo "---"
gh pr list --repo Project-Robius-China/makepad-flow --state all
echo "---"
gh pr list --repo mofa-org/makepad-flow --state open --author TigerInYourDream
```

**Step 3: Push main with scripts and docs**

```bash
git push origin main
```

---

## Summary of Ongoing Workflow

```
[You] --feature-branch--> [origin/main] --batch-PR--> [upstream/main]
         (self-merge)        (fast)        (periodic)      (slow)
```

1. **Develop** on feature branches
2. **PR + merge** to origin/main (self-managed, fast)
3. **Sync** from upstream weekly: `./scripts/sync-upstream.sh`
4. **Push** to upstream when ready: `./scripts/push-to-upstream.sh`
5. **Upstream old PRs** (#2-#5) will auto-deduplicate on rebase
