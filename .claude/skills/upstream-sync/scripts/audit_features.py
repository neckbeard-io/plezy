#!/usr/bin/env python3
import re
import subprocess
import sys

FEATURE_NAMES = [
    "android-seeking-fix",
    "view-all-breaks-media",
    "per-episode-cast",
    "watched-refresh",
    "next-up-fixes",
    "season-show-long-press",
    "osd-focus-changes",
    "skip-credit-changes",
    "playlist-enhancements",
    "per-server-visibility",
]

SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

def run(cmd):
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def semver_key(v):
    return tuple(int(p) for p in v.split("."))

def latest_version(prefix, below=None):
    # Only semver-suffixed branches; old date-suffixed ones would sort after them lexically.
    _, out, _ = run(f"git branch --list '{prefix}-*' --format='%(refname:short)'")
    versions = []
    for b in out.splitlines():
        v = b.strip()[len(prefix) + 1:]
        if SEMVER.match(v) and (below is None or semver_key(v) < semver_key(below)):
            versions.append(v)
    return max(versions, key=semver_key) if versions else None

def lines(out):
    return [l for l in out.splitlines() if l.strip()]

def identity_warning(commit, expected):
    # cherry-pick copies the original author, so a bad email spreads to every new release branch.
    _, emails, _ = run(f"git log -n 1 --format='%ae|%ce' {commit}")
    author, committer = emails.split("|")
    if author == expected and committer == expected:
        return ""
    return f"  !! identity <{author}>/<{committer}>, reset with --reset-author"

def main():
    if len(sys.argv) < 2:
        print("usage: audit_features.py <target-version> [<prev-version>]")
        sys.exit(1)
    target = sys.argv[1]
    prev = sys.argv[2] if len(sys.argv) > 2 else latest_version("testing-release", below=target)
    if not prev:
        print("No previous testing-release-<semver> branch found; pass <prev-version> explicitly.")
        sys.exit(1)
    prev_branch = f"testing-release-{prev}"

    expected_email = run("git config user.email")[1]

    print(f"=== Auditing Plezy custom features: {prev} -> {target} ===")

    for feat in FEATURE_NAMES:
        version = latest_version(feat, below=target)
        if not version:
            print(f"\n[-] {feat}: no <feature>-<semver> branch found!")
            continue
        branch = f"{feat}-{version}"
        # Feature commits are those on top of the upstream tag the branch was cut from.
        base = version if run(f"git rev-parse -q --verify refs/tags/{version}")[0] == 0 else "main"
        commits = lines(run(f"git rev-list --reverse {base}..{branch}")[1])

        print(f"\nFeature: {feat}  ({branch})")
        if not commits:
            print(f"  !! NO COMMITS on top of {base}: upstreamed, or lost in a past sync?")
            print(f"     Find the last branch that has it: git branch --list '{feat}-*' and check each with git log {base}..<branch>")
            continue

        for c in commits:
            summary = run(f"git log -n 1 --format='%h %s' {c}")[1]
            print(f"  Commit: {summary}{identity_warning(c, expected_email)}")

        files = " ".join(lines(run(f"git diff --name-only {base} {branch}")[1]))
        upstream_touches = lines(run(f"git log {prev}..{target} --oneline -- {files}")[1]) if files else []
        print(f"  Upstream Activity: {len(upstream_touches)} commit(s) touched related files since {prev}")
        for line in upstream_touches[:5]:
            print(f"    * {line}")
        if len(upstream_touches) > 5:
            print(f"    * ... and {len(upstream_touches) - 5} more")

        # Dry-run cherry-picking the whole feature range onto the target.
        mt_code, mt_out, _ = run(
            f"git merge-tree --write-tree --name-only --no-messages --merge-base={base} {target} {branch}")
        if mt_code == 0:
            print("  Merge-Tree Status: CLEAN")
        else:
            print("  Merge-Tree Status: CONFLICT DETECTED")
            for f in lines(mt_out)[1:11]:
                print(f"    ! {f}")

    # Commits made directly on the previous integration branch, outside any feature merge.
    loose = lines(run(f"git log --reverse --first-parent --no-merges --format='%h %s' {prev}..{prev_branch}")[1])
    print(f"\n=== Loose commits on {prev_branch} (carry forward unless upstreamed) ===")
    if not loose:
        print("  (none)")
    for line in loose:
        print(f"  {line}{identity_warning(line.split()[0], expected_email)}")

if __name__ == "__main__":
    main()
