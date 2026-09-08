---
name: upstream-sync
description: >-
  Use this skill whenever a new Plezy version drops or when syncing with upstream releases.
  It guards upstream by bringing updates in through main to origin, creates version-specific testing branches,
  audits the 10 custom features for upstream inclusion or redundancy, and presents interactive choices
  when conflicts arise.
---

# Plezy Upstream Reintegration Skill

This skill automates pulling new upstream Plezy releases, safely guarding upstream by channeling changes through `main` to `origin`, auditing the 10 custom features for upstream inclusion or redundancy, and cleanly re-integrating them into a version-specific testing release branch (`testing-release-<version>`).

---

## Safety & Remote Architecture

* **Never push to `upstream`**: The upstream remote (`git@github.com:edde746/plezy.git`) must only ever be fetched. The push URL is guarded as `DISABLED_no_push_to_upstream`.
* **Guard Upstream via `main`**: All upstream tags and releases are brought into local `main`, which is then pushed to `origin/main`.
* **All Branches Push to `origin`**: Version-based integration branches (`testing-release-<version>`) and feature branches (`<feature>-<version>`) are branched from `main` and pushed exclusively to `origin`.

---

## The 10 Custom Feature Portfolio

Always audit and re-integrate these 10 features in this order:

1. `android-seeking-fix` (ExoPlayer seek transient event suppression)
2. `view-all-breaks-media` (Endpoint-independent artwork cache keys)
3. `per-episode-cast` (Per-episode guest stars & crew on TV details)
4. `watched-refresh` (Continue watching 800ms debounce settle delay)
5. `next-up-fixes` (Cancel play-next exits player instead of black screen)
6. `season-show-long-press` (Go to Season & Go to Series context menus)
7. `osd-focus-changes` (Plex-style timeline focus on select & directional healing)
8. `skip-credit-changes` (Suppress skip reappearance & down-to-timeline navigation)
9. `playlist-enhancements` (Playlist resume unwatched & long-press menus)
10. `per-server-visibility` (Hidden media servers preference & provider)

Detailed references for each feature live in [portfolio_catalog.md](./references/portfolio_catalog.md).

---

## Workflow Steps

### 1. Remote Safety Guard
Run the safety script to confirm upstream push is disabled:
```bash
.agents/skills/upstream-sync/scripts/guard_remotes.sh
```

### 2. Fetch Upstream & Sync `main`
Fetch the latest tags from `upstream`, reset local `main` to the target tag/commit (e.g., `2.19.1`), and push `main` to `origin/main`:
```bash
.agents/skills/upstream-sync/scripts/sync_main.sh <target-version-tag>
```

### 3. Create the Versioned Integration Branch
Create a new version-specific integration branch from the synced `main`:
```bash
VERSION="<target-version>" # e.g. 2.19.1
git checkout main
git checkout -b "testing-release-${VERSION}"
```

### 4. Audit Custom Features
Run the audit script to check each of the 10 features against the target release:
```bash
python3 .agents/skills/upstream-sync/scripts/audit_features.py <target-version>
```

For each feature:
1. **Upstream Redundancy Check**: Check if upstream introduced equivalent functionality or if the patch is obsolete.
   - If upstream fully implemented the fix: Document that the feature is upstreamed, update `AGENTS.md`, and skip the local branch.
2. **Clean Apply**: If the feature cherry-picks/rebases cleanly onto `main`:
   - Create `<feature>-${VERSION}` from `main`.
   - Cherry-pick the feature commit (`git cherry-pick <commit>`).
   - Merge `<feature>-${VERSION}` into `testing-release-${VERSION}` using `--no-edit`.
3. **Conflicts / Structural Skew**: If upstream refactored the file (e.g., settings screen restructuring or D-pad extensions):
   - Analyze the conflict.
   - If the resolution involves a non-trivial architectural choice or trade-off, present the user with choices using `ask_question`.
   - Resolve the conflict, complete the cherry-pick, and merge into `testing-release-${VERSION}`.

### 5. Verify Build & Tests
Verify that the codebase compiles and critical tests pass:
```bash
flutter analyze lib/
flutter test
```

### 6. Push to `origin`
Push all updated versioned branches to `origin`:
```bash
git push -u origin "testing-release-${VERSION}"
# Push each rebased feature branch to origin
```

### 7. Update Documentation
Update `/Users/mike/repo/plezy/AGENTS.md` to record the new versioned release branch and any changes to the feature portfolio status.
