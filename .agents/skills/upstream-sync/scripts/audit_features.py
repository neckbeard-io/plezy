#!/usr/bin/env python3
import subprocess
import sys

FEATURES = [
    ("android-seeking-fix", "android-seeking-fix-2026-08-26"),
    ("view-all-breaks-media", "view-all-breaks-media-2026-08-26"),
    ("per-episode-cast", "per-episode-cast-2026-08-26"),
    ("watched-refresh", "watched-refresh-2026-08-26"),
    ("next-up-fixes", "next-up-fixes-2026-08-26"),
    ("season-show-long-press", "season-show-long-press-2026-08-26"),
    ("osd-focus-changes", "osd-focus-changes-2026-08-26"),
    ("skip-credit-changes", "skip-credit-changes-2026-08-26"),
    ("playlist-enhancements", "playlist-enhancements-2026-08-26"),
    ("per-server-visibility", "per-server-visibility-2026-08-26"),
]

def run(cmd, capture=True):
    res = subprocess.run(cmd, shell=True, text=True, capture_output=capture)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "2.19.0"
    print(f"=== Auditing 10 Plezy Custom Features against {target} ===")
    
    for feat, branch in FEATURES:
        # Get commit hash of feature
        code, commit, _ = run(f"git rev-parse {branch}")
        if code != 0:
            print(f"[-] {feat}: branch {branch} not found!")
            continue
            
        code, subject, _ = run(f"git log -n 1 --format=%s {branch}")
        
        # Test applying commit patch to target
        # Check if patch applies cleanly to target using git merge-tree or git apply
        code, touched_files, _ = run(f"git diff-tree --no-commit-id --name-only -r {branch}")
        file_list = " ".join(touched_files.split())
        code, upstream_touches, _ = run(f"git log testing-release-2026-08-26..{target} --oneline -- {file_list}")
        upstream_modified = len(upstream_touches.splitlines()) if upstream_touches else 0
        
        # We can test cherry-pick feasibility using git merge-tree
        # git merge-tree <base> <branch> <target>
        # base is the parent of the commit on branch
        code, parent, _ = run(f"git rev-parse {branch}~1")
        mt_code, mt_out, mt_err = run(f"git merge-tree {parent} {target} {branch}")
        has_conflict = ("+<<<<<<<" in mt_out or "CONFLICT" in mt_out or mt_code != 0)
        
        print(f"\nFeature: {feat}")
        print(f"  Source Commit: {commit[:8]} ('{subject}')")
        print(f"  Upstream Activity: {upstream_modified} commit(s) touched related files since last sync")
        if upstream_touches:
            for line in upstream_touches.splitlines()[:3]:
                print(f"    * {line}")
            if upstream_modified > 3:
                print(f"    * ... and {upstream_modified - 3} more")
        
        if not has_conflict:
            print(f"  Merge-Tree Status: CLEAN (Rebases cleanly with zero conflicts)")
        else:
            print(f"  Merge-Tree Status: CONFLICT DETECTED")

if __name__ == "__main__":
    main()
