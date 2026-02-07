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
4. Upstream PRs on mofa-org remain open for eventual merge

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

This creates a dated sync branch and opens a PR on mofa-org/makepad-flow.

## When Upstream Merges Your Old PRs

If upstream merges PRs that you've already merged into origin/main:

1. Run `./scripts/sync-upstream.sh --dry-run` to preview
2. Git rebase will automatically skip duplicate changes (same patches)
3. If conflicts arise, they're likely due to upstream modifying your code during merge
4. Resolve conflicts, then `git rebase --continue`

## When Upstream Rejects Your PRs

1. Your changes are already in origin/main — no action needed
2. Optionally close the upstream PR with a comment
3. Changes will be included in future batch pushes via push-to-upstream.sh
