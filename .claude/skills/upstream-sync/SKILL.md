---
name: upstream-sync
description: >-
  Use this skill whenever a new upstream Plezy version/tag drops (e.g. 2.24.0) or when asked to sync,
  merge, or rebase onto upstream. It guards upstream by bringing updates in through main to origin,
  creates the version-specific testing-release branch, audits every local commit and custom feature
  for upstream inclusion or conflicts, carries them onto the new branch, and asks the user when a
  conflict needs a real decision.
---

# Plezy Upstream Reintegration Skill

This skill pulls a new upstream Plezy release, guards upstream by channeling changes through `main` to `origin`, audits every local customization for upstream inclusion or redundancy, and carries them onto one version-specific branch, `testing-release-<version>`.

There are **no per-feature branches**. Every local change lives as plain commits on the testing-release branch, so carrying a release forward means cherry-picking the previous branch's local commits, in order, onto the new tag. The goal is that **every** customization survives: the portfolio features, any loose fixes, and the skill/agent tooling directories.

---

## Safety & Remote Architecture

* **Never push to `upstream`**: The upstream remote (`https://github.com/edde746/plezy.git`) must only ever be fetched. Its push URL is guarded as `DISABLED_no_push_to_upstream`.
* **Guard Upstream via `main`**: Upstream tags and releases are brought into local `main`, which is then pushed to `origin/main`. `main` carries no local changes.
* **One branch per release, pushed to `origin`**: `testing-release-<version>` is branched from `main` and pushed only to `origin`.
* **Non-interactive git only**: Use `-m`, `--no-edit`, and `GIT_EDITOR=true`. Never use `-i`.
* **Commit identity**: Commit as configured (`brutog <brutog@users.noreply.github.com>`); check `git config user.email` before the first commit. Use Conventional Commits and no AI/co-author trailers (see the user's git rules).
* **Re-stamp every carried commit**: `git cherry-pick` keeps the original author, so a bad identity on an old commit gets copied into every new release. Right after each pick (or `cherry-pick --continue`), run `git commit --amend --no-edit --reset-author`.

---

## The Custom Feature Portfolio

1. `android-seeking-fix` (ExoPlayer seek transient event suppression)
2. `view-all-breaks-media` (Endpoint-independent artwork cache keys)
3. `per-episode-cast` (Per-episode guest stars & crew on TV details)
4. `watched-refresh` (Continue Watching 800ms debounce settle delay)
5. `next-up-fixes` (Cancel play-next exits player instead of black screen)
6. `season-show-long-press` (Go to Season & Go to Series context menus)
7. `osd-focus-changes` (Plex-style timeline focus on select & directional healing)
8. `skip-credit-changes` (Suppress skip reappearance & down-to-timeline navigation)
9. `playlist-enhancements` (Playlist resume & single-press Back exit)
10. `per-server-visibility` (Hidden media servers preference & provider)
11. `osd-air-date` (Air date / release year and active player in the OSD header)
12. `watched-total-count` (Watched/total badge, including series counts on Continue Watching)

Details for each feature (purpose, key files, what to check upstream, last known commit) live in [portfolio_catalog.md](./references/portfolio_catalog.md). `AGENTS.md` at the repo root holds a summary of the same catalog. The audit script's `FEATURES` map mirrors the catalog's key files; keep the three in sync when a feature is added or its files move.

---

## Workflow Steps

Throughout, `PREV` is the previous release (the newest existing `testing-release-<semver>` branch, e.g. `2.23.0`) and `VERSION` is the new upstream tag (e.g. `2.24.0`).

### 1. Remote Safety Guard
```bash
.claude/skills/upstream-sync/scripts/guard_remotes.sh
```

### 2. Fetch Upstream & Sync `main`
Fetch upstream tags, reset local `main` to the target tag, and push `main` to `origin/main`:
```bash
.claude/skills/upstream-sync/scripts/sync_main.sh <target-version-tag>
```
Make sure the working tree is clean first; the script runs `git reset --hard`.

### 3. Create the Versioned Integration Branch
```bash
VERSION="<target-version>" # e.g. 2.24.0
git checkout main
git checkout -b "testing-release-${VERSION}"
```

### 4. Restore Agent Tooling
Upstream doesn't carry the local skill directories, so a fresh branch from `main` drops them. Restore them from the previous release and commit:
```bash
git checkout "testing-release-${PREV}" -- .claude .agents
git commit -m "chore: restore agent skill directories"
```
(`AGENTS.md` is excluded via `.git/info/exclude`, so it's untouched by branch switches.)

### 5. Audit Local Commits
```bash
python3 .claude/skills/upstream-sync/scripts/audit_features.py <target-version> [<prev-version>]
```
The script lists every local commit on `testing-release-${PREV}` (everything not in the `PREV` tag) in carry-forward order. For each commit it shows:
- the portfolio feature it belongs to, by key files ("loose commit" if none match);
- an identity warning if its author or committer isn't the configured `user.email`;
- upstream commits since `PREV` that touched the same files;
- a CLEAN or CONFLICT dry run of cherry-picking it after all the earlier commits.

Commits that only touch `.claude/` or `.agents/` are marked as tooling and skipped, since step 4 restores those directories.

It ends by listing **portfolio features with no commits**. Each one was either upstreamed or dropped by accident in a past sync. Find the last release branch that still has it (`git log <ver>..testing-release-<ver> -- <key files>`), and check that upstream really covers it before treating it as upstreamed.

### 6. Carry Commits Forward
Work through the audit list in order, one commit at a time:
1. **Upstream Redundancy Check**: Read the upstream changes to the commit's files (`git log -p ${PREV}..${VERSION} -- <files>`). Decide whether upstream now covers it fully, partly, or not at all.
   - Fully upstreamed: skip the commit, record it in the catalog and `AGENTS.md`, and tell the user.
   - Partly upstreamed: carry over only the parts upstream lacks, and say in the commit body what was dropped and why.
2. **Clean Apply**:
   ```bash
   git cherry-pick <commit>
   git commit --amend --no-edit --reset-author     # cherry-pick keeps the old author
   ```
3. **Conflicts / Structural Skew** (upstream moved or refactored the code):
   - Read both sides and understand what upstream changed before resolving anything.
   - Port the feature's *intent* onto the new structure. Don't drop hunks just to make the conflict go away.
   - If the resolution needs a real architectural choice or trade-off (e.g. keep our setting vs. adopt upstream's equivalent, or which of two behaviors wins), ask the user with `AskUserQuestion` before continuing.
   - Generated i18n files (`lib/i18n/strings*.g.dart`) conflict on almost every sync. Don't hand-merge them: resolve the source `lib/i18n/*.i18n.json` files, then regenerate with `dart run slang` and stage the output.
   - Finish with `GIT_EDITOR=true git cherry-pick --continue` and `git commit --amend --no-edit --reset-author`.
4. **Several commits for one feature** (e.g. a feature plus a later fix) can be squashed into one while carrying them, if they still read as one change. Never squash commits from different features together.

### 7. Verify Build & Tests
```bash
flutter pub get
flutter analyze lib/ test/
flutter test
```
Fix anything the reintegration broke in the commit it belongs to: `git commit --fixup=<commit>` and then `git rebase --autosquash "${VERSION}"`. That keeps each feature as one coherent commit instead of piling fix-ups on top. `--autosquash` works without `-i` on git ≥ 2.44.

### 8. Verify Nothing Was Lost
Compare the old and new local commit lists. Every old commit should map to a new one, or be one you deliberately skipped as upstreamed:
```bash
git range-diff "${PREV}..testing-release-${PREV}" "${VERSION}..testing-release-${VERSION}"
```
Then confirm every new commit carries the right identity. This must print nothing:
```bash
git log --format='%h %ae %ce %s' "${VERSION}..testing-release-${VERSION}" \
  | grep -v ' brutog@users.noreply.github.com brutog@users.noreply.github.com '
```
For any feature you resolved by hand, spot-check its key files for its marker symbols (e.g. `selectShowsOsdTimeline`, `suppressSkipReappearance`, `HiddenServersProvider`, `showWatchedTotalCount`).

### 9. Push to `origin`
```bash
git push -u origin "testing-release-${VERSION}"
```

### 10. Update Documentation
- Update `references/portfolio_catalog.md` in **both** `.claude/skills/upstream-sync/` and `.agents/skills/upstream-sync/`, and the summary in `AGENTS.md`: record the new commit hashes, any feature that was upstreamed, and any change in key files. Keep the audit script's `FEATURES` map in step.
- Commit the catalog changes on `testing-release-${VERSION}` so the next sync restores them, then push again.

### 11. Report
Give the user a per-feature table: clean / resolved conflict / partly upstreamed / fully upstreamed, plus the loose commits carried, build and test results, and the pushed branch name. Offer a streaming install to the Shields (see `AGENTS.md`).
