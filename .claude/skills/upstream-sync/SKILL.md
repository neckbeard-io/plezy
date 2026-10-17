---
name: upstream-sync
description: >-
  Use this skill whenever a new upstream Plezy version/tag drops (e.g. 2.24.0) or when asked to sync,
  merge, or rebase onto upstream. It guards upstream by bringing updates in through main to origin,
  creates the version-specific testing-release branch, audits every custom feature for upstream
  inclusion or conflicts, re-integrates each one on its own <feature>-<version> branch, and asks the
  user when a conflict needs a real decision.
---

# Plezy Upstream Reintegration Skill

This skill pulls a new upstream Plezy release, guards upstream by channeling changes through `main` to `origin`, audits every custom feature for upstream inclusion or redundancy, and re-integrates them into a version-specific testing release branch (`testing-release-<version>`).

The goal is that **every** local customization survives the sync: the 10 portfolio features, any loose commits made directly on the previous testing-release branch, and the skill/agent tooling directories.

---

## Safety & Remote Architecture

* **Never push to `upstream`**: The upstream remote (`https://github.com/edde746/plezy.git`) must only ever be fetched. Its push URL is guarded as `DISABLED_no_push_to_upstream`.
* **Guard Upstream via `main`**: Upstream tags and releases are brought into local `main`, which is then pushed to `origin/main`. `main` carries no local changes.
* **All Branches Push to `origin`**: The integration branch (`testing-release-<version>`) and feature branches (`<feature>-<version>`) are branched from `main` and pushed only to `origin`.
* **Non-interactive git only**: Use `-m`, `--no-edit`, and `GIT_EDITOR=true`. Never use `-i`.
* **Commit identity**: Commit as configured (`brutog <brutog@users.noreply.github.com>`); check `git config user.email` before the first commit. Use Conventional Commits and no AI/co-author trailers (see the user's git rules).
* **Re-stamp every carried commit**: `git cherry-pick` keeps the original author, so a bad identity on an old commit gets copied into every new release branch. Pick commits one at a time, and right after each pick (or `cherry-pick --continue`) run `git commit --amend --no-edit --reset-author`.

---

## The Custom Feature Portfolio

Audit and re-integrate these features in this order:

1. `android-seeking-fix` (ExoPlayer seek transient event suppression)
2. `view-all-breaks-media` (Endpoint-independent artwork cache keys)
3. `per-episode-cast` (Per-episode guest stars & crew on TV details)
4. `watched-refresh` (Continue Watching 800ms debounce settle delay)
5. `next-up-fixes` (Cancel play-next exits player instead of black screen)
6. `season-show-long-press` (Go to Season & Go to Series context menus)
7. `osd-focus-changes` (Plex-style timeline focus on select & directional healing)
8. `skip-credit-changes` (Suppress skip reappearance & down-to-timeline navigation)
9. `playlist-enhancements` (Playlist resume unwatched & long-press menus)
10. `per-server-visibility` (Hidden media servers preference & provider)

Details for each feature (purpose, key files, what to check upstream, last known commit) live in [portfolio_catalog.md](./references/portfolio_catalog.md). `AGENTS.md` at the repo root holds the same catalog.

---

## Workflow Steps

Throughout, `PREV` is the previous integration version (the newest existing `testing-release-<semver>` branch, e.g. `2.23.0`) and `VERSION` is the new upstream tag (e.g. `2.24.0`).

### 1. Remote Safety Guard
Confirm the upstream push URL is disabled:
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
Upstream doesn't carry the local skill directories, so a fresh branch from `main` drops them. Restore them from the previous integration branch and commit:
```bash
git checkout "testing-release-${PREV}" -- .claude .agents
git commit -m "chore: restore agent skill directories"
```
(`AGENTS.md` is excluded via `.git/info/exclude`, so it's untouched by branch switches.)

### 5. Audit Custom Features
```bash
python3 .claude/skills/upstream-sync/scripts/audit_features.py <target-version> [<prev-version>]
```
For each feature, the script finds the newest `<feature>-<semver>` branch, lists its commits on top of the release it was built on, counts upstream commits touching the same files since `PREV`, and dry-runs the cherry-pick with `git merge-tree`. It also lists **loose commits** made directly on `testing-release-${PREV}` (outside the feature merges) that must be carried forward too.

It also flags any feature or loose commit whose author or committer email isn't the configured `user.email`; reset those when carrying them over.

It flags a feature whose latest branch has **no commits** of its own. That means the feature was either upstreamed or dropped by accident in a past sync. Find the last version branch that still has the commit and check whether upstream really covers it before treating it as upstreamed.

Then for each feature, in portfolio order:
1. **Upstream Redundancy Check**: Read the upstream changes to the key files (`git log -p ${PREV}..${VERSION} -- <files>`). Decide whether upstream now covers the feature fully, partly, or not at all.
   - Fully upstreamed: create no branch, record it in `AGENTS.md` and the catalog, and tell the user.
   - Partly upstreamed: carry over only the parts upstream lacks, and say in the commit body what was dropped and why.
2. **Clean Apply**:
   ```bash
   git checkout -b "<feature>-${VERSION}" main
   git cherry-pick <commit>                        # one commit at a time
   git commit --amend --no-edit --reset-author     # cherry-pick keeps the old author
   git checkout "testing-release-${VERSION}"
   git merge --no-ff --no-edit "<feature>-${VERSION}"
   ```
3. **Conflicts / Structural Skew** (upstream moved or refactored the code):
   - Read both sides and understand what upstream changed before resolving anything.
   - Port the feature's *intent* onto the new structure. Don't drop hunks just to make the conflict go away.
   - If the resolution needs a real architectural choice or trade-off (e.g. keep our setting vs. adopt upstream's equivalent, or which of two behaviors wins), ask the user with `AskUserQuestion` before continuing.
   - Generated i18n files (`lib/i18n/strings*.g.dart`) conflict on almost every sync. Don't hand-merge them: resolve the source `lib/i18n/*.i18n.json` files, then regenerate with `dart run slang` and stage the output.
   - Finish with `GIT_EDITOR=true git cherry-pick --continue` and `git commit --amend --no-edit --reset-author`, then merge into `testing-release-${VERSION}` as above.
4. **Loose commits**: Cherry-pick each loose commit the audit listed straight onto `testing-release-${VERSION}`, resetting the author after each one. Skip earlier "restore skills directory" commits, since step 4 covers them. Run the same redundancy check: if upstream fixed the same bug, drop the commit and say so.

### 6. Verify Build & Tests
```bash
flutter pub get
flutter analyze lib/
flutter test
```
Fix anything the reintegration broke, in the feature branch it belongs to. Amend that feature's commit and re-merge rather than adding fix-up commits on the integration branch.

### 7. Verify Nothing Was Lost
Before pushing, confirm every feature is present:
```bash
git log --oneline --first-parent "${VERSION}..testing-release-${VERSION}"
```
There should be one merge per non-upstreamed feature plus the carried loose commits. Then confirm every new commit carries the right identity. This must print nothing:
```bash
git log --format='%h %ae %ce %s' "${VERSION}..testing-release-${VERSION}" \
  | grep -v ' brutog@users.noreply.github.com brutog@users.noreply.github.com '
```
For any feature you resolved by hand, spot-check its key files for its marker symbols (e.g. `selectShowsOsdTimeline`, `suppressSkipReappearance`, `HiddenServersProvider`).

### 8. Push to `origin`
```bash
git push -u origin "testing-release-${VERSION}"
for b in $(git branch --list "*-${VERSION}" --format='%(refname:short)'); do git push -u origin "$b"; done
```

### 9. Update Documentation
- Update `AGENTS.md` (repo root) and `references/portfolio_catalog.md` in **both** `.claude/skills/upstream-sync/` and `.agents/skills/upstream-sync/`: record the new commit hashes and branches, any feature that was upstreamed, and any change in key files.
- If the catalog or skill changed, commit that on `testing-release-${VERSION}` so the next sync restores it.

### 10. Report
Give the user a per-feature table: clean / resolved conflict / partly upstreamed / fully upstreamed, plus the loose commits carried, build and test results, and the pushed branch names. Offer a streaming install to the Shields (see `AGENTS.md`).
