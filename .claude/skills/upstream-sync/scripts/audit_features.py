#!/usr/bin/env python3
"""Audit local commits on the previous testing-release branch against a new upstream tag.

Lists every local commit in carry-forward order, tags it with its portfolio feature,
dry-runs cherry-picking them in sequence onto the target, and flags conflicts,
identity problems, and portfolio features that no longer have any commits.
"""
import re
import subprocess
import sys

# Key files per feature, mirroring references/portfolio_catalog.md. Used only to
# label commits; a commit matching none is reported as a loose commit.
FEATURES = {
    "android-seeking-fix": ["android/app/src/main/kotlin/com/edde746/plezy/exoplayer/ExoPlayerCore.kt"],
    "view-all-breaks-media": ["lib/utils/media_image_helper.dart"],
    "per-episode-cast": ["lib/screens/media_detail_screen.dart"],
    "watched-refresh": ["lib/providers/discover_provider.dart", "lib/screens/discover_screen.dart"],
    "next-up-fixes": ["lib/screens/video_player/parts/playback_prompts.dart"],
    "season-show-long-press": ["lib/widgets/media_context_menu.dart"],
    "osd-focus-changes": [
        "lib/widgets/video_controls/player_chrome_controller.dart",
        "lib/widgets/video_controls/desktop_video_controls.dart",
        "lib/widgets/video_controls/parts/visibility.dart",
        "lib/widgets/video_controls/parts/key_events.dart",
        "lib/screens/video_player/parts/episode_navigation.dart",
    ],
    "skip-credit-changes": ["lib/widgets/video_controls/parts/markers.dart", "lib/screens/settings/playback_settings_screen.dart"],
    "playlist-enhancements": ["lib/screens/playlist/playlist_detail_screen.dart"],
    "per-server-visibility": [
        "lib/providers/hidden_servers_provider.dart",
        "lib/screens/settings/media_servers_screen.dart",
        "lib/providers/libraries_provider.dart",
    ],
    "osd-air-date": ["lib/widgets/video_controls/widgets/video_controls_header.dart", "lib/mpv/player/active_player_type.dart"],
    "watched-total-count": [
        "lib/providers/show_watch_counts_provider.dart",
        "lib/widgets/watched_indicator.dart",
        "lib/media/leaf_watch_count.dart",
    ],
}

TOOLING_PREFIXES = (".agents/", ".claude/")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def run(cmd):
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()


def lines(out):
    return [l for l in out.splitlines() if l.strip()]


def semver_key(v):
    return tuple(int(p) for p in v.split("."))


def previous_release(below):
    _, out, _ = run("git branch --list 'testing-release-*' --format='%(refname:short)'")
    versions = [b[len("testing-release-"):] for b in lines(out)]
    versions = [v for v in versions if SEMVER.match(v) and semver_key(v) < semver_key(below)]
    return max(versions, key=semver_key) if versions else None


def label_for(files):
    scores = {name: len(set(files) & set(keys)) for name, keys in FEATURES.items()}
    best = max(scores.values())
    if best == 0:
        return "loose commit"
    return " / ".join(name for name, score in scores.items() if score == best)


def identity_warning(commit, expected):
    # cherry-pick copies the original author, so a bad email spreads to every new release branch.
    _, emails, _ = run(f"git log -n 1 --format='%ae|%ce' {commit}")
    author, committer = emails.split("|")
    if author == expected and committer == expected:
        return None
    return f"identity <{author}>/<{committer}>, reset with --reset-author"


def main():
    if len(sys.argv) < 2:
        print("usage: audit_features.py <target-version> [<prev-version>]")
        sys.exit(1)
    target = sys.argv[1]
    prev = sys.argv[2] if len(sys.argv) > 2 else previous_release(target)
    if not prev:
        print("No previous testing-release-<semver> branch found; pass <prev-version> explicitly.")
        sys.exit(1)
    prev_branch = f"testing-release-{prev}"
    for ref in (target, prev, prev_branch):
        if run(f"git rev-parse -q --verify '{ref}^{{commit}}'")[0] != 0:
            print(f"{ref} does not exist; fetch upstream tags first (scripts/sync_main.sh).")
            sys.exit(1)
    expected_email = run("git config user.email")[1]

    print(f"=== Local commits on {prev_branch}, dry-run onto {target} ===")

    commits = lines(run(f"git rev-list --reverse --topo-order --no-merges {prev}..{prev_branch}")[1])
    # Chain each clean pick onto a throwaway commit so later picks see earlier ones,
    # as a real sequential cherry-pick would.
    _, head, _ = run(f"git rev-parse {target}^{{commit}}")
    seen_conflict = False
    found = set()

    for c in commits:
        _, summary, _ = run(f"git log -n 1 --format='%h %s' {c}")
        files = lines(run(f"git diff-tree --no-commit-id --name-only -r {c}")[1])
        if files and all(f.startswith(TOOLING_PREFIXES) for f in files):
            print(f"\n  {summary}\n    tooling only, covered by the restore step")
            continue

        label = label_for(files)
        found.update(label.split(" / "))
        print(f"\n  {summary}\n    feature: {label}")

        warning = identity_warning(c, expected_email)
        if warning:
            print(f"    !! {warning}")

        touches = lines(run(f"git log {prev}..{target} --oneline -- {' '.join(files)}")[1]) if files else []
        if touches:
            print(f"    upstream touched these files in {len(touches)} commit(s) since {prev}:")
            for line in touches[:3]:
                print(f"      * {line}")
            if len(touches) > 3:
                print(f"      * ... and {len(touches) - 3} more")

        code, out, _ = run(f"git merge-tree --write-tree --name-only --no-messages --merge-base={c}^ {head} {c}")
        if code == 0:
            _, head, _ = run(f"git commit-tree {out.splitlines()[0]} -p {head} -m audit")
            print("    pick: CLEAN" + (" (after an earlier conflict, approximate)" if seen_conflict else ""))
        else:
            seen_conflict = True
            print("    pick: CONFLICT")
            for f in lines(out)[1:11]:
                print(f"      ! {f}")

    missing = [name for name in FEATURES if name not in found]
    print("\n=== Portfolio features with no commits ===")
    if not missing:
        print("  (none)")
    for name in missing:
        print(f"  !! {name}: upstreamed, or lost in a past sync? Check before treating it as upstreamed.")


if __name__ == "__main__":
    main()
